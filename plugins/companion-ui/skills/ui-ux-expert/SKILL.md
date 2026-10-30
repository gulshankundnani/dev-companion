---
name: ui-ux-expert
description: UI/UX design and review (usability, WCAG 2.2 AA, consistency, responsive layout, forms) plus wireframes, HTML mockups and diagrams. Use when designing or reviewing screens, or asked for a mockup, wireframe, prototype, diagram or better usability.
---

# UI/UX expert + visualization & mockups

## Before designing
- Find the existing design system: component library (Bootstrap, Material, Telerik, DevExpress, Kendo, Tailwind…), shared styles/tokens, layout shell, existing similar screens. **Reuse those components** (`code-reuse`) — consistency beats novelty.
- Clarify: who is the user, primary task, frequency of use (power user data-entry vs occasional user), devices.

## Principles (apply and check)
- **Hierarchy**: one primary action per view; most important info top-left / above the fold; group related fields.
- **Consistency**: same patterns for same things (labels, buttons order, date formats, empty states).
- **Feedback & states**: every view handles loading, empty, error, success, disabled, partial data. Long actions show progress; destructive actions confirm and allow undo when possible.
- **Forms**: labels above/left consistently, inline validation on blur, clear error text next to field, sensible defaults, keyboard-friendly tab order, don't clear input on error.
- **Data-heavy screens (grids)**: sort/filter/paging server-side for large data, sticky headers, right-aligned numbers, column choice persisted, export when users need it.
- **Accessibility (WCAG 2.2 AA)**: contrast ≥ 4.5:1 text, focus visible, all actions keyboard-reachable, semantic HTML / ARIA only when needed, alt text, don't rely on colour alone, target size ≥ 24px.
- **Responsive**: mobile-first breakpoints if the app supports mobile; no horizontal scroll at 320–375px.
- Copy: plain words, verbs on buttons ("Save order", not "OK"), no jargon.

## Visualization & mockups (show before building)
Pick the cheapest artifact that answers the question:
| Need | Produce |
|------|---------|
| Flow / process / architecture | Mermaid diagram (flowchart, sequence, ER, state) in markdown |
| Layout idea, quick | ASCII/markdown wireframe in chat |
| Look & feel / stakeholder review | Single self-contained HTML file with inline CSS, using the project's colours and component look; static data; light + dark if the app supports it |
| Interaction feel | Same HTML + minimal vanilla JS for key interactions |
| Data chart | Chart that fits the data (bar for comparison, line for trend), labelled axes, accessible colours |

- Save mockups under `docs/mockups/<feature>.html` (or the project's docs folder) — ask before adding files.
- If the environment offers an artifact / visual widget tool, use it to show the mockup inline; otherwise open the HTML file in the browser pane.
- Offer 1 recommended design; add a variant only when there is a real trade-off.
- After approval, build with real components and match the mockup.

## Review output
List issues as `severity | screen/element | problem | fix`, highest severity first (blocks task > accessibility failure > inconsistency > polish).
