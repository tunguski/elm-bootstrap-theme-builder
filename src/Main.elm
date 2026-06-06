module Main exposing (main)

{-| A custom-theme builder for Bootstrap 5.3, built on the reusable `Editor` shell.

You edit a CSS file — the complete set of Bootstrap's `--bs-*` CSS variables, every one commented out,
so out of the box the theme is empty and the preview shows stock Bootstrap. Uncomment a variable,
change its value, and the right pane — an example page rendered with real Bootstrap inside an iframe —
updates instantly. The shell provides the IDE chrome (file pane, code editing, resizable panes,
sharing, autosave); this module just supplies the CSS configuration (`Highlight.cssSegments`, the
template as the starting file) and the Bootstrap preview pane (`BootstrapPreview`).
-}

import BootstrapPreview
import Editor
import Highlight


main : Program () (Editor.Model BootstrapPreview.Model BootstrapPreview.Msg) (Editor.Msg BootstrapPreview.Msg)
main =
    Editor.program
        { preview = BootstrapPreview.spec
        , intel = cssIntel
        , initialFiles = [ ( templateName, "" ) ]
        , urls = [ templateName ]
        , libUrls = []
        , title = "Bootstrap 5.3 theme builder"
        , tagline = "edit the CSS variables — the preview updates live"
        , sessionKey = "bs-theme-builder"
        }


{-| The single editable file. A placeholder shares the template's URL key, so the shell's startup
fetch of `theme-template.css` replaces the placeholder with the real (all-commented) template. -}
templateName : String
templateName =
    "theme-template.css"


{-| CSS code intelligence: the CSS highlighter, and no autocomplete or error squiggle (a stylesheet
has no interpreter errors to locate). -}
cssIntel : Editor.CodeIntel
cssIntel =
    { highlight = Highlight.cssSegments
    , completions = \_ _ -> []
    , accept = \source caret _ -> ( source, caret )
    , locate = \_ _ -> Nothing
    }
