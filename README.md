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

It is built on the [elm-lang](https://github.com/tunguski/elm-lang) ecosystem and **reuses the
[elm-editor](https://github.com/tunguski/elm-editor) code-editing widget**: the syntax-highlighted
`textarea`/`pre` overlay (`CodeEditor`) and a CSS highlighter (`Highlight.cssSegments`), both added to
elm-editor so they can be reused here. The whole app is an Elm `Browser.element` program compiled to
JavaScript by the elm-lang compiler.

## Features

- **Live theming** — every keystroke re-applies your CSS over Bootstrap in the preview iframe.
- **All variables, ready to uncomment** — the full Bootstrap 5.3.8 `:root` light set *and* the
  `[data-bs-theme=dark]` dark set, grouped and commented, generated from the stock stylesheet.
- **Light / dark preview** — toggle the preview's `data-bs-theme` to check both modes.
- **Reset** — restore the default all-commented template.
- **Copy CSS** — copy the finished theme file to the clipboard.
- **Autosave** — your work is kept in `localStorage` (via the elm-lang runtime `Storage` module) and
  restored on your next visit.

## Layout

| File | Role |
|---|---|
| [src/Main.elm](src/Main.elm) | The `Browser.element` app: the CSS editor pane, the preview iframe, and the ports that drive it. |
| [src/theme-template.css](src/theme-template.css) | The default editor contents: every Bootstrap `--bs-*` variable, commented, grouped by section. Fetched at startup. |
| [index.template.html](index.template.html) | The host page: app chrome + editor-widget CSS, the example page rendered in the preview iframe, and the JS port wiring (Bootstrap from a CDN). |
| `vendor/` | `Highlight.elm` + `CodeEditor.elm`, copied from elm-editor at build time (git-ignored). |

## Build & run

You need the [elm-lang](https://github.com/tunguski/elm-lang) CLI and an
[elm-editor](https://github.com/tunguski/elm-editor) checkout next to this project (the build copies
two of its modules into `vendor/`). Point `ELM` at the CLI and `EDITOR` at the checkout.

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

`--no-check` is used to compile, like the other elm-lang example apps (the reused editor widget leans
on idioms the strict type checker doesn't fully analyse). It runs correctly under the elm-lang JS
backend.

## How the theming works

Bootstrap 5.3 reads its colours, spacing, radii, shadows, etc. from CSS custom properties at runtime
(`--bs-primary`, `--bs-body-bg`, `--bs-border-radius`, …). Because they are *runtime* variables, you
can override them with a stylesheet that loads after Bootstrap — no recompile needed. This tool writes
exactly that stylesheet. (Sass-only variables such as `$primary`, and anything that changes generated
selectors, can't be themed this way and aren't offered.)
