#!/usr/bin/env node
'use strict';
// razor-bridge: one LSP server for .cs and .cshtml.
// .cs requests pass straight through to csharp-ls. In .cshtml there is no Razor compiler, so the C# symbol
// under the cursor is resolved by name through csharp-ls workspace/symbol (qualifier and @model narrow it),
// and references add view call sites found by text match. Other .cshtml requests go to the HTML server.
// View hits are word matches, not compiler-exact: callers should treat them as candidates.

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { fileURLToPath, pathToFileURL } = require('url');

const VERSION = '1.1.0';
const VIEW_EXT = /\.(cshtml|vbhtml)$/i;
const SKIP_DIRS = new Set(['bin', 'obj', 'node_modules', '.git', '.vs', 'packages', '$tf', '.svn']);
const MAX_VIEW_HITS = 5000;
const MAX_NAME_MATCHES = 20;
const VIEW_LIST_TTL_MS = 10 * 60 * 1000;
const LOG = process.env.RAZOR_BRIDGE_LOG;
const HTML_INIT_OPTIONS = { provideFormatter: true, embeddedLanguages: { css: true, javascript: true } };

function log(text) {
  if (!LOG) return;
  try { fs.appendFileSync(LOG, new Date().toISOString() + ' ' + text + '\n'); } catch (e) { /* logging is best effort */ }
}

// ---------- JSON-RPC framing ----------
class Endpoint {
  constructor(name, readable, writable, onMessage) {
    this.name = name;
    this.writable = writable;
    this.onMessage = onMessage;
    this.buffer = Buffer.alloc(0);
    this.nextId = 1;
    this.pending = new Map();
    readable.on('data', (chunk) => this.receive(chunk));
  }

  receive(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    for (;;) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd < 0) return;
      const match = /Content-Length:\s*(\d+)/i.exec(this.buffer.subarray(0, headerEnd).toString('ascii'));
      if (!match) { this.buffer = this.buffer.subarray(headerEnd + 4); continue; }
      const length = parseInt(match[1], 10);
      const bodyStart = headerEnd + 4;
      if (this.buffer.length < bodyStart + length) return;
      const body = this.buffer.subarray(bodyStart, bodyStart + length).toString('utf8');
      this.buffer = this.buffer.subarray(bodyStart + length);
      let msg;
      try { msg = JSON.parse(body); } catch (e) { log(this.name + ' bad json'); continue; }
      this.dispatch(msg);
    }
  }

  dispatch(msg) {
    const isResponse = msg.id !== undefined && msg.method === undefined;
    if (isResponse && this.pending.has(msg.id)) {
      const waiter = this.pending.get(msg.id);
      this.pending.delete(msg.id);
      if (msg.error) waiter.reject(msg.error); else waiter.resolve(msg.result);
      return;
    }
    this.onMessage(msg);
  }

  send(msg) {
    msg.jsonrpc = '2.0';
    const body = Buffer.from(JSON.stringify(msg), 'utf8');
    this.writable.write('Content-Length: ' + body.length + '\r\n\r\n');
    this.writable.write(body);
  }

  request(method, params) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.send({ id, method, params });
    });
  }

  notify(method, params) { this.send({ method, params }); }
}

// ---------- child servers ----------
function startChild(tag, command, args, useShell) {
  let proc;
  try {
    proc = spawn(command, args, { stdio: ['pipe', 'pipe', 'pipe'], shell: useShell, windowsHide: true });
  } catch (e) {
    log(tag + ' spawn failed: ' + e.message);
    return null;
  }
  proc.stderr.on('data', (d) => log(tag + ' stderr: ' + d.toString().trim()));
  const child = new Endpoint(tag, proc.stdout, proc.stdin, (msg) => forwardFromChild(tag, msg));
  child.alive = true;
  proc.on('error', (e) => { child.alive = false; log(tag + ' error: ' + e.message); });
  proc.on('exit', (code) => { child.alive = false; log(tag + ' exited ' + code); });
  return child;
}

const isWindows = process.platform === 'win32';
const children = {
  cs: startChild('cs', process.env.RAZOR_BRIDGE_CSHARP || 'csharp-ls', [], false),
  html: startChild('html', process.env.RAZOR_BRIDGE_HTML || 'vscode-html-language-server', ['--stdio'], isWindows),
};

const client = new Endpoint('client', process.stdin, process.stdout, onClientMessage);
let rootPath = process.cwd();
const openViews = new Map(); // uri -> text

function forwardFromChild(tag, msg) {
  if (msg.id !== undefined && msg.method !== undefined) {
    client.send({ id: tag + ':' + JSON.stringify(msg.id), method: msg.method, params: msg.params });
    return;
  }
  if (msg.method !== undefined) client.send({ method: msg.method, params: msg.params });
}

function childRequest(tag, method, params) {
  const child = children[tag];
  if (!child || !child.alive) return Promise.resolve(null);
  return child.request(method, params);
}

function childNotify(tag, method, params) {
  const child = children[tag];
  if (child && child.alive) child.notify(method, params);
}

// ---------- client side ----------
function onClientMessage(msg) {
  if (msg.method === undefined) { routeClientResponse(msg); return; }
  if (msg.id === undefined) { onClientNotification(msg); return; }
  handleRequest(msg.method, msg.params || {}).then(
    (result) => client.send({ id: msg.id, result: result === undefined ? null : result }),
    (err) => client.send({ id: msg.id, error: { code: (err && err.code) || -32603, message: (err && err.message) || String(err) } })
  );
}

function routeClientResponse(msg) {
  const text = String(msg.id);
  const colon = text.indexOf(':');
  const tag = text.slice(0, colon);
  const child = children[tag];
  if (!child || !child.alive) return;
  const reply = { id: JSON.parse(text.slice(colon + 1)) };
  if (msg.error) reply.error = msg.error; else reply.result = msg.result === undefined ? null : msg.result;
  child.send(reply);
}

function onClientNotification(msg) {
  const params = msg.params || {};
  const uri = params.textDocument && params.textDocument.uri;
  if (msg.method === '$/cancelRequest') return;
  if (msg.method === 'exit') {
    childNotify('cs', 'exit');
    childNotify('html', 'exit');
    setTimeout(() => process.exit(0), 200);
    return;
  }
  if (uri && isView(uri)) { onViewNotification(msg.method, params); return; }
  if (uri) { childNotify('cs', msg.method, params); return; }
  childNotify('cs', msg.method, params);
  childNotify('html', msg.method, params);
}

function onViewNotification(method, params) {
  const uri = params.textDocument.uri;
  if (method === 'textDocument/didOpen') {
    openViews.set(uri, params.textDocument.text);
    const doc = Object.assign({}, params.textDocument, { languageId: 'html' });
    childNotify('html', method, { textDocument: doc });
    return;
  }
  if (method === 'textDocument/didChange') {
    const changes = params.contentChanges || [];
    const full = changes.length ? changes[changes.length - 1] : null;
    if (full && full.range === undefined) openViews.set(uri, full.text);
  }
  if (method === 'textDocument/didClose') openViews.delete(uri);
  childNotify('html', method, params);
}

async function handleRequest(method, params) {
  if (method === 'initialize') return initialize(params);
  if (method === 'shutdown') {
    await Promise.all([childRequest('cs', 'shutdown').catch(() => null), childRequest('html', 'shutdown').catch(() => null)]);
    return null;
  }
  const uri = params.textDocument && params.textDocument.uri;
  if (uri && isView(uri)) return handleViewRequest(method, params);
  if (method === 'textDocument/references') return csReferences(params);
  return childRequest('cs', method, params);
}

async function initialize(params) {
  rootPath = rootFromInitialize(params) || rootPath;
  log('root ' + rootPath);
  const htmlParams = Object.assign({}, params, { initializationOptions: HTML_INIT_OPTIONS });
  const htmlInit = childRequest('html', 'initialize', htmlParams).catch((e) => { log('html init failed ' + JSON.stringify(e)); return null; });
  const csInit = await childRequest('cs', 'initialize', params);
  await htmlInit;
  const capabilities = Object.assign({}, (csInit && csInit.capabilities) || {});
  capabilities.textDocumentSync = { openClose: true, change: 1, save: { includeText: false } };
  capabilities.definitionProvider = true;
  capabilities.hoverProvider = true;
  capabilities.referencesProvider = true;
  capabilities.documentSymbolProvider = true;
  return { capabilities, serverInfo: { name: 'razor-bridge', version: VERSION } };
}

function rootFromInitialize(params) {
  if (params.rootUri) return uriToPath(params.rootUri);
  if (params.workspaceFolders && params.workspaceFolders.length) return uriToPath(params.workspaceFolders[0].uri);
  return params.rootPath || null;
}

// ---------- .cshtml requests ----------
const VIEW_DEFINITION_METHODS = new Set(['textDocument/definition', 'textDocument/implementation', 'textDocument/typeDefinition', 'textDocument/declaration']);

async function handleViewRequest(method, params) {
  if (VIEW_DEFINITION_METHODS.has(method)) {
    const found = await resolveInView(params.textDocument.uri, params.position);
    return found.map((f) => f.location);
  }
  if (method === 'textDocument/hover') return viewHover(params);
  if (method === 'textDocument/references') return viewReferences(params);
  if (method === 'textDocument/prepareCallHierarchy') {
    const found = await resolveInView(params.textDocument.uri, params.position);
    if (!found.length) return null;
    return childRequest('cs', method, { textDocument: { uri: found[0].location.uri }, position: found[0].location.range.start });
  }
  ensureHtmlOpen(params.textDocument.uri);
  return childRequest('html', method, params);
}

function ensureHtmlOpen(uri) {
  if (openViews.has(uri)) return;
  const text = readText(uri);
  if (text === null) return;
  openViews.set(uri, text);
  childNotify('html', 'textDocument/didOpen', { textDocument: { uri, languageId: 'html', version: 1, text } });
}

async function viewHover(params) {
  const found = await resolveInView(params.textDocument.uri, params.position);
  if (!found.length) return null;
  const first = found[0].location;
  const hover = await childRequest('cs', 'textDocument/hover', { textDocument: { uri: first.uri }, position: first.range.start });
  if (!hover || found.length === 1) return hover;
  const note = '\n\n(resolved by name in a Razor view; ' + (found.length - 1) + ' other symbol(s) share this name)';
  return { contents: appendToHover(hover.contents, note), range: hover.range };
}

function appendToHover(contents, note) {
  if (typeof contents === 'string') return contents + note;
  if (Array.isArray(contents)) return contents.concat([note]);
  if (contents && contents.value !== undefined) return { kind: contents.kind || 'markdown', value: contents.value + note };
  return contents;
}

async function viewReferences(params) {
  const found = await resolveInView(params.textDocument.uri, params.position);
  if (!found.length) return [];
  const results = [];
  for (const f of found.slice(0, 3)) {
    const refs = await childRequest('cs', 'textDocument/references', {
      textDocument: { uri: f.location.uri }, position: f.location.range.start, context: params.context || { includeDeclaration: true },
    }).catch(() => null);
    if (refs) results.push(...refs);
  }
  const viewHits = await findViewReferences(found[0].location, found[0].name);
  return dedupeLocations(results.concat(viewHits));
}

// ---------- .cs references: add the view call sites ----------
async function csReferences(params) {
  const csRefs = (await childRequest('cs', 'textDocument/references', params)) || [];
  const name = identifierAt(readText(params.textDocument.uri), params.position);
  if (!name) return csRefs;
  const defs = normalizeLocations(await childRequest('cs', 'textDocument/definition', {
    textDocument: params.textDocument, position: params.position,
  }).catch(() => null));
  if (!defs.length) return csRefs;
  const def = refineLocation(defs[0], name.name) || defs[0];
  const viewHits = await findViewReferences(def, name.name);
  return dedupeLocations(csRefs.concat(viewHits));
}

// ---------- resolving a name in a view ----------
async function resolveInView(uri, position) {
  const text = readText(uri);
  const at = identifierAt(text, position);
  if (!at) return [];
  const symbols = (await childRequest('cs', 'workspace/symbol', { query: at.name }).catch(() => null)) || [];
  const exact = symbols.filter((s) => symbolShortName(s) === at.name);
  if (!exact.length) return [];
  const qualifier = viewQualifier(text, at.qualifier);
  const ranked = exact
    .map((s) => ({ s, score: scoreSymbol(s, qualifier, text) }))
    .sort((a, b) => b.score - a.score);
  const best = ranked[0].score;
  const kept = ranked.filter((r) => best === 0 || r.score === best).slice(0, MAX_NAME_MATCHES);
  const found = [];
  for (const r of kept) {
    const loc = symbolLocation(r.s, at.name);
    if (loc) found.push({ name: at.name, location: loc });
  }
  return found;
}

function viewQualifier(viewText, qualifier) {
  if (!qualifier) return null;
  if (qualifier === 'Model' || qualifier === 'model') return modelTypeName(viewText);
  if (qualifier === 'Html' || qualifier === 'Url' || qualifier === 'ViewBag' || qualifier === 'Ajax') return null;
  return qualifier;
}

function modelTypeName(viewText) {
  const m = /^\s*@model\s+(.+)$/m.exec(viewText || '');
  if (!m) return null;
  const generic = new Set(['IEnumerable', 'List', 'IList', 'ICollection', 'IQueryable', 'System', 'Collections', 'Generic', 'Linq']);
  const tokens = m[1].match(/[A-Za-z_]\w*/g) || [];
  const candidates = tokens.filter((t) => !generic.has(t));
  return candidates.length ? candidates[candidates.length - 1] : null;
}

function scoreSymbol(symbol, qualifier, viewText) {
  const container = containerShortName(symbol);
  if (qualifier && container === qualifier) return 3;
  if (container && viewText && new RegExp('\\b' + escapeRe(container) + '\\b').test(viewText)) return 2;
  return 0;
}

function symbolShortName(symbol) {
  let n = String(symbol.name || '');
  const paren = n.indexOf('(');
  if (paren >= 0) n = n.slice(0, paren);
  const lt = n.indexOf('<');
  if (lt >= 0) n = n.slice(0, lt);
  n = n.trim();
  const parts = n.split(/[\s.]+/);
  return parts[parts.length - 1];
}

function containerShortName(symbol) {
  let c = symbol.containerName;
  if (!c) {
    const n = String(symbol.name || '').split('(')[0];
    const dot = n.lastIndexOf('.');
    c = dot > 0 ? n.slice(0, dot) : '';
  }
  const parts = String(c).split(/[\s.]+/).filter(Boolean);
  return parts.length ? parts[parts.length - 1] : '';
}

function symbolLocation(symbol, name) {
  const loc = symbol.location;
  if (!loc || !loc.uri) return null;
  const range = loc.range || { start: { line: 0, character: 0 }, end: { line: 0, character: 0 } };
  return refineLocation({ uri: loc.uri, range }, name) || { uri: loc.uri, range };
}

// A symbol range may start at its doc comment: move it onto the name itself.
function refineLocation(location, name) {
  const text = readText(location.uri);
  if (text === null) return null;
  const lines = text.split(/\r?\n/);
  const re = new RegExp('\\b' + escapeRe(name) + '\\b');
  const start = location.range.start.line;
  for (let i = start; i < Math.min(lines.length, start + 60); i++) {
    if (/^\s*\/\//.test(lines[i])) continue;
    const m = re.exec(lines[i]);
    if (m) return { uri: location.uri, range: { start: { line: i, character: m.index }, end: { line: i, character: m.index + name.length } } };
  }
  return null;
}

function identifierAt(text, position) {
  if (text === null || !position) return null;
  const lines = text.split(/\r?\n/);
  const line = lines[position.line];
  if (line === undefined) return null;
  const isWord = (ch) => /[A-Za-z0-9_]/.test(ch);
  let i = Math.min(position.character, line.length);
  if (!isWord(line[i] || '') && i > 0 && isWord(line[i - 1])) i--;
  if (!isWord(line[i] || '')) return null;
  let s = i;
  let e = i;
  while (s > 0 && isWord(line[s - 1])) s--;
  while (e < line.length && isWord(line[e])) e++;
  const name = line.slice(s, e);
  if (/^\d/.test(name)) return null;
  let qualifier = null;
  if (s > 0 && line[s - 1] === '.') {
    let q = s - 1;
    while (q > 0 && isWord(line[q - 1])) q--;
    if (q < s - 1) qualifier = line.slice(q, s - 1);
  }
  return { name, qualifier };
}

// ---------- view text search ----------
async function findViewReferences(defLocation, name) {
  const shape = describeDeclaration(defLocation, name);
  if (!shape) return [];
  log('view search ' + name + ' as ' + shape.kind + (shape.container ? ' in ' + shape.container : ''));
  const files = listViews();
  const needle = Buffer.from(name, 'utf8');
  const hits = [];
  let index = 0;
  async function worker() {
    while (index < files.length && hits.length < MAX_VIEW_HITS) {
      const file = files[index++];
      let buf;
      try { buf = await fs.promises.readFile(file); } catch (e) { continue; }
      if (buf.indexOf(needle) < 0) continue;
      const text = stripBom(buf.toString('utf8'));
      if (shape.requireInFile && !shape.requireInFile.test(text)) continue;
      collectHits(file, text, shape.pattern, name, hits);
    }
  }
  await Promise.all(Array.from({ length: 32 }, worker));
  return hits.slice(0, MAX_VIEW_HITS);
}

function collectHits(file, text, pattern, name, hits) {
  const uri = pathToFileURL(file).href;
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].indexOf(name) < 0) continue;
    pattern.lastIndex = 0;
    let m;
    while ((m = pattern.exec(lines[i])) !== null) {
      const col = m.index + m[0].lastIndexOf(name);
      hits.push({ uri, range: { start: { line: i, character: col }, end: { line: i, character: col + name.length } } });
      if (m[0].length === 0) pattern.lastIndex++;
    }
  }
}

// Decide how a view refers to the symbol from its declaration line.
function describeDeclaration(location, name) {
  const text = readText(location.uri);
  if (text === null) return null;
  const lines = text.split(/\r?\n/);
  const declLine = lines[location.range.start.line] || '';
  const n = escapeRe(name);
  if (new RegExp('\\b(class|struct|interface|enum|delegate)\\b[^=;{]*\\b' + n + '\\b').test(declLine)) {
    return { kind: 'type', pattern: new RegExp('\\b' + n + '\\b', 'g') };
  }
  const owner = enclosingType(lines, location.range.start.line);
  const container = owner ? owner.name : null;
  const c = container ? escapeRe(container) : null;
  const isStatic = /\b(static|const)\b/.test(declLine) || (owner && owner.kind === 'enum');
  if (isStatic && /\(\s*this\s/.test(declLine)) {
    const alt = c ? '|\\b' + c + '\\s*\\.\\s*' + n + '\\b' : '';
    return { kind: 'extension', container, pattern: new RegExp('\\.\\s*' + n + '\\s*[(<]' + alt, 'g') };
  }
  if (isStatic && c) {
    return { kind: 'static', container, pattern: new RegExp('\\b' + c + '\\s*\\.\\s*' + n + '\\b', 'g') };
  }
  return {
    kind: 'instance',
    container,
    pattern: new RegExp('\\.\\s*' + n + '\\b', 'g'),
    requireInFile: c ? new RegExp('\\b' + c + '\\b') : null,
  };
}

function enclosingType(lines, fromLine) {
  const re = /\b(class|struct|interface|enum)\s+([A-Za-z_]\w*)/;
  for (let i = fromLine; i >= 0; i--) {
    if (/^\s*\/\//.test(lines[i])) continue;
    const m = re.exec(lines[i]);
    if (m) return { kind: m[1], name: m[2] };
  }
  return null;
}

let viewCache = { at: 0, root: null, files: [] };
function listViews() {
  const now = Date.now();
  if (viewCache.root === rootPath && now - viewCache.at < VIEW_LIST_TTL_MS) return viewCache.files;
  const files = [];
  const stack = [rootPath];
  while (stack.length) {
    const dir = stack.pop();
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { continue; }
    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (!SKIP_DIRS.has(entry.name.toLowerCase())) stack.push(path.join(dir, entry.name));
      } else if (VIEW_EXT.test(entry.name)) {
        files.push(path.join(dir, entry.name));
      }
    }
  }
  viewCache = { at: now, root: rootPath, files };
  log('views listed: ' + files.length);
  return files;
}

// ---------- helpers ----------
function isView(uri) { return VIEW_EXT.test(String(uri).split('?')[0]); }

function uriToPath(uri) {
  try { return fileURLToPath(uri); } catch (e) { return null; }
}

const textCache = new Map();
function readText(uri) {
  if (openViews.has(uri)) return openViews.get(uri);
  const file = uriToPath(uri);
  if (!file) return null;
  let stat;
  try { stat = fs.statSync(file); } catch (e) { return null; }
  const cached = textCache.get(file);
  if (cached && cached.mtime === stat.mtimeMs) return cached.text;
  let text;
  try { text = stripBom(fs.readFileSync(file, 'utf8')); } catch (e) { return null; }
  if (textCache.size > 200) textCache.clear();
  textCache.set(file, { mtime: stat.mtimeMs, text });
  return text;
}

function stripBom(text) { return text.charCodeAt(0) === 0xfeff ? text.slice(1) : text; }

function escapeRe(text) { return String(text).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

function normalizeLocations(result) {
  if (!result) return [];
  const list = Array.isArray(result) ? result : [result];
  return list.map((l) => (l.targetUri ? { uri: l.targetUri, range: l.targetSelectionRange || l.targetRange } : l)).filter((l) => l && l.uri);
}

function dedupeLocations(list) {
  const seen = new Set();
  const out = [];
  for (const l of list) {
    const file = (uriToPath(l.uri) || l.uri).toLowerCase();
    const key = file + ':' + l.range.start.line + ':' + l.range.start.character;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(l);
  }
  return out;
}

process.on('uncaughtException', (e) => log('uncaught ' + (e && e.stack)));
