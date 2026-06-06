# build.ps1 — build the Bootstrap 5.3 theme builder (Windows).
#
# The app reuses the elm-editor code-editing widget. Set EDITOR to the elm-editor checkout
# (default ..\elm-editor) and ELM to the elm-lang CLI (default `elm`).
#
#   $env:ELM = 'java -jar C:\path\to\elm.jar'; ./build.ps1

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$Elm = if ($env:ELM) { $env:ELM } else { 'elm' }
$Editor = if ($env:EDITOR) { $env:EDITOR } else { '..\elm-editor' }
$Out = 'build'

# 1) Vendor the editor widget + highlighter from elm-editor.
New-Item -ItemType Directory -Force -Path vendor | Out-Null
foreach ($m in 'Highlight','CodeEditor') {
  $srcFile = Join-Path $Editor "src/$m.elm"
  if (-not (Test-Path $srcFile)) {
    Write-Error "missing $srcFile - set EDITOR to the elm-editor checkout"
  }
  Copy-Item $srcFile "vendor/$m.elm" -Force
}

# 2) Compile the app (--no-check: like the other elm-lang example apps). Absolute paths are used
#    because the elm.sh/elm wrapper may chdir to the elm-lang project before running.
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$P = (Get-Location).Path
Write-Host "Compiling the theme builder with: $Elm"
& cmd /c "$Elm make `"$P/src/Main.elm`" --project=`"$P/elm.json`" -o `"$P/$Out/app.js`" --no-check" | Out-Null

# 3) The default variable template is fetched by the app at runtime.
Copy-Item src/theme-template.css "$Out/theme-template.css" -Force

# 4) The host page (Bootstrap CDN inside the preview iframe, the app, and the port wiring).
Copy-Item index.template.html "$Out/index.html" -Force

Write-Host "Done. Serve with:  npx --yes serve $Out"
