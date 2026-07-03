# elm-bootstrap-theme-builder — a live Bootstrap 5.3 theme builder in Elm

A focused, in-browser tool for building a **custom [Bootstrap 5.3](https://getbootstrap.com/) theme**.
A theme here is a *single CSS file* that is layered on top of the stock Bootstrap stylesheet — so it
themes Bootstrap purely by overriding its runtime `--bs-*` CSS variables (and, if you want, component
rules). No Sass, no build step for the theme itself: you edit CSS, the preview restyles instantly.

- **Left pane (~30%)** — the one CSS file you edit. It opens as the *complete* set of Bootstrap's
  `--bs-*` variables, every line commented out, so the theme starts empty. Uncomment what you want to
  change.
- **Right pane** — an example page rendered with **real Bootstrap inside an iframe**. Your CSS is
  injected as a live `<style>` element after `bootstrap.css`, exactly as a published theme file would
  sit on top of it. Edits update the preview with no flicker and no re-fetch of Bootstrap.

There is no file browser — there is only ever one file.

It is built on the [elm-lang](https://github.com/tunguski/elm-lang) ecosystem and **reuses the whole
[elm-editor](https://github.com/tunguski/elm-editor) shell** (`Editor.program`): the file/editing
chrome, resizable panes, permalink sharing and autosave, the syntax-highlighted `textarea`/`pre`
overlay (`CodeEditor`) and a CSS highlighter (`Highlight.cssSegments`). This app plugs in its own
Bootstrap preview pane plus two structured editing panels; the shell modules are a *source
dependency* declared in `elm.vendored.json` and resolved by the compiler at build time. The whole app
compiles to JavaScript by the elm-lang compiler.

The one CSS file can be edited three ways, switched from the code pane's title bar:

- **Wizard** (the default view) — a handful of high-level knobs (colour palette, corners, spacing,
  heading scale, body font size, border width, base font). Pick a preset (ten of them) or a custom
  palette seeded from one to three colours, and the wizard derives the whole `--bs-*` set — plus the
  component rules Bootstrap can't drive from `:root` alone (per-variant buttons, active/selected
  states, spacing, headings) — writing them into your file as a managed block.
- **Form** — a typed view of the file. A *Properties* tab lists every `--bs-*` variable as a
  checkbox + value row (ticking uncomments the line), grouped by block and section; a *Component
  styles* tab is a code editor over the free-form CSS below the marker line.
- **Code** — the plain source editor (appended by the shell).

## Features

- **Live theming** — every keystroke re-applies your CSS over Bootstrap in the preview iframe.
- **All variables, ready to uncomment** — the full Bootstrap 5.3.8 `:root` light set *and* the
  `[data-bs-theme=dark]` dark set, grouped and commented, generated from the stock stylesheet.
- **Wizard & Form editing** — build a theme from high-level knobs, or tick variables on and off in a
  typed form, without hand-editing CSS.
- **Light / dark preview** — toggle the preview's `data-bs-theme` to check both modes.
- **Copy CSS** — copy the finished theme file to the clipboard.
- **Sharing & autosave** — sessions are shareable via permalink and kept in `localStorage` (via the
  elm-lang runtime `Storage` module), restored on your next visit — all provided by the editor shell.

## Layout

| File | Role |
|---|---|
| [src/Main.elm](src/Main.elm) | Wires the app together: `Editor.program` with the CSS highlighter, the template as the starting file, the Bootstrap preview, and the Wizard/Form panels. |
| [src/BootstrapPreview.elm](src/BootstrapPreview.elm) | The preview pane (`Preview.Spec`): the live iframe, the light/dark toggle and Copy CSS, and the ports that push CSS into the iframe. |
| [src/ThemeWizard.elm](src/ThemeWizard.elm) | The Wizard panel: high-level knobs and palette presets/derivation that generate the `--bs-*` overrides and component rules. |
| [src/ThemeForm.elm](src/ThemeForm.elm) | The Form panel: the Properties (variable checkboxes) and Component styles tabs. |
| [src/theme-template.css](src/theme-template.css) | The default editor contents: every Bootstrap `--bs-*` variable, commented, grouped by section. Fetched at startup. |
| [index.template.html](index.template.html) | The host page: app chrome + editor-shell CSS, the example page rendered in the preview iframe, and the JS port wiring (Bootstrap from a CDN). |
| `vendor/` | The elm-editor shell modules (`Editor`, `Preview`, `Share`, `CodeEditor`, `Highlight`), resolved from `elm.vendored.json` at build time (git-ignored). |

## Build & run

You need the [elm-lang](https://github.com/tunguski/elm-lang) CLI. The
[elm-editor](https://github.com/tunguski/elm-editor) shell modules are a *source dependency* declared
in `elm.vendored.json` — the compiler resolves them at build time (from `git-deps/` at the pinned
ref, or from a local checkout via `elm.vendored.local.json`). Point `ELM` at the CLI; set `EDITOR` to
an elm-editor checkout so the build can copy its `editor.css`.

```sh
# from this directory
ELM=../../elm.sh EDITOR=../elm-editor ./build.sh
npx --yes serve build      # then open the printed URL
```

On Windows:

```powershell
$env:ELM = 'java -jar C:\path\to\elm.jar'; $env:EDITOR = '..\elm-editor'; ./build.ps1
npx --yes serve build
```

The app must be **served over HTTP** (it fetches `theme-template.css` at startup); opening
`build/index.html` from the filesystem will not load the template.

The app **type-checks cleanly** under the strict checker (no `--no-check`) and runs under the elm-lang
JS backend.

## How the theming works

Bootstrap 5.3 reads its colours, spacing, radii, shadows, etc. from CSS custom properties at runtime
(`--bs-primary`, `--bs-body-bg`, `--bs-border-radius`, …). Because they are *runtime* variables, you
can override them with a stylesheet that loads after Bootstrap — no recompile needed. This tool writes
exactly that stylesheet. (Sass-only variables such as `$primary`, and anything that changes generated
selectors, can't be themed this way and aren't offered.)
