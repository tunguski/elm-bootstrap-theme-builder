port module Main exposing (main)

{-| A custom-theme builder for Bootstrap 5.3.

You edit **one** CSS file in the left pane (~30% of the screen). It starts as the complete set of
Bootstrap's `--bs-*` CSS variables, every one commented out, so out of the box the theme is empty and
the preview shows stock Bootstrap. Uncomment a variable, change its value, and the right pane — an
example page rendered with real Bootstrap inside an iframe — updates instantly: your stylesheet is
layered on top of the default Bootstrap CSS via a live `<style>` element, exactly the way a published
theme file would sit on top of `bootstrap.css`.

There is no file browser (there is only ever one file). The left pane reuses the elm-editor
code-editing widget (`CodeEditor`) with the CSS highlighter (`Highlight.cssSegments`); the preview and
clipboard are driven over ports; edits are autosaved to `localStorage` via the runtime `Storage`
module.
-}

import Browser
import CodeEditor
import Highlight
import Html exposing (Html, a, button, div, span, text)
import Html.Attributes exposing (class, classList, href, id, title)
import Html.Events exposing (onClick)
import Http
import Storage


{-| Outgoing: the composed CSS to layer on top of Bootstrap in the preview iframe. -}
port renderCss : String -> Cmd msg


{-| Outgoing: the preview's Bootstrap colour mode — `"light"` or `"dark"` (sets `data-bs-theme`). -}
port setPreviewTheme : String -> Cmd msg


{-| Outgoing: copy the given text (the finished theme CSS) to the clipboard. -}
port copyToClipboard : String -> Cmd msg


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    { code : String -- the CSS the user is editing (the whole theme file)
    , caret : Int -- caret offset, for the editor's current-line gutter
    , template : Maybe String -- the default fully-commented template, fetched at startup (for "Reset")
    , restored : Bool -- True once a saved session replaced the defaults (so the template doesn't clobber it)
    , dark : Bool -- preview Bootstrap in dark mode
    , status : Status
    }


type Status
    = Loading
    | Ready
    | Failed String


{-| The localStorage key the in-progress theme is autosaved under. -}
storageKey : String
storageKey =
    "bs-theme-builder"


init : () -> ( Model, Cmd Msg )
init _ =
    ( { code = ""
      , caret = 0
      , template = Nothing
      , restored = False
      , dark = False
      , status = Loading
      }
    , Cmd.batch
        [ Http.get { url = "theme-template.css", expect = Http.expectString TemplateLoaded }
        , Storage.load storageKey RestoreSession
        ]
    )



-- UPDATE


type Msg
    = EditCss String Int
    | TemplateLoaded (Result Http.Error String)
    | RestoreSession (Maybe String)
    | Reset
    | ToggleDark
    | Copy


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        EditCss content caret ->
            ( { model | code = content, caret = caret, status = Ready }
            , Cmd.batch [ renderCss content, Storage.save storageKey content ]
            )

        TemplateLoaded (Ok template) ->
            -- The default template arrived. Adopt it as the starting code unless a saved session
            -- already won the race; either way keep it around so "Reset" can restore it.
            if model.restored then
                ( { model | template = Just template, status = Ready }, Cmd.none )

            else
                ( { model | template = Just template, code = template, status = Ready }
                , renderCss template
                )

        TemplateLoaded (Err _) ->
            ( { model | status = Failed "Could not load theme-template.css — serve the build/ folder over HTTP." }
            , Cmd.none
            )

        RestoreSession (Just saved) ->
            -- An autosaved theme from a previous visit: restore it in place of the default template.
            if saved == "" then
                ( model, Cmd.none )

            else
                ( { model | code = saved, restored = True, status = Ready }, renderCss saved )

        RestoreSession Nothing ->
            ( model, Cmd.none )

        Reset ->
            case model.template of
                Just template ->
                    ( { model | code = template, caret = 0, status = Ready }
                    , Cmd.batch [ renderCss template, Storage.save storageKey template ]
                    )

                Nothing ->
                    ( model, Cmd.none )

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

        Copy ->
            ( model, copyToClipboard model.code )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "app" ]
        [ viewHeader model
        , div [ class "body" ]
            [ viewEditor model
            , viewPreview
            ]
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    div [ class "header" ]
        [ span [ class "logo" ] [ text "🎨" ]
        , span [ class "title" ] [ text "Bootstrap 5.3 theme builder" ]
        , span [ class "tagline" ] [ text "edit the CSS variables on the left — the preview updates live" ]
        , div [ class "actions" ]
            [ button
                [ class "btn", onClick ToggleDark, title "Toggle the preview's Bootstrap colour mode" ]
                [ text
                    (if model.dark then
                        "☀ Light preview"

                     else
                        "🌙 Dark preview"
                    )
                ]
            , button [ class "btn", onClick Reset, title "Restore the default (all-commented) template" ]
                [ text "↺ Reset" ]
            , button [ class "btn primary", onClick Copy, title "Copy the theme CSS to the clipboard" ]
                [ text "⧉ Copy CSS" ]
            ]
        ]


viewEditor : Model -> Html Msg
viewEditor model =
    div [ class "editor" ]
        [ div [ class "pane-label" ]
            [ text "theme.css"
            , span [ class "pane-hint" ] [ text "applied on top of bootstrap.css" ]
            ]
        , div [ class "editor-scroll" ]
            [ CodeEditor.view
                { source = model.code
                , caret = model.caret
                , highlight = Highlight.cssSegments
                , onChange = EditCss
                }
            ]
        , viewStatus model
        ]


viewStatus : Model -> Html Msg
viewStatus model =
    case model.status of
        Loading ->
            div [ class "status" ] [ text "Loading the variable template…" ]

        Ready ->
            div [ class "status ok" ] [ text "✓ live" ]

        Failed err ->
            div [ class "status err" ] [ text err ]


{-| The preview pane is a single iframe (built by the host page with Bootstrap + the example markup);
the app only pushes CSS and the colour mode into it over ports, so it is a constant Html node. -}
viewPreview : Html Msg
viewPreview =
    div [ class "preview" ]
        [ Html.node "iframe"
            [ id "preview-frame"
            , title "Theme preview"
            ]
            []
        ]
