module ThemeForm exposing (tabs, view)

{-| The Bootstrap theme builder's structured "typed form" view of the single CSS file, plugged into
the `Editor` shell as its `formEditor`. The shell shows a code/form toggle in the code pane's title
bar; in form mode it renders these two tabs:

  - **Properties** — every Bootstrap `--bs-*` variable in the file as a row: a checkbox (ticked when
    the variable is active, i.e. *uncommented* in the CSS) and a text field for its value. Ticking the
    box uncomments the line; clearing it comments it back out. Editing the field replaces the value.
    The rows are grouped by their CSS block (`:root`, `[data-bs-theme=dark]`) and the template's
    `/* === … === */` section headers.

  - **Component styles** — a plain CSS code editor over the free-form component overrides below the
    `marker` line (the part of the file that isn't simple variable declarations).

Both tabs are pure functions of the file's text and emit the **new full source** on every change, so
the form, the code editor and the live preview never diverge. All edits are done in place, line by
line (identified by absolute line index), so comments, formatting and the component section are
preserved untouched.
-}

import CodeEditor
import Highlight
import Html exposing (Html, div, input, label, span, text)
import Html.Attributes exposing (checked, class, classList, type_, value)
import Html.Events exposing (onCheck, onInput)


{-| The form's two tabs, in order (the shell renders the tab bar from these labels). -}
tabs : List String
tabs =
    [ "Properties", "Component styles" ]


{-| The line that divides the variable declarations (the Properties tab's territory) from the
free-form component CSS (the Component styles tab's). The template ships with it in place. -}
marker : String
marker =
    "/* ===== component styles — edit freely below ===== */"


{-| The opening line of the block the Wizard tab generates (it sits just before `marker`). The
Properties tab stops at it so the wizard's generated `:root`/component rules aren't shown as editable
variable rows. Must match `ThemeWizard.wizardBegin`. -}
wizardBegin : String
wizardBegin =
    "/* @wizard:begin — generated; edit knobs in the Wizard tab */"


{-| The index at which the variable region ends: the first of the wizard block or the component
marker (or the end of the file if neither is present). -}
varsEnd : List String -> Int
varsEnd lines =
    [ wizardBegin, marker ]
        |> List.filterMap (\mk -> indexWhere (\l -> String.trim l == mk) lines)
        |> List.minimum
        |> Maybe.withDefault (List.length lines)


{-| Render the active tab's body. The emitted message is the new full source. -}
view : Int -> String -> Html String
view tab source =
    case tab of
        1 ->
            componentsView source

        _ ->
            propertiesView source



-- PROPERTIES TAB


{-| One parsed entry of the variables region: a block header, a section label, or a property row. -}
type Item
    = Group String
    | Section String
    | Prop { line : Int, name : String, valueText : String, on : Bool }


propertiesView : String -> Html String
propertiesView source =
    let
        lines =
            String.lines source

        varsLines =
            List.take (varsEnd lines) lines

        items =
            List.indexedMap parseLine varsLines |> List.filterMap identity
    in
    div [ class "bs-form-props" ] (List.map (renderItem source) items)


{-| Classify one line of the variables region (its index is the absolute line index, since the
variables region is the file's prefix). -}
parseLine : Int -> String -> Maybe Item
parseLine i line =
    let
        t =
            String.trim line
    in
    if t == "" then
        Nothing

    else if String.startsWith "/* ===" t then
        Just (Section (sectionLabel t))

    else if String.endsWith "{" t then
        Just (Group (String.trimRight (String.dropRight 1 t)))

    else
        case parseVarLine line of
            Just p ->
                Just (Prop { line = i, name = p.name, valueText = p.value, on = p.on })

            Nothing ->
                Nothing


renderItem : String -> Item -> Html String
renderItem source item =
    case item of
        Group g ->
            div [ class "bs-form-group" ] [ text g ]

        Section s ->
            div [ class "bs-form-section" ] [ text s ]

        Prop p ->
            propRow source p


propRow : String -> { line : Int, name : String, valueText : String, on : Bool } -> Html String
propRow source p =
    div [ classList [ ( "bs-prop-row", True ), ( "on", p.on ) ] ]
        [ label [ class "bs-prop-check" ]
            [ input
                [ type_ "checkbox"
                , checked p.on
                , onCheck (\_ -> toggleLine p.line source)
                ]
                []
            , span [ class "bs-prop-name" ] [ text p.name ]
            ]
        , input
            [ class "bs-prop-val"
            , type_ "text"
            , value p.valueText
            , onInput (\v -> setValueAt p.line v source)
            ]
            []
        ]



-- COMPONENT STYLES TAB


componentsView : String -> Html String
componentsView source =
    let
        lines =
            String.lines source

        compText =
            case indexWhere (\l -> String.trim l == marker) lines of
                Just m ->
                    String.join "\n" (List.drop (m + 1) lines)

                Nothing ->
                    ""
    in
    div [ class "bs-form-components" ]
        [ CodeEditor.view
            { source = compText
            , caret = 0
            , gutter = True
            , highlight = Highlight.cssSegments
            , onChange = \new _ -> setComponents new source
            , onKey = Nothing
            }
        ]


{-| Splice a new component-CSS body back into the file, leaving the variable region untouched. If the
file has no marker yet, append one (and the new body) so the split exists from now on. -}
setComponents : String -> String -> String
setComponents newComps source =
    let
        lines =
            String.lines source
    in
    case indexWhere (\l -> String.trim l == marker) lines of
        Just m ->
            String.join "\n" (List.take (m + 1) lines ++ String.lines newComps)

        Nothing ->
            source ++ "\n\n" ++ marker ++ "\n" ++ newComps



-- LINE-LEVEL EDITS (by absolute line index, preserving everything else)


{-| Toggle line `i` between active and commented (`--x: v;` ⇄ `/* --x: v; */`). -}
toggleLine : Int -> String -> String
toggleLine i source =
    mapLineAt i
        (\line ->
            case parseVarLine line of
                Just p ->
                    renderVarLine p.indent (not p.on) p.name p.value

                Nothing ->
                    line
        )
        source


{-| Replace the value on line `i`, keeping its name and its active/commented state. -}
setValueAt : Int -> String -> String -> String
setValueAt i newVal source =
    mapLineAt i
        (\line ->
            case parseVarLine line of
                Just p ->
                    renderVarLine p.indent p.on p.name newVal

                Nothing ->
                    line
        )
        source


mapLineAt : Int -> (String -> String) -> String -> String
mapLineAt i f source =
    String.lines source
        |> List.indexedMap
            (\j line ->
                if j == i then
                    f line

                else
                    line
            )
        |> String.join "\n"



-- VARIABLE LINE PARSING / RENDERING


{-| Parse a CSS custom-property line (commented or not) into its indentation, active state, name and
value — or `Nothing` if the line isn't a `--variable: value;` declaration. -}
parseVarLine : String -> Maybe { indent : String, on : Bool, name : String, value : String }
parseVarLine line =
    let
        indent =
            leadingWhitespace line

        t =
            String.trim line

        ( on, inner ) =
            if String.startsWith "/*" t && String.endsWith "*/" t then
                ( False, String.trim (String.dropRight 2 (String.dropLeft 2 t)) )

            else
                ( True, t )
    in
    if String.startsWith "--" inner then
        case splitColon inner of
            Just ( n, v ) ->
                Just { indent = indent, on = on, name = String.trim n, value = cleanValue v }

            Nothing ->
                Nothing

    else
        Nothing


{-| Render a variable line back to text: active as `indent--name: value;`, commented wrapped in
`/* … */`. The value's trailing `;` is normalised so editing never doubles or drops it. -}
renderVarLine : String -> Bool -> String -> String -> String
renderVarLine indent on name value =
    let
        v =
            cleanValue value

        decl =
            name ++ ": " ++ v ++ ";"
    in
    if on then
        indent ++ decl

    else
        indent ++ "/* " ++ decl ++ " */"


{-| A value as it should appear before the trailing `;`: trimmed, with any trailing `;` removed. -}
cleanValue : String -> String
cleanValue v =
    let
        vt =
            String.trim v
    in
    if String.endsWith ";" vt then
        String.trimRight (String.dropRight 1 vt)

    else
        vt


{-| The label inside a `/* === Label === */` section comment. -}
sectionLabel : String -> String
sectionLabel t =
    String.trim (String.replace "=" "" (String.trim (String.dropRight 2 (String.dropLeft 2 t))))


{-| Split on the first `:`, returning the parts around it (the value may itself contain `:`). -}
splitColon : String -> Maybe ( String, String )
splitColon s =
    case String.indexes ":" s of
        i :: _ ->
            Just ( String.left i s, String.dropLeft (i + 1) s )

        [] ->
            Nothing


leadingWhitespace : String -> String
leadingWhitespace s =
    String.left (String.length s - String.length (String.trimLeft s)) s


indexWhere : (a -> Bool) -> List a -> Maybe Int
indexWhere pred xs =
    indexWhereHelp 0 pred xs


indexWhereHelp : Int -> (a -> Bool) -> List a -> Maybe Int
indexWhereHelp i pred xs =
    case xs of
        x :: rest ->
            if pred x then
                Just i

            else
                indexWhereHelp (i + 1) pred rest

        [] ->
            Nothing
