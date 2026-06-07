port module BootstrapPreview exposing (Model, Msg, spec)

{-| The result pane for the Bootstrap theme builder, plugged into the reusable `Editor` shell as a
`Preview.Spec`. It renders a live preview iframe (built by the host page with Bootstrap + an example
layout) and pushes the edited CSS — the currently selected file — into it over the `renderCss` port.
A small toolbar toggles the preview's colour mode (`setPreviewTheme`) and copies the theme CSS
(`copyToClipboard`). The shell owns the file/editing chrome; this module owns only the preview.
-}

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class, id, title)
import Html.Events exposing (onClick)
import Preview exposing (Context)


{-| Outgoing: the composed CSS to layer on top of Bootstrap in the preview iframe. -}
port renderCss : String -> Cmd msg


{-| Outgoing: the preview's Bootstrap colour mode — `"light"` or `"dark"` (sets `data-bs-theme`). -}
port setPreviewTheme : String -> Cmd msg


{-| Outgoing: copy the given text (the finished theme CSS) to the clipboard. -}
port copyToClipboard : String -> Cmd msg


{-| The preview's own state: just the colour mode it is showing. -}
type alias Model =
    { dark : Bool }


type Msg
    = ToggleDark
    | Copy String


{-| The pluggable preview the Bootstrap builder wires into `Editor.program`. -}
spec : Preview.Spec Model Msg
spec =
    { init = \ctx -> ( { dark = False }, renderCss (currentCss ctx) )
    , sourcesChanged = \ctx model -> ( model, renderCss (currentCss ctx) )
    , update = update
    , subscriptions = \_ _ -> Sub.none
    , view = view
    , error = \_ -> Nothing
    , onAddFile = Nothing
    , takeNewFile = \_ -> Nothing
    }


update : Context -> Msg -> Model -> ( Model, Cmd Msg )
update _ msg model =
    case msg of
        ToggleDark ->
            let
                dark =
                    not model.dark
            in
            ( { model | dark = dark }
            , setPreviewTheme
                (if dark then
                    "dark"

                 else
                    "light"
                )
            )

        Copy css ->
            ( model, copyToClipboard css )


view : Context -> Model -> Html Msg
view ctx model =
    div [ class "bs-preview" ]
        [ div [ class "bs-toolbar" ]
            [ button
                [ class "bs-btn", onClick ToggleDark, title "Toggle the preview's Bootstrap colour mode" ]
                [ text
                    (if model.dark then
                        "☀ Light preview"

                     else
                        "🌙 Dark preview"
                    )
                ]
            , button
                [ class "bs-btn", onClick (Copy (currentCss ctx)), title "Copy the theme CSS to the clipboard" ]
                [ text "⧉ Copy CSS" ]
            ]
        , Html.node "iframe" [ id "preview-frame", title "Theme preview" ] []
        ]


{-| The CSS currently being edited (the selected file's contents). -}
currentCss : Context -> String
currentCss ctx =
    lookup ctx.selected ctx.files |> Maybe.withDefault ""


lookup : String -> List ( String, String ) -> Maybe String
lookup name files =
    case files of
        ( n, content ) :: rest ->
            if n == name then
                Just content

            else
                lookup name rest

        [] ->
            Nothing
