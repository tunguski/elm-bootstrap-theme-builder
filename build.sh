#!/usr/bin/env bash
#
# build.sh — build the Bootstrap 5.3 theme builder.
#
# The app reuses the elm-editor code-editing widget (the syntax-highlighted textarea) for its single
# CSS file. Since Elm has no cross-project imports, we copy the two modules we need into vendor/ (a
# source-directory listed in elm.json) before compiling. Set EDITOR to the elm-editor checkout
# (default ../elm-editor) and ELM to the elm-lang CLI (default `elm`).
#
#   ELM=../../elm.sh ./build.sh
#
set -euo pipefail
cd "$(dirname "$0")"

ELM="${ELM:-elm}"
EDITOR="${EDITOR:-../elm-editor}"
OUT="build"

# 1) Vendor the editor widget + highlighter from elm-editor.
mkdir -p vendor
for m in Highlight CodeEditor; do
  if [ ! -f "$EDITOR/src/$m.elm" ]; then
    echo "build.sh: missing $EDITOR/src/$m.elm — set EDITOR to the elm-editor checkout" >&2
    exit 1
  fi
  cp "$EDITOR/src/$m.elm" "vendor/$m.elm"
done

# 2) Compile the app (the editor widget leans on idioms the strict type checker doesn't fully
#    analyse, so — like the other elm-lang example apps — we compile with --no-check). Absolute paths
#    are used because the elm.sh wrapper chdirs to the elm-lang project before running.
mkdir -p "$OUT"
P="$(pwd)"
echo "Compiling the theme builder with: $ELM"
$ELM make "$P/src/Main.elm" --project="$P/elm.json" -o "$P/$OUT/app.js" --no-check >/dev/null

# 3) The default (fully-commented) variable template is fetched by the app at runtime.
cp src/theme-template.css "$OUT/theme-template.css"

# 4) The host page (Bootstrap CDN inside the preview iframe, the compiled app, and the port wiring).
cp index.template.html "$OUT/index.html"

echo "Done. Serve with:  npx --yes serve $OUT   (then open the printed URL)"
