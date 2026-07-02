#!/usr/bin/env bash
#
# build.sh — build the Bootstrap 5.3 theme builder.
#
# The app reuses the whole elm-editor shell (file pane, code editing, resizable panes, sharing,
# autosave) via Editor.program, plugging in its own CSS-preview pane. The shell modules are a source
# dependency declared in elm.vendored.json, resolved by the compiler at build time. Set ELM to the
# elm-lang CLI (default `elm`).
#
#   ELM=../../elm.sh ./build.sh
#
set -euo pipefail
cd "$(dirname "$0")"

ELM="${ELM:-elm}"
OUT="build"

# The editor shell modules are a source dependency declared in elm.vendored.json; the compiler
# resolves them at build time (git-deps/ at the pinned ref, or the local elm.vendored.local.json).

# 2) Compile the app (it type-checks cleanly, like the other elm-lang example apps). Absolute
#    paths are used because the elm.sh wrapper chdirs to the elm-lang project before running.
mkdir -p "$OUT"
P="$(pwd)"
echo "Compiling the theme builder with: $ELM"
$ELM make "$P/src/Main.elm" --project="$P/elm.json" -o "$P/$OUT/app.js" >/dev/null

# 3) The default (fully-commented) variable template is fetched by the app at runtime.
cp src/theme-template.css "$OUT/theme-template.css"

# 4) The editor shell's stylesheet (the .ed-* IDE chrome the host page layers its preview styles on).
cp "$EDITOR/editor.css" "$OUT/editor.css"

# 5) The host page (editor shell CSS + builder overlay, the compiled app, the preview iframe + ports).
cp index.template.html "$OUT/index.html"

echo "Done. Serve with:  npx --yes serve $OUT   (then open the printed URL)"
