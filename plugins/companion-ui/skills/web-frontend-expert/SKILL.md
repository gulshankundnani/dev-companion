---
name: web-frontend-expert
description: Front end of ASP.NET MVC / Razor apps - .cshtml views and partials, JavaScript/jQuery, AJAX, Bootstrap/jQuery UI modals and stacked popups, events, caching of scripts. Use when fixing or building views, scripts, popups, dialogs or page behaviour.
---

# Web front end (Razor + JavaScript)

**Find the existing way first**: grep for the app's popup helper (`function \w*(Popup|Modal|Dialog)`, `.modal(`, `.dialog(`) and shared scripts (`common.js`, `site.js`). Put changes where the user wants them: a shared-file change affects every page, so ask if unclear. Check `_Layout.cshtml` and bundling for script order and versions.

**Popups**
- Stacked Bootstrap modals: on `show.bs.modal`, set `z-index` from the count of visible modals; in a `setTimeout`, put the newest `.modal-backdrop` just below it. On `hidden.bs.modal`, re-add `modal-open` to `body` if another modal is still open.
- Reload/callback on close: bind to that popup's close event (`hidden.bs.modal`, `dialogclose`). Store the opener (button, grid, callback) when opening, in `data-` attributes or a stack, not one global.
- AJAX-loaded content: bind with delegated handlers or `.off().on()` (else handlers duplicate); re-run `$.validator.unobtrusive.parse`, date pickers and other plugins after insertion.

**JavaScript**: small named functions; `const`/`let` (not `var`) where the browser target allows; early return; cache jQuery selections used twice; no new globals; reuse shared helpers. AJAX: handle `.fail()`, send the anti-forgery token on POST, disable submit while pending. Use `.text()` or encode for user data. Changed `.js` may be cached: bump the version query string; hard-refresh when testing.

**Razor**: logic in controller/view model; partials for repeated markup; `Html.Raw` only for trusted HTML; page scripts in `@section Scripts`.

**Verify** in the browser: open, nest, close and reopen every popup variant the user named; check console and failed requests. Query specific elements, not full page text.
