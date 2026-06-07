module ThemeWizard exposing (view)

{-| The Bootstrap theme builder's **Wizard** panel: a handful of high-level knobs (corners, spacing,
colour palette, heading sizes, body font size, border width, base font) that generate a block of
Bootstrap `--bs-*` overrides (and the component rules Bootstrap can't drive from `:root` alone).

It is stateless: the chosen knob values are encoded in a `@wizard:config …` comment at the top of the
generated block, so the CSS file stays the single source of truth. `view` reads that comment to show
the current selection, and each control regenerates the whole block — delimited by `wizardBegin` …
`wizardEnd` — in place, leaving the rest of the file (the Properties variables, the component styles)
untouched. The block is inserted just before the component-styles marker, so it overrides the
template's defaults while the free-form component CSS still wins last.

The colour palette offers ten presets plus a **custom** mode: pick one to three seed colours and the
generator derives every themed colour (the `-rgb`/`-text-emphasis`/`-bg-subtle`/`-border-subtle`
families, the link colours and per-variant button colours with hover/active shades and a readable
text colour) from them.
-}

import Html exposing (Html, button, div, input, label, option, select, span, text)
import Html.Attributes exposing (class, classList, selected, type_, value)
import Html.Events exposing (onClick, onInput)



-- MARKERS (wizardBegin must match ThemeForm.wizardBegin)


wizardBegin : String
wizardBegin =
    "/* @wizard:begin — generated; edit knobs in the Wizard tab */"


wizardEnd : String
wizardEnd =
    "/* @wizard:end */"


configPrefix : String
configPrefix =
    "/* @wizard:config"


{-| Where the block is inserted: just before the component-styles marker (matches `ThemeForm.marker`). -}
componentMarker : String
componentMarker =
    "/* ===== component styles — edit freely below ===== */"



-- SETTINGS


type alias Settings =
    { corners : String -- none | small | medium | large
    , spacing : String -- small | medium | large
    , palette : String -- a preset key, used when custom is False
    , custom : Bool
    , c1 : String -- custom seeds (hex): primary
    , c2 : String -- secondary (blank = derived from primary)
    , c3 : String -- accent / info (blank = derived)
    , c4 : String -- success (blank = derived from primary)
    , c5 : String -- danger (blank = derived)
    , c6 : String -- warning (blank = derived)
    , headings : String -- small | medium | big
    , font : Int -- 12 | 16 | 18  (px)
    , border : String -- thin | medium | thick
    , family : String -- system | serif | mono
    }


defaults : Settings
defaults =
    { corners = "medium"
    , spacing = "medium"
    , palette = "default"
    , custom = False
    , c1 = "#0d6efd"
    , c2 = "#6c757d"
    , c3 = "#0dcaf0"
    , c4 = ""
    , c5 = ""
    , c6 = ""
    , headings = "medium"
    , font = 16
    , border = "thin"
    , family = "system"
    }



-- VIEW


view : String -> Html String
view source =
    let
        s =
            readSettings source

        apply : Settings -> String
        apply next =
            applyWizard next source
    in
    div [ class "wz-form" ]
        [ div [ class "wz-intro" ]
            [ text "Set a few high-level knobs; the wizard writes the matching Bootstrap overrides into your theme." ]
        , paletteSection s apply
        , segmented "Corners (rounding)"
            [ ( "none", "None" ), ( "small", "Small" ), ( "medium", "Medium" ), ( "large", "Large" ) ]
            s.corners
            (\v -> apply { s | corners = v })
        , segmented "Spacing (padding)"
            [ ( "small", "Small" ), ( "medium", "Medium" ), ( "large", "Large" ) ]
            s.spacing
            (\v -> apply { s | spacing = v })
        , segmented "Headings & leads"
            [ ( "small", "Small" ), ( "medium", "Medium" ), ( "big", "Big" ) ]
            s.headings
            (\v -> apply { s | headings = v })
        , segmented "Body text size"
            [ ( "12", "12px" ), ( "16", "16px" ), ( "18", "18px" ) ]
            (String.fromInt s.font)
            (\v -> apply { s | font = Maybe.withDefault 16 (String.toInt v) })
        , segmented "Border width"
            [ ( "thin", "Thin" ), ( "medium", "Medium" ), ( "thick", "Thick" ) ]
            s.border
            (\v -> apply { s | border = v })
        , selectRow "Base font"
            [ ( "system", "System sans" ), ( "serif", "Serif" ), ( "mono", "Monospace" ) ]
            s.family
            (\v -> apply { s | family = v })
        , div [ class "wz-actions" ]
            [ button [ class "wz-reset", onClick (removeBlock source) ]
                [ text "Remove wizard styles" ]
            ]
        ]


{-| The colour-palette control: a preset dropdown, a "custom palette" toggle, and (when custom) one
to three seed-colour pickers. -}
paletteSection : Settings -> (Settings -> String) -> Html String
paletteSection s apply =
    div [ class "wz-row wz-palette" ]
        [ div [ class "wz-label" ] [ text "Colour palette" ]
        , div [ class "wz-palette-body" ]
            [ select
                [ class "wz-select"
                , onInput (\v -> apply (pickPreset v s))
                ]
                (List.map (\( key, lbl, _ ) -> option [ value key, selected (key == s.palette) ] [ text lbl ]) presets)
            , label [ class "wz-check" ]
                [ input
                    [ type_ "checkbox"
                    , Html.Attributes.checked s.custom
                    , Html.Events.onCheck
                        (\c ->
                            apply
                                (if c then
                                    seedFrom s.palette { s | custom = True }

                                 else
                                    { s | custom = False }
                                )
                        )
                    ]
                    []
                , span [] [ text "Custom palette" ]
                ]
            , if s.custom then
                let
                    -- Show each picker at its *resolved* colour, so the derived ones (secondary,
                    -- accent and the semantic colours) display real values and update live as the
                    -- primary changes, rather than showing black for a blank seed.
                    p =
                        customPalette s
                in
                div [ class "wz-seeds-grid" ]
                    [ div [ class "wz-seeds" ]
                        [ seedPicker "Primary" p.primary (\v -> apply { s | c1 = v })
                        , seedPicker "Secondary" p.secondary (\v -> apply { s | c2 = v })
                        , seedPicker "Accent" p.info (\v -> apply { s | c3 = v })
                        ]
                    , div [ class "wz-seeds" ]
                        [ seedPicker "Success" p.success (\v -> apply { s | c4 = v })
                        , seedPicker "Danger" p.danger (\v -> apply { s | c5 = v })
                        , seedPicker "Warning" p.warning (\v -> apply { s | c6 = v })
                        ]
                    , div [ class "wz-hint" ]
                        [ text "Start from a preset; the semantic colours are derived from your primary — tweak any of the six." ]
                    ]

              else
                text ""
            ]
        ]


{-| Choosing a preset in the dropdown: in custom mode it seeds the three custom colours from the
preset (so the user can then tweak only some); otherwise it just selects the preset. -}
pickPreset : String -> Settings -> Settings
pickPreset key s =
    if s.custom then
        seedFrom key { s | palette = key }

    else
        { s | palette = key }


{-| Seed the custom colours from a preset: primary / secondary / accent come from the preset; the
semantic seeds are cleared so success / danger / warning re-derive from the new primary. -}
seedFrom : String -> Settings -> Settings
seedFrom key s =
    let
        p =
            presetByKey key
    in
    { s | palette = key, c1 = p.primary, c2 = p.secondary, c3 = p.info, c4 = "", c5 = "", c6 = "" }


presetByKey : String -> Palette
presetByKey key =
    case List.filter (\( k, _, _ ) -> k == key) presets of
        ( _, _, p ) :: _ ->
            p

        [] ->
            bootstrapDefault


seedPicker : String -> String -> (String -> String) -> Html String
seedPicker name current onPick =
    label [ class "wz-seed" ]
        [ input [ type_ "color", value (normaliseHex current), onInput onPick ] []
        , span [] [ text name ]
        ]


{-| A labelled segmented button group (radio-like): one button per option, the active one highlighted. -}
segmented : String -> List ( String, String ) -> String -> (String -> String) -> Html String
segmented labelText opts current onPick =
    div [ class "wz-row" ]
        [ div [ class "wz-label" ] [ text labelText ]
        , div [ class "wz-seg" ]
            (List.map
                (\( val, lbl ) ->
                    button
                        [ classList [ ( "wz-opt", True ), ( "active", val == current ) ]
                        , onClick (onPick val)
                        ]
                        [ text lbl ]
                )
                opts
            )
        ]


selectRow : String -> List ( String, String ) -> String -> (String -> String) -> Html String
selectRow labelText opts current onPick =
    div [ class "wz-row" ]
        [ div [ class "wz-label" ] [ text labelText ]
        , select [ class "wz-select", onInput onPick ]
            (List.map (\( val, lbl ) -> option [ value val, selected (val == current) ] [ text lbl ]) opts)
        ]



-- READING SETTINGS FROM THE SOURCE


readSettings : String -> Settings
readSettings source =
    case List.filter (\l -> String.startsWith configPrefix (String.trimLeft l)) (String.lines source) of
        line :: _ ->
            settingsFrom (parseConfig line)

        [] ->
            defaults


{-| Parse a `/* @wizard:config k=v k=v … */` line into key/value pairs. -}
parseConfig : String -> List ( String, String )
parseConfig line =
    let
        inner =
            line
                |> String.trim
                |> dropPrefix configPrefix
                |> dropSuffix "*/"
                |> String.trim
    in
    inner
        |> String.words
        |> List.filterMap
            (\tok ->
                case String.indexes "=" tok of
                    i :: _ ->
                        Just ( String.left i tok, String.dropLeft (i + 1) tok )

                    [] ->
                        Nothing
            )


settingsFrom : List ( String, String ) -> Settings
settingsFrom kv =
    let
        g key dflt =
            case List.filter (\( k, _ ) -> k == key) kv of
                ( _, v ) :: _ ->
                    if v == "" then
                        dflt

                    else
                        v

                [] ->
                    dflt
    in
    { corners = g "corners" defaults.corners
    , spacing = g "spacing" defaults.spacing
    , palette = g "palette" defaults.palette
    , custom = g "custom" "off" == "on"
    , c1 = g "c1" defaults.c1
    , c2 = g "c2" defaults.c2
    , c3 = g "c3" defaults.c3
    , c4 = g "c4" defaults.c4
    , c5 = g "c5" defaults.c5
    , c6 = g "c6" defaults.c6
    , headings = g "headings" defaults.headings
    , font = Maybe.withDefault defaults.font (String.toInt (g "font" (String.fromInt defaults.font)))
    , border = g "border" defaults.border
    , family = g "family" defaults.family
    }


configLine : Settings -> String
configLine s =
    configPrefix
        ++ " corners="
        ++ s.corners
        ++ " spacing="
        ++ s.spacing
        ++ " palette="
        ++ s.palette
        ++ " custom="
        ++ (if s.custom then
                "on"

            else
                "off"
           )
        ++ " c1="
        ++ s.c1
        ++ " c2="
        ++ s.c2
        ++ " c3="
        ++ s.c3
        ++ " c4="
        ++ s.c4
        ++ " c5="
        ++ s.c5
        ++ " c6="
        ++ s.c6
        ++ " headings="
        ++ s.headings
        ++ " font="
        ++ String.fromInt s.font
        ++ " border="
        ++ s.border
        ++ " family="
        ++ s.family
        ++ " */"



-- APPLYING / REMOVING THE BLOCK


{-| Apply the settings to `source`: write the variable knobs (colours, radius, font size, border
width, font family) straight into the editable `:root` block — uncommenting and setting each — so
they show up checked in the Form's Properties tab and in context in the source; and splice the
component rules (buttons, spacing, headings) that `:root` can't drive into a managed block before the
component-styles marker. Returns the new full source. -}
applyWizard : Settings -> String -> String
applyWizard settings source =
    source
        |> setRootVars (rootVarDecls settings)
        |> spliceBlock (componentBlock settings)


{-| Undo the wizard ("Remove wizard styles"): re-comment the `:root` variables it manages and remove
the generated component block. -}
removeBlock : String -> String
removeBlock source =
    source
        |> commentRootVars (List.map Tuple.first (rootVarDecls (readSettings source)))
        |> stripComponentBlock


stripComponentBlock : String -> String
stripComponentBlock source =
    let
        lines =
            String.lines source
    in
    case ( lineIndex wizardBegin lines, lineIndex wizardEnd lines ) of
        ( Just b, Just e ) ->
            if e >= b then
                String.join "\n" (dropBlankAround b (List.take b lines ++ List.drop (e + 1) lines))

            else
                source

        _ ->
            source


{-| Set each `(name, value)` declaration active in the first (light) `:root { … }` block: the line
for that variable — commented or not — becomes `  name: value;`. Names not present are left alone
(every variable the wizard sets exists in the template). -}
setRootVars : List ( String, String ) -> String -> String
setRootVars decls source =
    mapRootBlock
        (\line ->
            case varNameOf line of
                Just nm ->
                    case lookupAssoc nm decls of
                        Just v ->
                            "  " ++ nm ++ ": " ++ v ++ ";"

                        Nothing ->
                            line

                Nothing ->
                    line
        )
        source


{-| Comment out (deactivate) the named variables in the `:root` block — the inverse of `setRootVars`. -}
commentRootVars : List String -> String -> String
commentRootVars names source =
    mapRootBlock
        (\line ->
            let
                t =
                    String.trim line
            in
            case varNameOf line of
                Just nm ->
                    if String.startsWith "--" t && List.member nm names then
                        "  /* " ++ t ++ " */"

                    else
                        line

                Nothing ->
                    line
        )
        source


{-| Apply `f` to every line inside the first `:root { … }` block (between its braces). -}
mapRootBlock : (String -> String) -> String -> String
mapRootBlock f source =
    let
        lines =
            String.lines source

        ( lo, hi ) =
            rootRange lines
    in
    if lo < 0 then
        source

    else
        lines
            |> List.indexedMap
                (\j line ->
                    if j > lo && j < hi then
                        f line

                    else
                        line
                )
            |> String.join "\n"


{-| The line range `( open, close )` of the first `:root { … }` block (`( -1, -1 )` if none). -}
rootRange : List String -> ( Int, Int )
rootRange lines =
    case indexWhere (\l -> String.startsWith ":root" (String.trim l) && String.endsWith "{" (String.trim l)) lines of
        Just o ->
            case indexWhereFrom (o + 1) (\l -> String.trim l == "}") lines of
                Just c ->
                    ( o, c )

                Nothing ->
                    ( o, List.length lines )

        Nothing ->
            ( -1, -1 )


{-| The variable name on a declaration line (commented or active), or `Nothing` if it isn't one. -}
varNameOf : String -> Maybe String
varNameOf line =
    let
        t =
            String.trim line

        inner =
            if String.startsWith "/*" t && String.endsWith "*/" t then
                String.trim (String.dropRight 2 (String.dropLeft 2 t))

            else
                t
    in
    if String.startsWith "--" inner then
        case String.indexes ":" inner of
            i :: _ ->
                Just (String.trim (String.left i inner))

            [] ->
                Nothing

    else
        Nothing


spliceBlock : String -> String -> String
spliceBlock block source =
    let
        lines =
            String.lines source

        blockLines =
            String.lines block
    in
    case ( lineIndex wizardBegin lines, lineIndex wizardEnd lines ) of
        ( Just b, Just e ) ->
            if e >= b then
                String.join "\n" (List.take b lines ++ blockLines ++ List.drop (e + 1) lines)

            else
                insertBefore componentMarker blockLines lines

        _ ->
            insertBefore componentMarker blockLines lines


{-| Insert `blockLines` (with a blank line on each side) just before the first line matching `mark`,
or at the end of the file if it isn't found. -}
insertBefore : String -> List String -> List String -> String
insertBefore mark blockLines lines =
    case lineIndex mark lines of
        Just m ->
            String.join "\n" (List.take m lines ++ blockLines ++ [ "" ] ++ List.drop m lines)

        Nothing ->
            String.join "\n" (lines ++ [ "", "" ] ++ blockLines)


{-| Drop a single blank line left dangling where the block was removed (cosmetic). -}
dropBlankAround : Int -> List String -> List String
dropBlankAround i lines =
    case nth i lines of
        Just "" ->
            List.take i lines ++ List.drop (i + 1) lines

        _ ->
            lines


lineIndex : String -> List String -> Maybe Int
lineIndex mark lines =
    indexWhere (\l -> String.trim l == mark) lines



-- GENERATING THE BLOCK


{-| The managed component block: the rules `:root` variables can't drive (per-variant buttons, the
spacing/heading overrides), wrapped in the begin/config/end markers. The variable knobs are written
into `:root` separately (see `setRootVars`). -}
componentBlock : Settings -> String
componentBlock s =
    let
        p =
            resolvePalette s
    in
    String.join "\n"
        ([ wizardBegin, configLine s ]
            ++ buttonRules p
            ++ spacingRules s
            ++ headingRules s
            ++ [ wizardEnd ]
        )


{-| The `( name, value )` variable declarations the wizard writes into `:root` — all of which exist in
the template, so they round-trip cleanly. -}
rootVarDecls : Settings -> List ( String, String )
rootVarDecls s =
    radiusPairs s.corners
        ++ [ ( "--bs-body-font-size", String.fromInt s.font ++ "px" )
           , ( "--bs-border-width", borderWidth s.border )
           , ( "--bs-body-font-family", fontFamily s.family )
           ]
        ++ colorPairs (resolvePalette s)


radiusPairs : String -> List ( String, String )
radiusPairs corners =
    let
        ( r, sm, lg ) =
            case corners of
                "none" ->
                    ( "0", "0", "0" )

                "small" ->
                    ( "0.2rem", "0.15rem", "0.3rem" )

                "large" ->
                    ( "0.75rem", "0.5rem", "1rem" )

                _ ->
                    ( "0.375rem", "0.25rem", "0.5rem" )

        xl =
            case corners of
                "none" ->
                    "0"

                "small" ->
                    "0.5rem"

                "large" ->
                    "1.5rem"

                _ ->
                    "1rem"
    in
    [ ( "--bs-border-radius", r )
    , ( "--bs-border-radius-sm", sm )
    , ( "--bs-border-radius-lg", lg )
    , ( "--bs-border-radius-xl", xl )
    ]


borderWidth : String -> String
borderWidth b =
    case b of
        "medium" ->
            "2px"

        "thick" ->
            "3px"

        _ ->
            "1px"


fontFamily : String -> String
fontFamily f =
    case f of
        "serif" ->
            "Georgia, Cambria, \"Times New Roman\", Times, serif"

        "mono" ->
            "var(--bs-font-monospace)"

        _ ->
            "var(--bs-font-sans-serif)"


{-| The full set of themed-colour `( name, value )` pairs for a palette: each colour's
base/rgb/emphasis/subtle family, plus the link colours derived from `primary`. -}
colorPairs : Palette -> List ( String, String )
colorPairs p =
    List.concatMap colorFamilyPairs
        [ ( "primary", p.primary )
        , ( "secondary", p.secondary )
        , ( "success", p.success )
        , ( "info", p.info )
        , ( "warning", p.warning )
        , ( "danger", p.danger )
        , ( "light", p.light )
        , ( "dark", p.dark )
        ]
        ++ [ ( "--bs-link-color", p.primary )
           , ( "--bs-link-color-rgb", rgbOf p.primary )
           , ( "--bs-link-hover-color", mixHex p.primary "#000000" 0.2 )
           , ( "--bs-link-hover-color-rgb", rgbOf (mixHex p.primary "#000000" 0.2) )
           ]


colorFamilyPairs : ( String, String ) -> List ( String, String )
colorFamilyPairs ( name, c ) =
    [ ( "--bs-" ++ name, c )
    , ( "--bs-" ++ name ++ "-rgb", rgbOf c )
    , ( "--bs-" ++ name ++ "-text-emphasis", mixHex c "#000000" 0.6 )
    , ( "--bs-" ++ name ++ "-bg-subtle", mixHex c "#ffffff" 0.8 )
    , ( "--bs-" ++ name ++ "-border-subtle", mixHex c "#ffffff" 0.6 )
    ]


{-| Per-variant solid and outline button overrides (Bootstrap compiles these from Sass, so `:root`
variables don't reach them — we set the components directly). -}
buttonRules : Palette -> List String
buttonRules p =
    List.concatMap buttonRule
        [ ( "primary", p.primary )
        , ( "secondary", p.secondary )
        , ( "success", p.success )
        , ( "danger", p.danger )
        , ( "warning", p.warning )
        , ( "info", p.info )
        ]


buttonRule : ( String, String ) -> List String
buttonRule ( v, c ) =
    let
        hover =
            mixHex c "#000000" 0.15

        active =
            mixHex c "#000000" 0.2

        txt =
            contrast c
    in
    [ "." ++ "btn-" ++ v ++ " { "
        ++ joinDecls
            [ decl "--bs-btn-bg" c
            , decl "--bs-btn-border-color" c
            , decl "--bs-btn-color" txt
            , decl "--bs-btn-hover-bg" hover
            , decl "--bs-btn-hover-border-color" hover
            , decl "--bs-btn-hover-color" txt
            , decl "--bs-btn-active-bg" active
            , decl "--bs-btn-active-border-color" active
            , decl "--bs-btn-active-color" txt
            , decl "--bs-btn-disabled-bg" c
            , decl "--bs-btn-disabled-border-color" c
            , decl "--bs-btn-disabled-color" txt
            ]
        ++ " }"
    , ".btn-outline-" ++ v ++ " { "
        ++ joinDecls
            [ decl "--bs-btn-color" c
            , decl "--bs-btn-border-color" c
            , decl "--bs-btn-hover-bg" c
            , decl "--bs-btn-hover-border-color" c
            , decl "--bs-btn-hover-color" txt
            , decl "--bs-btn-active-bg" c
            , decl "--bs-btn-active-border-color" c
            , decl "--bs-btn-active-color" txt
            ]
        ++ " }"
    ]


{-| Component padding overrides scaled by the spacing knob (most paddings are component `--bs-*`
variables Bootstrap reads at runtime; a couple are literal). -}
spacingRules : Settings -> List String
spacingRules s =
    let
        f =
            case s.spacing of
                "small" ->
                    0.6

                "large" ->
                    1.5

                _ ->
                    1.0

        r base =
            rem (base * f)
    in
    [ ".btn { " ++ joinDecls [ decl "--bs-btn-padding-x" (r 0.75), decl "--bs-btn-padding-y" (r 0.375) ] ++ " }"
    , ".card { " ++ joinDecls [ decl "--bs-card-spacer-y" (r 1.0), decl "--bs-card-spacer-x" (r 1.0) ] ++ " }"
    , ".navbar { " ++ joinDecls [ decl "--bs-navbar-padding-y" (r 0.5), decl "--bs-navbar-padding-x" (r 0.5) ] ++ " }"
    , ".alert { " ++ joinDecls [ decl "--bs-alert-padding-y" (r 1.0), decl "--bs-alert-padding-x" (r 1.0) ] ++ " }"
    , ".nav-link { " ++ joinDecls [ decl "--bs-nav-link-padding-y" (r 0.5), decl "--bs-nav-link-padding-x" (r 1.0) ] ++ " }"
    , ".list-group-item { padding: " ++ r 0.5 ++ " " ++ r 1.0 ++ "; }"
    , ".form-control, .form-select { padding: " ++ r 0.375 ++ " " ++ r 0.75 ++ "; }"
    ]


{-| Heading and `.lead` font sizes for the chosen scale. "big" is close to Bootstrap's defaults;
"small" makes headings only slightly larger than body text. -}
headingRules : Settings -> List String
headingRules s =
    let
        ( h, lead ) =
            case s.headings of
                "small" ->
                    ( [ 1.4, 1.3, 1.2, 1.1, 1.05, 1.0 ], 1.05 )

                "big" ->
                    ( [ 2.5, 2.0, 1.75, 1.5, 1.25, 1.0 ], 1.25 )

                _ ->
                    ( [ 1.95, 1.6, 1.4, 1.25, 1.1, 1.0 ], 1.15 )

        levelRule ( i, size ) =
            "h" ++ String.fromInt i ++ ", .h" ++ String.fromInt i ++ " { font-size: " ++ rem size ++ "; }"
    in
    List.map levelRule (List.indexedMap (\i size -> ( i + 1, size )) h)
        ++ [ ".lead { font-size: " ++ rem lead ++ "; }" ]


decl : String -> String -> String
decl name v =
    name ++ ": " ++ v ++ ";"


joinDecls : List String -> String
joinDecls =
    String.join " "


rem : Float -> String
rem f =
    trimNum f ++ "rem"


{-| A compact decimal (drops a trailing ".0" that `String.fromFloat` would leave on whole numbers). -}
trimNum : Float -> String
trimNum f =
    let
        s =
            String.fromFloat f
    in
    if String.endsWith ".0" s then
        String.dropRight 2 s

    else
        s



-- PALETTES


type alias Palette =
    { primary : String
    , secondary : String
    , success : String
    , info : String
    , warning : String
    , danger : String
    , light : String
    , dark : String
    }


{-| The ten presets, each `( key, label, palette )`; the first is Bootstrap's own defaults. -}
presets : List ( String, String, Palette )
presets =
    [ ( "default", "Bootstrap default", Palette "#0d6efd" "#6c757d" "#198754" "#0dcaf0" "#ffc107" "#dc3545" "#f8f9fa" "#212529" )
    , ( "ocean", "Ocean", Palette "#1b6ec2" "#5b7083" "#1d8a73" "#17a2b8" "#f4b942" "#e15554" "#eef3f8" "#13314f" )
    , ( "forest", "Forest", Palette "#2e7d32" "#6d8b74" "#43a047" "#0097a7" "#f9a825" "#c62828" "#f1f5ef" "#1b3a23" )
    , ( "sunset", "Sunset", Palette "#fb5607" "#ff924c" "#8ac926" "#4cc9f0" "#ffca3a" "#e5383b" "#fff4ec" "#3a2618" )
    , ( "grape", "Grape", Palette "#6f42c1" "#8e7cc3" "#5a9367" "#3fa7d6" "#e0a458" "#d6336c" "#f4f0fb" "#2a1a45" )
    , ( "slate", "Slate", Palette "#475569" "#64748b" "#0f9d8c" "#0ea5e9" "#eab308" "#ef4444" "#f1f5f9" "#1e293b" )
    , ( "candy", "Candy", Palette "#e83e8c" "#b5179e" "#06d6a0" "#56cfe1" "#ffd166" "#ef476f" "#fff0f6" "#3d1029" )
    , ( "mint", "Mint", Palette "#10b981" "#6b9080" "#22c55e" "#06b6d4" "#fbbf24" "#f43f5e" "#ecfdf5" "#134e4a" )
    , ( "mocha", "Mocha", Palette "#795548" "#a1887f" "#6d8b3a" "#4e9aa6" "#d4a017" "#b23a2e" "#f5efe9" "#3e2723" )
    , ( "midnight", "Midnight", Palette "#4f6df5" "#7c8cf8" "#2dd4bf" "#38bdf8" "#f5c542" "#fb7185" "#e8ebff" "#0b1020" )
    ]


bootstrapDefault : Palette
bootstrapDefault =
    Palette "#0d6efd" "#6c757d" "#198754" "#0dcaf0" "#ffc107" "#dc3545" "#f8f9fa" "#212529"


{-| The palette in force: the custom one (built from the seeds) when custom is on, else the preset. -}
resolvePalette : Settings -> Palette
resolvePalette s =
    if s.custom then
        customPalette s

    else
        case List.filter (\( key, _, _ ) -> key == s.palette) presets of
            ( _, _, p ) :: _ ->
                p

            [] ->
                bootstrapDefault


{-| Build a full palette from the custom seeds. Seed 1 is the primary. Every other colour falls back
to a value *derived from the primary* when its seed is blank, so the whole palette harmonises with one
colour: secondary is a greyed primary, the accent (info) leans cyan, and the semantic colours keep
their meaning-bearing hue (green / red / amber) nudged a little towards the primary — so success,
danger and warning sit with the theme instead of being fixed Bootstrap colours. Any seed the user
fills in overrides its derived value. -}
customPalette : Settings -> Palette
customPalette s =
    let
        primary =
            normaliseHex s.c1

        seed raw fallback =
            if String.trim raw == "" then
                fallback

            else
                normaliseHex raw
    in
    { primary = primary
    , secondary = seed s.c2 (mixHex primary "#6c757d" 0.6)
    , info = seed s.c3 (mixHex primary "#0dcaf0" 0.5)
    , success = seed s.c4 (mixHex "#198754" primary 0.22)
    , danger = seed s.c5 (mixHex "#dc3545" primary 0.22)
    , warning = seed s.c6 (mixHex "#ffc107" primary 0.15)
    , light = mixHex primary "#ffffff" 0.92
    , dark = mixHex primary "#000000" 0.78
    }



-- COLOUR MATHS


{-| Blend two hex colours: `t` of the way from `a` to `b` (0 = a, 1 = b). -}
mixHex : String -> String -> Float -> String
mixHex a b t =
    case ( parseHex a, parseHex b ) of
        ( Just ( ar, ag, ab ), Just ( br, bg, bb ) ) ->
            toHex ( lerp ar br t, lerp ag bg t, lerp ab bb t )

        _ ->
            a


lerp : Int -> Int -> Float -> Int
lerp x y t =
    round (toFloat x + (toFloat y - toFloat x) * t)


{-| The `r, g, b` triplet string for a hex colour (for the `--bs-*-rgb` variables). -}
rgbOf : String -> String
rgbOf hex =
    case parseHex hex of
        Just ( r, g, b ) ->
            String.fromInt r ++ ", " ++ String.fromInt g ++ ", " ++ String.fromInt b

        Nothing ->
            "0, 0, 0"


{-| A readable text colour (near-black or white) for text placed on `hex`. -}
contrast : String -> String
contrast hex =
    case parseHex hex of
        Just ( r, g, b ) ->
            if toFloat r * 0.299 + toFloat g * 0.587 + toFloat b * 0.114 > 150 then
                "#000"

            else
                "#fff"

        Nothing ->
            "#fff"


{-| A `#rrggbb` colour input value: a valid 6-digit hex, or black if the text isn't parseable. -}
normaliseHex : String -> String
normaliseHex s =
    case parseHex s of
        Just rgb ->
            toHex rgb

        Nothing ->
            "#000000"


parseHex : String -> Maybe ( Int, Int, Int )
parseHex raw =
    let
        h0 =
            if String.startsWith "#" raw then
                String.dropLeft 1 (String.trim raw)

            else
                String.trim raw

        h =
            if String.length h0 == 3 then
                String.fromList (List.concatMap (\c -> [ c, c ]) (String.toList h0))

            else
                h0
    in
    if String.length h >= 6 then
        Just ( hexPair (String.slice 0 2 h), hexPair (String.slice 2 4 h), hexPair (String.slice 4 6 h) )

    else
        Nothing


hexPair : String -> Int
hexPair s =
    case String.toList s of
        a :: b :: _ ->
            hexDigit a * 16 + hexDigit b

        _ ->
            0


hexDigit : Char -> Int
hexDigit c =
    let
        n =
            Char.toCode (Char.toLower c)
    in
    if n >= 48 && n <= 57 then
        n - 48

    else if n >= 97 && n <= 102 then
        10 + n - 97

    else
        0


toHex : ( Int, Int, Int ) -> String
toHex ( r, g, b ) =
    "#" ++ hex2 r ++ hex2 g ++ hex2 b


hex2 : Int -> String
hex2 n =
    let
        c =
            clamp 0 255 n
    in
    hexChar (c // 16) ++ hexChar (modBy 16 c)


hexChar : Int -> String
hexChar d =
    if d < 10 then
        String.fromChar (Char.fromCode (48 + d))

    else
        String.fromChar (Char.fromCode (97 + d - 10))



-- SMALL HELPERS


dropPrefix : String -> String -> String
dropPrefix pre s =
    if String.startsWith pre s then
        String.dropLeft (String.length pre) s

    else
        s


dropSuffix : String -> String -> String
dropSuffix suf s =
    if String.endsWith suf s then
        String.dropRight (String.length suf) s

    else
        s


nth : Int -> List a -> Maybe a
nth i xs =
    List.head (List.drop i xs)


lookupAssoc : String -> List ( String, String ) -> Maybe String
lookupAssoc k pairs =
    case pairs of
        ( a, b ) :: rest ->
            if a == k then
                Just b

            else
                lookupAssoc k rest

        [] ->
            Nothing


indexWhereFrom : Int -> (a -> Bool) -> List a -> Maybe Int
indexWhereFrom start pred xs =
    indexWhere pred (List.drop start xs) |> Maybe.map (\i -> i + start)


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
