module TheWebMachineXConsole exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import String
import Time


-- ============================================================================
-- MAIN ENTRY POINT
-- ============================================================================


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- ============================================================================
-- DOMAIN TYPES & ARCHITECTURE MODELS
-- ============================================================================


type LayerCategory
    = MarkupAndStyle
    | SystemsAndCompiled
    | FunctionalAndBeam
    | ScriptingAndData
    | RuntimeInterop


type SortKey
    = SortByName
    | SortByLines
    | SortByLayer
    | SortByStatus


type ActiveTab
    = OverviewTab
    | LanguageMatrixTab
    | RuntimePipelineTab
    | ArchitectureNotesTab


type NodeHealth
    = Nominal
    | WatchActive
    | Syncing


type alias LanguageSpec =
    { id : String
    , name : String
    , extension : String
    , lineCount : Int
    , layer : LayerCategory
    , primaryRole : String
    , sampleArtifact : String
    , compilerOrRuntime : String
    , health : NodeHealth
    }


type alias PipelineStage =
    { stepNumber : Int
    , stageName : String
    , ownerLanguage : String
    , inputArtifact : String
    , outputArtifact : String
    , latencyBudgetMs : Int
    , notes : String
    }


type alias TelemetryEvent =
    { seq : Int
    , timestampSec : Int
    , source : String
    , severity : String
    , message : String
    }


type alias Model =
    { projectName : String
    , versionTag : String
    , milestoneIndex : Int
    , totalLinesBaseline : Int
    , hostOs : String
    , hostHardware : String
    , activeTab : ActiveTab
    , selectedLayerFilter : Maybe LayerCategory
    , searchQuery : String
    , sortKey : SortKey
    , sortAscending : Bool
    , selectedLanguageId : Maybe String
    , autoStreamEnabled : Bool
    , tickCounter : Int
    , simulatedExtraLines : Int
    , events : List TelemetryEvent
    , languages : List LanguageSpec
    , pipeline : List PipelineStage
    }


type Msg
    = SelectTab ActiveTab
    | SetLayerFilter (Maybe LayerCategory)
    | UpdateSearch String
    | SetSortKey SortKey
    | SelectLanguage (Maybe String)
    | ToggleAutoStream
    | AdvanceTick Time.Posix
    | SimulateBuildPulse
    | ResetTelemetry


-- ============================================================================
-- INITIALIZATION & DATASET (THE WEB MACHINE X v0.2)
-- ============================================================================


init : () -> ( Model, Cmd Msg )
init _ =
    let
        langs =
            initialLanguages

        baselineSum =
            List.sum (List.map .lineCount langs)
    in
    ( { projectName = "The Web Machine X"
      , versionTag = "v0.2"
      , milestoneIndex = 333
      , totalLinesBaseline = baselineSum
      , hostOs = "Fedora Linux"
      , hostHardware = "ThinkPad X13 Gen 1 (Anti-Glare 13.3\")"
      , activeTab = OverviewTab
      , selectedLayerFilter = Nothing
      , searchQuery = ""
      , sortKey = SortByLines
      , sortAscending = False
      , selectedLanguageId = Just "elm"
      , autoStreamEnabled = True
      , tickCounter = 0
      , simulatedExtraLines = 0
      , events = initialEvents
      , languages = langs
      , pipeline = initialPipeline
      }
    , Cmd.none
    )


initialLanguages : List LanguageSpec
initialLanguages =
    [ { id = "html"
      , name = "HTML"
      , extension = ".html"
      , lineCount = 12994
      , layer = MarkupAndStyle
      , primaryRole = "Semantic document structure & UI mount shells"
      , sampleArtifact = "shell_index.html"
      , compilerOrRuntime = "Browser DOM / Template Renderer"
      , health = Nominal
      }
    , { id = "css"
      , name = "CSS"
      , extension = ".css"
      , lineCount = 12886
      , layer = MarkupAndStyle
      , primaryRole = "Layout grids, low-glare contrast rules & responsive surfaces"
      , sampleArtifact = "mat_surface.css"
      , compilerOrRuntime = "Browser Layout Engine"
      , health = Nominal
      }
    , { id = "cobol"
      , name = "COBOL"
      , extension = ".cbl"
      , lineCount = 4002
      , layer = SystemsAndCompiled
      , primaryRole = "Structured ledger & deterministic record routines"
      , sampleArtifact = "coresys.cbl"
      , compilerOrRuntime = "GnuCOBOL (cobc)"
      , health = Nominal
      }
    , { id = "fortran"
      , name = "Fortran"
      , extension = ".f90"
      , lineCount = 486
      , layer = SystemsAndCompiled
      , primaryRole = "Numeric array kernels & high-precision calculations"
      , sampleArtifact = "num_kernel.f90"
      , compilerOrRuntime = "GNU Fortran (gfortran)"
      , health = Nominal
      }
    , { id = "assembly"
      , name = "Assembly"
      , extension = ".s / .asm"
      , lineCount = 486
      , layer = SystemsAndCompiled
      , primaryRole = "Low-level register inspection & hardware-close routines"
      , sampleArtifact = "reg_probe.s"
      , compilerOrRuntime = "GNU Assembler (as) / NASM"
      , health = WatchActive
      }
    , { id = "ruby"
      , name = "Ruby"
      , extension = ".rb"
      , lineCount = 382
      , layer = ScriptingAndData
      , primaryRole = "Core numeric & build-graph utilities"
      , sampleArtifact = "corenum.rb"
      , compilerOrRuntime = "Ruby 4.0.9 MRI"
      , health = Nominal
      }
    , { id = "sql"
      , name = "SQL"
      , extension = ".sql"
      , lineCount = 354
      , layer = ScriptingAndData
      , primaryRole = "Relational schema definitions & indexed queries"
      , sampleArtifact = "schema_core.sql"
      , compilerOrRuntime = "SQLite / PostgreSQL Engine"
      , health = Nominal
      }
    , { id = "pascal"
      , name = "Pascal"
      , extension = ".pas"
      , lineCount = 280
      , layer = SystemsAndCompiled
      , primaryRole = "Strongly typed core web routines & state checks"
      , sampleArtifact = "webcore.pas"
      , compilerOrRuntime = "Free Pascal Compiler (fpc)"
      , health = Nominal
      }
    , { id = "rust"
      , name = "Rust"
      , extension = ".rs"
      , lineCount = 252
      , layer = SystemsAndCompiled
      , primaryRole = "Memory-safe systems helpers & strict boundary checks"
      , sampleArtifact = "safe_bridge.rs"
      , compilerOrRuntime = "rustc / Cargo"
      , health = Nominal
      }
    , { id = "javascript"
      , name = "JavaScript"
      , extension = ".js"
      , lineCount = 212
      , layer = RuntimeInterop
      , primaryRole = "Browser interop ports, DOM event bridges & host glue"
      , sampleArtifact = "interop_port.js"
      , compilerOrRuntime = "ES Module Runtime / Node"
      , health = Nominal
      }
    , { id = "python"
      , name = "Python"
      , extension = ".py"
      , lineCount = 196
      , layer = ScriptingAndData
      , primaryRole = "Automation scripts, line counters & data transforms"
      , sampleArtifact = "metrics_sync.py"
      , compilerOrRuntime = "CPython 3.x"
      , health = Syncing
      }
    , { id = "csharp"
      , name = "C#"
      , extension = ".cs"
      , lineCount = 180
      , layer = SystemsAndCompiled
      , primaryRole = "Strongly typed service components & structured contracts"
      , sampleArtifact = "contract_svc.cs"
      , compilerOrRuntime = ".NET SDK"
      , health = Nominal
      }
    , { id = "haskell"
      , name = "Haskell"
      , extension = ".hs"
      , lineCount = 174
      , layer = FunctionalAndBeam
      , primaryRole = "Pure functional transformations & algebraic rules"
      , sampleArtifact = "pure_rules.hs"
      , compilerOrRuntime = "GHC"
      , health = Nominal
      }
    , { id = "json"
      , name = "JSON"
      , extension = ".json"
      , lineCount = 164
      , layer = ScriptingAndData
      , primaryRole = "Manifests, configuration tables & interchange payloads"
      , sampleArtifact = "manifest_v02.json"
      , compilerOrRuntime = "JSON Schema Parser"
      , health = Nominal
      }
    , { id = "c"
      , name = "C"
      , extension = ".c"
      , lineCount = 158
      , layer = SystemsAndCompiled
      , primaryRole = "Compact C primitives & POSIX/Linux system calls"
      , sampleArtifact = "sys_prim.c"
      , compilerOrRuntime = "GCC"
      , health = Nominal
      }
    , { id = "cpp"
      , name = "C++"
      , extension = ".cpp"
      , lineCount = 156
      , layer = SystemsAndCompiled
      , primaryRole = "Template-driven components & performance helpers"
      , sampleArtifact = "tpl_helper.cpp"
      , compilerOrRuntime = "G++ (C++20)"
      , health = Nominal
      }
    , { id = "scss"
      , name = "SCSS"
      , extension = ".scss"
      , lineCount = 14
      , layer = MarkupAndStyle
      , primaryRole = "Nested style variables & modular design tokens"
      , sampleArtifact = "tokens.scss"
      , compilerOrRuntime = "Sass Preprocessor"
      , health = Nominal
      }
    , { id = "typescript"
      , name = "TypeScript"
      , extension = ".ts"
      , lineCount = 8
      , layer = RuntimeInterop
      , primaryRole = "Typed client bridge definitions & interface contracts"
      , sampleArtifact = "bridge_types.ts"
      , compilerOrRuntime = "tsc / TypeScript Compiler"
      , health = Nominal
      }
    , { id = "erlang"
      , name = "Erlang"
      , extension = ".erl"
      , lineCount = 0
      , layer = FunctionalAndBeam
      , primaryRole = "BEAM actor supervision, fault isolation & OTP primitives"
      , sampleArtifact = "sup_core.erl"
      , compilerOrRuntime = "Erlang/OTP BEAM (erlc)"
      , health = WatchActive
      }
    , { id = "elm"
      , name = "Elm"
      , extension = ".elm"
      , lineCount = 600
      , layer = FunctionalAndBeam
      , primaryRole = "Zero-runtime-exception TEA front-end state & views"
      , sampleArtifact = "WebMachineXConsole.elm"
      , compilerOrRuntime = "Elm Compiler (elm make)"
      , health = Nominal
      }
    , { id = "bash"
      , name = "Bash"
      , extension = ".sh"
      , lineCount = 0
      , layer = ScriptingAndData
      , primaryRole = "Fedora shell pipelines, compiler checks & repo scripts"
      , sampleArtifact = "fedora_check.sh"
      , compilerOrRuntime = "GNU Bash"
      , health = Nominal
      }
    , { id = "elixir"
      , name = "Elixir"
      , extension = ".ex"
      , lineCount = 0
      , layer = FunctionalAndBeam
      , primaryRole = "Concurrent web orchestration & Phoenix/BEAM channels"
      , sampleArtifact = "web_router.ex"
      , compilerOrRuntime = "Elixir on BEAM (mix)"
      , health = Syncing
      }
    ]


initialPipeline : List PipelineStage
initialPipeline =
    [ { stepNumber = 1
      , stageName = "Shell Pre-Flight & Toolchain Check"
      , ownerLanguage = "Bash"
      , inputArtifact = "fedora_check.sh"
      , outputArtifact = "env_ready.flag"
      , latencyBudgetMs = 25
      , notes = "Verifies compilers (fpc, cobc, gfortran, rustc, elm, erl, mix, ruby) on Fedora Linux."
      }
    , { stepNumber = 2
      , stageName = "Numeric & Ledger Computation"
      , ownerLanguage = "COBOL / Fortran / Ruby"
      , inputArtifact = "coresys.cbl + corenum.rb"
      , outputArtifact = "ledger_state.json"
      , latencyBudgetMs = 120
      , notes = "Runs structured record logic, numeric kernels, and Ruby 4.0.9 helper utilities."
      }
    , { stepNumber = 3
      , stageName = "Systems & Type Boundary Verification"
      , ownerLanguage = "Pascal / Rust / C / C++"
      , inputArtifact = "webcore.pas + safe_bridge.rs"
      , outputArtifact = "verified_modules"
      , latencyBudgetMs = 180
      , notes = "Compiles native and typed modules cleanly with zero silent state corruption."
      }
    , { stepNumber = 4
      , stageName = "BEAM Concurrency & Fault Supervision"
      , ownerLanguage = "Erlang / Elixir"
      , inputArtifact = "sup_core.erl + web_router.ex"
      , outputArtifact = "beam_process_tree"
      , latencyBudgetMs = 45
      , notes = "Isolates concurrent processes so one failing worker never takes down the whole app."
      }
    , { stepNumber = 5
      , stageName = "Deterministic Front-End State & View"
      , ownerLanguage = "Elm + HTML/CSS"
      , inputArtifact = "WebMachineXConsole.elm"
      , outputArtifact = "web-machine-x.js"
      , latencyBudgetMs = 60
      , notes = "Compiles pure Elm state transitions into predictable browser rendering."
      }
    ]


initialEvents : List TelemetryEvent
initialEvents =
    [ { seq = 1
      , timestampSec = 10
      , source = "fedora-x13"
      , severity = "INFO"
      , message = "Milestone #333 baseline verified on ThinkPad X13 Gen 1 (Fedora Linux)."
      }
    , { seq = 2
      , timestampSec = 24
      , source = "beam-rt"
      , severity = "INFO"
      , message = "Erlang/Elixir process supervision tree ready for concurrent web tasks."
      }
    , { seq = 3
      , timestampSec = 38
      , source = "elm-tea"
      , severity = "OK"
      , message = "Elm Model-Update-View loop compiled with strict type guarantees."
      }
    , { seq = 4
      , timestampSec = 52
      , source = "bash-ops"
      , severity = "INFO"
      , message = "Anti-glare workspace active; zero background bloat from consumer OS defaults."
      }
    ]


-- ============================================================================
-- UPDATE LOGIC (THE ELM ARCHITECTURE)
-- ============================================================================


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectTab tab ->
            ( { model | activeTab = tab }, Cmd.none )

        SetLayerFilter maybeLayer ->
            ( { model | selectedLayerFilter = maybeLayer }, Cmd.none )

        UpdateSearch query ->
            ( { model | searchQuery = query }, Cmd.none )

        SetSortKey key ->
            let
                nextAsc =
                    if model.sortKey == key then
                        not model.sortAscending

                    else
                        case key of
                            SortByLines ->
                                False

                            _ ->
                                True
            in
            ( { model
                | sortKey = key
                , sortAscending = nextAsc
              }
            , Cmd.none
            )

        SelectLanguage maybeId ->
            ( { model | selectedLanguageId = maybeId }, Cmd.none )

        ToggleAutoStream ->
            ( { model | autoStreamEnabled = not model.autoStreamEnabled }, Cmd.none )

        AdvanceTick _ ->
            if model.autoStreamEnabled then
                let
                    nextTick =
                        model.tickCounter + 1

                    nextSeq =
                        List.length model.events + 1

                    rotatedLang =
                        pickRotatingLanguage nextTick model.languages

                    newEvent =
                        { seq = nextSeq
                        , timestampSec = model.tickCounter * 3 + 60
                        , source = rotatedLang.name
                        , severity = "PULSE"
                        , message =
                            rotatedLang.name
                                ++ " ("
                                ++ rotatedLang.extension
                                ++ ") check passed on "
                                ++ model.hostOs
                                ++ "."
                        }

                    updatedEvents =
                        List.take 12 (newEvent :: model.events)
                in
                ( { model
                    | tickCounter = nextTick
                    , events = updatedEvents
                  }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        SimulateBuildPulse ->
            let
                addedLines =
                    12

                nextSeq =
                    List.length model.events + 1

                pulseEvent =
                    { seq = nextSeq
                    , timestampSec = model.tickCounter * 3 + 65
                    , source = "elm+elixir"
                    , severity = "BUILD"
                    , message =
                        "Simulated polyglot build pulse: +"
                            ++ String.fromInt addedLines
                            ++ " lines integrated cleanly."
                    }
            in
            ( { model
                | simulatedExtraLines = model.simulatedExtraLines + addedLines
                , events = List.take 12 (pulseEvent :: model.events)
              }
            , Cmd.none
            )

        ResetTelemetry ->
            let
                ( freshModel, _ ) =
                    init ()
            in
            ( freshModel, Cmd.none )


pickRotatingLanguage : Int -> List LanguageSpec -> LanguageSpec
pickRotatingLanguage index list =
    let
        len =
            List.length list

        safeIdx =
            if len > 0 then
                modBy len index

            else
                0

        fallback =
            { id = "elm"
            , name = "Elm"
            , extension = ".elm"
            , lineCount = 600
            , layer = FunctionalAndBeam
            , primaryRole = "Front-end state & UI"
            , sampleArtifact = "WebMachineXConsole.elm"
            , compilerOrRuntime = "elm make"
            , health = Nominal
            }
    in
    list
        |> List.drop safeIdx
        |> List.head
        |> Maybe.withDefault fallback


-- ============================================================================
-- SUBSCRIPTIONS
-- ============================================================================


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.autoStreamEnabled then
        Time.every 3000 AdvanceTick

    else
        Sub.none


-- ============================================================================
-- FILTERING, SORTING & AGGREGATION HELPERS
-- ============================================================================


effectiveTotalLines : Model -> Int
effectiveTotalLines model =
    model.totalLinesBaseline + model.simulatedExtraLines


filteredAndSortedLanguages : Model -> List LanguageSpec
filteredAndSortedLanguages model =
    let
        queryLower =
            String.toLower (String.trim model.searchQuery)

        matchesLayer spec =
            case model.selectedLayerFilter of
                Nothing ->
                    True

                Just targetLayer ->
                    spec.layer == targetLayer

        matchesQuery spec =
            if String.isEmpty queryLower then
                True

            else
                String.contains queryLower (String.toLower spec.name)
                    || String.contains queryLower (String.toLower spec.extension)
                    || String.contains queryLower (String.toLower spec.primaryRole)
                    || String.contains queryLower (String.toLower spec.compilerOrRuntime)

        comparator a b =
            let
                ord =
                    case model.sortKey of
                        SortByName ->
                            compare a.name b.name

                        SortByLines ->
                            compare a.lineCount b.lineCount

                        SortByLayer ->
                            compare (layerOrder a.layer) (layerOrder b.layer)

                        SortByStatus ->
                            compare (healthOrder a.health) (healthOrder b.health)
            in
            if model.sortAscending then
                ord

            else
                flipOrder ord
    in
    model.languages
        |> List.filter (\s -> matchesLayer s && matchesQuery s)
        |> List.sortWith comparator


flipOrder : Order -> Order
flipOrder ord =
    case ord of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT


layerOrder : LayerCategory -> Int
layerOrder layer =
    case layer of
        MarkupAndStyle ->
            1

        SystemsAndCompiled ->
            2

        FunctionalAndBeam ->
            3

        ScriptingAndData ->
            4

        RuntimeInterop ->
            5


layerLabel : LayerCategory -> String
layerLabel layer =
    case layer of
        MarkupAndStyle ->
            "Markup & Style"

        SystemsAndCompiled ->
            "Systems & Compiled"

        FunctionalAndBeam ->
            "Functional & BEAM"

        ScriptingAndData ->
            "Scripting & Data"

        RuntimeInterop ->
            "Runtime & Interop"


healthOrder : NodeHealth -> Int
healthOrder h =
    case h of
        Nominal ->
            1

        WatchActive ->
            2

        Syncing ->
            3


healthLabel : NodeHealth -> String
healthLabel h =
    case h of
        Nominal ->
            "NOMINAL"

        WatchActive ->
            "WATCH ACTIVE"

        Syncing ->
            "SYNCING"


linesForLayer : LayerCategory -> List LanguageSpec -> Int
linesForLayer targetLayer specs =
    specs
        |> List.filter (\s -> s.layer == targetLayer)
        |> List.map .lineCount
        |> List.sum


findSelectedLanguage : Model -> Maybe LanguageSpec
findSelectedLanguage model =
    case model.selectedLanguageId of
        Nothing ->
            Nothing

        Just targetId ->
            model.languages
                |> List.filter (\s -> s.id == targetId)
                |> List.head


-- ============================================================================
-- TOP-LEVEL VIEW & LAYOUT COMPOSITION
-- ============================================================================


view : Model -> Html Msg
view model =
    div
        [ class "wmx-root"
        , style "font-family" "system-ui, -apple-system, 'Segoe UI', Roboto, monospace"
        , style "background-color" "#0f1419"
        , style "color" "#e6edf3"
        , style "min-height" "100vh"
        , style "padding" "24px"
        , style "box-sizing" "border-box"
        ]
        [ viewHeaderBar model
        , viewKpiStrip model
        , viewNavigationTabs model
        , viewActiveTabBody model
        , viewFooterBar model
        ]


viewHeaderBar : Model -> Html Msg
viewHeaderBar model =
    header
        [ style "display" "flex"
        , style "flex-wrap" "wrap"
        , style "justify-content" "space-between"
        , style "align-items" "center"
        , style "gap" "16px"
        , style "padding" "18px 22px"
        , style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "margin-bottom" "18px"
        ]
        [ div []
            [ h1
                [ style "margin" "0 0 6px 0"
                , style "font-size" "22px"
                , style "font-weight" "700"
                , style "color" "#f0f6fc"
                ]
                [ text (model.projectName ++ " (" ++ model.versionTag ++ ") — Elm Control Plane") ]
            , p
                [ style "margin" "0"
                , style "font-size" "13px"
                , style "color" "#9fb0c0"
                ]
                [ text ("Host: " ++ model.hostHardware ++ " | OS: " ++ model.hostOs) ]
            ]
        , div
            [ style "display" "flex"
            , style "flex-wrap" "wrap"
            , style "gap" "10px"
            ]
            [ actionButton
                "Simulate Build (+12 LOC)"
                "#1f6feb"
                SimulateBuildPulse
            , actionButton
                (if model.autoStreamEnabled then
                    "Pause Stream"

                 else
                    "Resume Stream"
                )
                "#238636"
                ToggleAutoStream
            , actionButton
                "Reset State"
                "#30363d"
                ResetTelemetry
            ]
        ]


actionButton : String -> String -> Msg -> Html Msg
actionButton label bgColor msg =
    button
        [ type_ "button"
        , onClick msg
        , style "background-color" bgColor
        , style "color" "#ffffff"
        , style "border" "1px solid rgba(255,255,255,0.14)"
        , style "border-radius" "6px"
        , style "padding" "8px 14px"
        , style "font-size" "13px"
        , style "font-weight" "600"
        , style "cursor" "pointer"
        ]
        [ text label ]


viewKpiStrip : Model -> Html Msg
viewKpiStrip model =
    let
        totalLoc =
            effectiveTotalLines model

        langCount =
            List.length model.languages

        beamLoc =
            linesForLayer FunctionalAndBeam model.languages
    in
    section
        [ style "display" "grid"
        , style "grid-template-columns" "repeat(auto-fit, minmax(200px, 1fr))"
        , style "gap" "14px"
        , style "margin-bottom" "18px"
        ]
        [ kpiCard "Milestone Reached" ("#" ++ String.fromInt model.milestoneIndex) "Polyglot architecture checkpoints"
        , kpiCard "Tracked Lines of Code" (String.fromInt totalLoc) ("Across " ++ String.fromInt langCount ++ " languages & modules")
        , kpiCard "Functional & BEAM Layer" (String.fromInt beamLoc ++ " LOC") "Elm front-end + Erlang/Elixir/Haskell"
        , kpiCard "Live Stream Ticks" (String.fromInt model.tickCounter)
            (if model.autoStreamEnabled then
                "Active (3s interval)"

             else
                "Paused by user"
            )
        ]


kpiCard : String -> String -> String -> Html Msg
kpiCard title val subtitle =
    div
        [ style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "padding" "16px"
        ]
        [ div
            [ style "font-size" "12px"
            , style "text-transform" "uppercase"
            , style "letter-spacing" "0.05em"
            , style "color" "#8b9cb0"
            , style "margin-bottom" "6px"
            ]
            [ text title ]
        , div
            [ style "font-size" "24px"
            , style "font-weight" "700"
            , style "color" "#79c0ff"
            , style "margin-bottom" "4px"
            ]
            [ text val ]
        , div
            [ style "font-size" "12px"
            , style "color" "#9fb0c0"
            ]
            [ text subtitle ]
        ]


viewNavigationTabs : Model -> Html Msg
viewNavigationTabs model =
    nav
        [ style "display" "flex"
        , style "flex-wrap" "wrap"
        , style "gap" "8px"
        , style "margin-bottom" "18px"
        ]
        [ tabButton model OverviewTab "Overview & Telemetry"
        , tabButton model LanguageMatrixTab "Language Matrix"
        , tabButton model RuntimePipelineTab "Build & BEAM Pipeline"
        , tabButton model ArchitectureNotesTab "Hardware & Stack Rationale"
        ]


tabButton : Model -> ActiveTab -> String -> Html Msg
tabButton model tab label =
    let
        isActive =
            model.activeTab == tab
    in
    button
        [ type_ "button"
        , onClick (SelectTab tab)
        , style "padding" "10px 16px"
        , style "border-radius" "6px"
        , style "font-size" "13px"
        , style "font-weight" "600"
        , style "cursor" "pointer"
        , style "background-color"
            (if isActive then
                "#1f6feb"

             else
                "#161d24"
            )
        , style "color"
            (if isActive then
                "#ffffff"

             else
                "#c9d1d9"
            )
        , style "border"
            (if isActive then
                "1px solid #58a6ff"

             else
                "1px solid #2b3642"
            )
        ]
        [ text label ]


viewActiveTabBody : Model -> Html Msg
viewActiveTabBody model =
    case model.activeTab of
        OverviewTab ->
            viewOverviewTab model

        LanguageMatrixTab ->
            viewLanguageMatrixTab model

        RuntimePipelineTab ->
            viewRuntimePipelineTab model

        ArchitectureNotesTab ->
            viewArchitectureNotesTab model


-- ============================================================================
-- TAB 1: OVERVIEW & TELEMETRY
-- ============================================================================


viewOverviewTab : Model -> Html Msg
viewOverviewTab model =
    div
        [ style "display" "grid"
        , style "grid-template-columns" "repeat(auto-fit, minmax(340px, 1fr))"
        , style "gap" "18px"
        ]
        [ viewLayerBreakdownCard model
        , viewLiveEventLogCard model
        ]


viewLayerBreakdownCard : Model -> Html Msg
viewLayerBreakdownCard model =
    let
        layers =
            [ MarkupAndStyle
            , SystemsAndCompiled
            , FunctionalAndBeam
            , ScriptingAndData
            , RuntimeInterop
            ]

        grandTotal =
            Basics.max 1 (effectiveTotalLines model)
    in
    div
        [ style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "padding" "18px"
        ]
        [ h2
            [ style "margin" "0 0 12px 0"
            , style "font-size" "17px"
            , style "color" "#f0f6fc"
            ]
            [ text "Architectural Layer Distribution" ]
        , p
            [ style "margin" "0 0 16px 0"
            , style "font-size" "13px"
            , style "color" "#9fb0c0"
            ]
            [ text "Click any layer below to filter the language matrix." ]
        , div
            [ style "display" "flex"
            , style "flex-direction" "column"
            , style "gap" "12px"
            ]
            (List.map (viewLayerBar grandTotal model.languages) layers)
        ]


viewLayerBar : Int -> List LanguageSpec -> LayerCategory -> Html Msg
viewLayerBar grandTotal specs layer =
    let
        loc =
            linesForLayer layer specs

        pct =
            (toFloat loc / toFloat grandTotal) * 100.0

        pctRounded =
            String.fromInt (round pct)
    in
    div
        [ onClick (SetLayerFilter (Just layer))
        , style "cursor" "pointer"
        , style "padding" "10px"
        , style "border-radius" "6px"
        , style "background-color" "#0f1419"
        , style "border" "1px solid #242e38"
        ]
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "font-size" "13px"
            , style "margin-bottom" "6px"
            ]
            [ span [ style "font-weight" "600", style "color" "#e6edf3" ] [ text (layerLabel layer) ]
            , span [ style "color" "#8b9cb0" ]
                [ text (String.fromInt loc ++ " LOC (" ++ pctRounded ++ "%)") ]
            ]
        , div
            [ style "height" "8px"
            , style "width" "100%"
            , style "background-color" "#212a34"
            , style "border-radius" "4px"
            , style "overflow" "hidden"
            ]
            [ div
                [ style "height" "100%"
                , style "width" (String.fromFloat (Basics.min 100.0 pct) ++ "%")
                , style "background-color" "#388bfd"
                ]
                []
            ]
        ]


viewLiveEventLogCard : Model -> Html Msg
viewLiveEventLogCard model =
    div
        [ style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "padding" "18px"
        ]
        [ h2
            [ style "margin" "0 0 12px 0"
            , style "font-size" "17px"
            , style "color" "#f0f6fc"
            ]
            [ text "Live Runtime & Build Telemetry" ]
        , div
            [ style "display" "flex"
            , style "flex-direction" "column"
            , style "gap" "8px"
            ]
            (List.map viewEventRow model.events)
        ]


viewEventRow : TelemetryEvent -> Html Msg
viewEventRow ev =
    div
        [ style "padding" "10px 12px"
        , style "background-color" "#0f1419"
        , style "border-left" "3px solid #58a6ff"
        , style "border-radius" "4px"
        , style "font-size" "12px"
        ]
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "margin-bottom" "4px"
            , style "color" "#8b9cb0"
            ]
            [ span [] [ text ("#" ++ String.fromInt ev.seq ++ " · [" ++ ev.severity ++ "] · " ++ ev.source) ]
            , span [] [ text ("t+" ++ String.fromInt ev.timestampSec ++ "s") ]
            ]
        , div [ style "color" "#e6edf3" ] [ text ev.message ]
        ]


-- ============================================================================
-- TAB 2: LANGUAGE MATRIX & INSPECTOR
-- ============================================================================


viewLanguageMatrixTab : Model -> Html Msg
viewLanguageMatrixTab model =
    let
        visibleSpecs =
            filteredAndSortedLanguages model
    in
    div []
        [ viewFilterBar model
        , div
            [ style "display" "grid"
            , style "grid-template-columns" "minmax(0, 2fr) minmax(280px, 1fr)"
            , style "gap" "18px"
            ]
            [ viewLanguageTable visibleSpecs
            , viewSelectedLanguageInspector (findSelectedLanguage model)
            ]
        ]


viewFilterBar : Model -> Html Msg
viewFilterBar model =
    div
        [ style "display" "flex"
        , style "flex-wrap" "wrap"
        , style "gap" "10px"
        , style "align-items" "center"
        , style "margin-bottom" "14px"
        , style "padding" "12px"
        , style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        ]
        [ input
            [ type_ "text"
            , placeholder "Filter by language, extension, role, or runtime..."
            , value model.searchQuery
            , onInput UpdateSearch
            , style "padding" "8px 12px"
            , style "border-radius" "6px"
            , style "border" "1px solid #30363d"
            , style "background-color" "#0f1419"
            , style "color" "#e6edf3"
            , style "min-width" "240px"
            , style "font-size" "13px"
            ]
            []
        , filterChip "All Layers" (model.selectedLayerFilter == Nothing) (SetLayerFilter Nothing)
        , filterChip "Markup & Style" (model.selectedLayerFilter == Just MarkupAndStyle) (SetLayerFilter (Just MarkupAndStyle))
        , filterChip "Systems" (model.selectedLayerFilter == Just SystemsAndCompiled) (SetLayerFilter (Just SystemsAndCompiled))
        , filterChip "Functional & BEAM" (model.selectedLayerFilter == Just FunctionalAndBeam) (SetLayerFilter (Just FunctionalAndBeam))
        , filterChip "Scripting & Data" (model.selectedLayerFilter == Just ScriptingAndData) (SetLayerFilter (Just ScriptingAndData))
        , filterChip "Interop" (model.selectedLayerFilter == Just RuntimeInterop) (SetLayerFilter (Just RuntimeInterop))
        ]


filterChip : String -> Bool -> Msg -> Html Msg
filterChip label active msg =
    button
        [ type_ "button"
        , onClick msg
        , style "padding" "6px 10px"
        , style "border-radius" "5px"
        , style "font-size" "12px"
        , style "cursor" "pointer"
        , style "background-color"
            (if active then
                "#238636"

             else
                "#21262d"
            )
        , style "color" "#ffffff"
        , style "border" "1px solid rgba(255,255,255,0.12)"
        ]
        [ text label ]


viewLanguageTable : List LanguageSpec -> Html Msg
viewLanguageTable specs =
    div
        [ style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "overflow-x" "auto"
        ]
        [ table
            [ style "width" "100%"
            , style "border-collapse" "collapse"
            , style "font-size" "13px"
            ]
            [ thead []
                [ tr [ style "background-color" "#1c2530", style "text-align" "left" ]
                    [ sortableHeader "Language" SortByName
                    , th [ style "padding" "10px 12px", style "color" "#9fb0c0" ] [ text "Ext" ]
                    , sortableHeader "Lines" SortByLines
                    , sortableHeader "Layer" SortByLayer
                    , sortableHeader "Status" SortByStatus
                    ]
                ]
            , tbody [] (List.map viewLanguageRow specs)
            ]
        ]


sortableHeader : String -> SortKey -> Html Msg
sortableHeader label key =
    th
        [ onClick (SetSortKey key)
        , style "padding" "10px 12px"
        , style "color" "#79c0ff"
        , style "cursor" "pointer"
        , style "user-select" "none"
        ]
        [ text (label ++ " ↕") ]


viewLanguageRow : LanguageSpec -> Html Msg
viewLanguageRow spec =
    tr
        [ onClick (SelectLanguage (Just spec.id))
        , style "cursor" "pointer"
        , style "border-top" "1px solid #242e38"
        ]
        [ td [ style "padding" "10px 12px", style "font-weight" "600", style "color" "#f0f6fc" ]
            [ text spec.name ]
        , td [ style "padding" "10px 12px", style "color" "#8b9cb0" ]
            [ text spec.extension ]
        , td [ style "padding" "10px 12px", style "color" "#79c0ff", style "font-weight" "600" ]
            [ text (String.fromInt spec.lineCount) ]
        , td [ style "padding" "10px 12px", style "color" "#c9d1d9" ]
            [ text (layerLabel spec.layer) ]
        , td [ style "padding" "10px 12px", style "color" "#56d364" ]
            [ text (healthLabel spec.health) ]
        ]


viewSelectedLanguageInspector : Maybe LanguageSpec -> Html Msg
viewSelectedLanguageInspector maybeSpec =
    div
        [ style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "padding" "18px"
        ]
        [ h2
            [ style "margin" "0 0 12px 0"
            , style "font-size" "16px"
            , style "color" "#f0f6fc"
            ]
            [ text "Module & Toolchain Inspector" ]
        , case maybeSpec of
            Nothing ->
                p [ style "color" "#8b9cb0", style "font-size" "13px" ]
                    [ text "Select any language row to inspect its role, compiler, and sample file." ]

            Just spec ->
                div [ style "display" "flex", style "flex-direction" "column", style "gap" "10px", style "font-size" "13px" ]
                    [ inspectorField "Language" spec.name
                    , inspectorField "Line Count" (String.fromInt spec.lineCount ++ " LOC")
                    , inspectorField "Layer" (layerLabel spec.layer)
                    , inspectorField "Sample File" spec.sampleArtifact
                    , inspectorField "Compiler / Runtime" spec.compilerOrRuntime
                    , inspectorField "Role in Project" spec.primaryRole
                    ]
        ]


inspectorField : String -> String -> Html Msg
inspectorField label val =
    div
        [ style "padding" "8px 10px"
        , style "background-color" "#0f1419"
        , style "border-radius" "5px"
        ]
        [ div [ style "font-size" "11px", style "color" "#8b9cb0", style "margin-bottom" "2px" ] [ text label ]
        , div [ style "color" "#e6edf3", style "font-weight" "500" ] [ text val ]
        ]


-- ============================================================================
-- TAB 3: BUILD & BEAM PIPELINE
-- ============================================================================


viewRuntimePipelineTab : Model -> Html Msg
viewRuntimePipelineTab model =
    div
        [ style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "padding" "18px"
        ]
        [ h2
            [ style "margin" "0 0 8px 0"
            , style "font-size" "17px"
            , style "color" "#f0f6fc"
            ]
            [ text "Multi-Language Execution & Build Pipeline" ]
        , p
            [ style "margin" "0 0 16px 0"
            , style "font-size" "13px"
            , style "color" "#9fb0c0"
            ]
            [ text "How Bash, systems/compiled modules, BEAM concurrency, and Elm front-end state fit together." ]
        , div
            [ style "display" "flex"
            , style "flex-direction" "column"
            , style "gap" "12px"
            ]
            (List.map viewPipelineStageCard model.pipeline)
        ]


viewPipelineStageCard : PipelineStage -> Html Msg
viewPipelineStageCard stage =
    div
        [ style "padding" "14px"
        , style "background-color" "#0f1419"
        , style "border" "1px solid #26323d"
        , style "border-radius" "6px"
        ]
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "flex-wrap" "wrap"
            , style "gap" "8px"
            , style "margin-bottom" "6px"
            ]
            [ span [ style "font-weight" "700", style "color" "#79c0ff", style "font-size" "14px" ]
                [ text ("Stage " ++ String.fromInt stage.stepNumber ++ ": " ++ stage.stageName) ]
            , span [ style "font-size" "12px", style "color" "#56d364" ]
                [ text ("Owner: " ++ stage.ownerLanguage ++ " · Budget: " ++ String.fromInt stage.latencyBudgetMs ++ " ms") ]
            ]
        , div [ style "font-size" "12px", style "color" "#8b9cb0", style "margin-bottom" "6px" ]
            [ text (stage.inputArtifact ++ "  -->  " ++ stage.outputArtifact) ]
        , p [ style "margin" "0", style "font-size" "13px", style "color" "#e6edf3" ]
            [ text stage.notes ]
        ]


-- ============================================================================
-- TAB 4: HARDWARE & STACK RATIONALE
-- ============================================================================


viewArchitectureNotesTab : Model -> Html Msg
viewArchitectureNotesTab model =
    div
        [ style "display" "grid"
        , style "grid-template-columns" "repeat(auto-fit, minmax(320px, 1fr))"
        , style "gap" "18px"
        ]
        [ rationaleCard
            "Why ThinkPad X13 Gen 1 + Fedora Linux"
            [ "Anti-glare 13.3-inch display avoids harsh reflections during long coding and terminal sessions."
            , "Fedora Linux removes consumer OS bloat and keeps local compilers, shells, and editors responsive."
            , "Avoids overpaying for glossy panels, unwanted trackpad premiums, or memory-starved 8 GB entry tiers."
            ]
        , rationaleCard
            "Why Erlang, Elm, Bash & Elixir Fit the Stack"
            [ "Erlang and Elixir bring lightweight BEAM processes and fault-tolerant supervision to concurrent web tasks."
            , "Elm enforces strict static typing and predictable Model-Update-View state transitions in the browser."
            , "Bash ties together shell automation, environment checks, and multi-language build steps cleanly."
            , "Expanding from HTML, CSS, JS, TS, and Python into additional paradigms reflects deliberate architectural growth rather than bloat."
            ]
        ]


rationaleCard : String -> List String -> Html Msg
rationaleCard title bullets =
    div
        [ style "background-color" "#161d24"
        , style "border" "1px solid #2b3642"
        , style "border-radius" "8px"
        , style "padding" "18px"
        ]
        [ h2
            [ style "margin" "0 0 12px 0"
            , style "font-size" "17px"
            , style "color" "#f0f6fc"
            ]
            [ text title ]
        , ul
            [ style "margin" "0"
            , style "padding-left" "20px"
            , style "display" "flex"
            , style "flex-direction" "column"
            , style "gap" "10px"
            , style "font-size" "13px"
            , style "color" "#c9d1d9"
            ]
            (List.map (\b -> li [] [ text b ]) bullets)
        ]


-- ============================================================================
-- FOOTER BAR
-- ============================================================================

viewFooterBar : Model -> Html Msg
viewFooterBar model =
    footer
        [ style "margin-top" "22px"
        , style "padding-top" "14px"
        , style "border-top" "1px solid #242e38"
        , style "display" "flex"
        , style "flex-wrap" "wrap"
        , style "justify-content" "space-between"
        , style "gap" "10px"
        , style "font-size" "12px"
        , style "color" "#8b9cb0"
        ]
        [ text (model.projectName ++ " " ++ model.versionTag ++ " · Pure Elm Control Surface")
        , text ("Effective LOC: " ++ String.fromInt (effectiveTotalLines model) ++ " · Milestone #" ++ String.fromInt model.milestoneIndex)
        ]