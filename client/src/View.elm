module View exposing (view)

import Color exposing (Color)
import ColorTheme exposing (currentTheme)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (autofocus, class, href, id, placeholder, style, type_, value)
import Html.Events exposing (onClick, onDoubleClick, onInput, onMouseDown, onSubmit)
import Html.Events.Extra.Mouse as Mouse
import Maybe.Extra
import Model exposing (Article, Model, Msg(..), Node, TextType)
import Simulation
import TypedSvg exposing (circle, g, line, rect, svg, text_, title)
import TypedSvg.Attributes exposing (class, color, fill, fontFamily, fontWeight, lengthAdjust, stroke, textAnchor, viewBox)
import TypedSvg.Attributes.InEm as InEm
import TypedSvg.Attributes.InPx as InPx exposing (cx, cy, r, strokeWidth, x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute, Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Fill(..), FontWeight(..), LengthAdjust(..))


view : Model -> Html Msg
view model =
    let
        heightInPx =
            (model.window.height |> floor |> String.fromInt) ++ "px"

        mainIcon =
            getViewModeIcon model.viewMode

        mainWindow =
            case model.viewMode of
                Model.Nodes ->
                    drawGraph model

                Model.TimeLine ->
                    drawTimeLine model
    in
    div
        [ style "background-color" currentTheme.background
        , style "padding" "0.5em"
        , style "padding-top" "0"
        , style "height" heightInPx
        , id "main_div"
        ]
        [ searchBox model
        , div [ style "display" "flex", style "flex-direction" "row" ]
            [ div [ style "flex-grow" "1", style "min-width" "75%", style "min-height" heightInPx, style "position" "relative" ]
                [ mainWindow
                , div [ style "position" "absolute", style "top" "0", style "left" "0" ] [ mainIcon ]
                ]
            , viewSelectedNode model
            ]
        ]


getViewModeIcon : Model.ViewMode -> Html Msg
getViewModeIcon viewMode =
    let
        create icon msg =
            i
                [ class [ icon ]
                , style "background-color" currentTheme.graph.background
                , style "color" currentTheme.text.title
                , style "padding" "5px"
                , onClick msg
                ]
                []
    in
    case viewMode of
        Model.Nodes ->
            create "fas fa-calendar-alt" SwitchToTimeLineView

        Model.TimeLine ->
            create "fas fa-project-diagram" SwitchToNodesView


viewSelectedNode : Model -> Html Msg
viewSelectedNode model =
    div
        [ style "background-color" currentTheme.nodeBackground
        , style "border-radius" "5px"
        , style "padding" "0.5em"
        , style "margin-left" "0.8em"
        , style "margin-right" "0.3em"
        , style "width" "25%"
        , style "min-height" "100%"
        ]
        [ case model.selectedNode of
            Model.NoneSelected ->
                text ""

            Model.Selected nodeToShow ->
                selectedNode model nodeToShow
        ]


renderTag htmlTag tagText =
    htmlTag
        [ style "list-style-type" "none"
        , style "color" currentTheme.text.text
        , style "background-color" currentTheme.text.tag
        , style "border-radius" "3px"
        , style "margin" "0.1em"
        , style "padding" "0.2em"
        , style "display" "table"
        ]
        [ text tagText ]


selectedNode : Model -> Node -> Html Msg
selectedNode model node =
    case node of
        Model.TagNode n ->
            div []
                [ span [ style "font-weight" "bold", style "color" currentTheme.text.text ] [ text "Tag:" ]
                , p [] []
                , span [ style "color" currentTheme.text.text ] [ text n.tag ]
                ]

        Model.ArticleNode article ->
            let
                tags =
                    article.tags
                        |> List.map (\x -> x.tag)
                        |> List.sort

                parsedText =
                    article.parsedText
                        |> List.map
                            (\( _, text_, type_ ) ->
                                case type_ of
                                    Model.TypeText ->
                                        span [ style "color" currentTheme.text.text ] [ text text_ ]

                                    Model.TypeTag ->
                                        let
                                            bgColor =
                                                if List.any (\x -> String.toLower x == String.toLower text_) tags then
                                                    currentTheme.text.tag

                                                else
                                                    currentTheme.text.possibleTag
                                        in
                                        span
                                            [ style "color" currentTheme.text.text
                                            , style "background-color" bgColor
                                            , style "border-radius" "3px"
                                            ]
                                            [ text text_ ]

                                    Model.NewLine ->
                                        br [] []
                            )
            in
            div
                []
                [ div [ style "font-weight" "bold" ]
                    [ div [ style "color" currentTheme.text.text ] [ text article.date ]
                    , div [ style "color" currentTheme.text.text ] [ text article.title ]
                    ]
                , p [] []
                , span [] parsedText
                , p [] []
                , div
                    [ style "color" currentTheme.text.title
                    , style "font-weight" "bold"
                    ]
                    [ text "Tags: " ]
                , div []
                    [ ul
                        [ style "margin-block-start" "0.5em"
                        , style "padding-inline-start" "0.5em"
                        ]
                        (tags
                            |> List.map (renderTag li)
                        )
                    ]
                ]


searchBox : Model -> Html Msg
searchBox model =
    {--
select:focus {
outline: none;
}
    --}
    form [ onSubmit SubmitSearch ]
        [ div
            [ style "display" "flex"
            , style "flex-direction" "row"
            , style "background-color" currentTheme.form.background
            , style "margin-bottom" "1em"
            , style "padding" "0.5em"
            ]
            [ div
                [ style "flex-grow" "1"
                , style "padding" "0.1em"
                ]
                [ div
                    [ style "display" "flex"
                    , style "flex-direction" "row"
                    , style "background-color" currentTheme.form.background
                    , style "border-radius" "5px"
                    ]
                    [ span
                        [ style "padding" "0.5em"
                        , style "line-height" "2em"
                        , style "border" "0"
                        ]
                        [ i
                            [ class [ "fas fa-dollar-sign" ]
                            , style "color" currentTheme.form.button
                            , style "background-color" currentTheme.form.background
                            ]
                            []
                        ]
                    , input
                        [ type_ "search"
                        , placeholder "type search query"
                        , autofocus True
                        , value model.tagFilter
                        , onInput TagFilterInput
                        , style "flex-grow" "1"
                        , style "font-size" "1.2em"
                        , style "padding-bottom" "0.3em"
                        , style "border" "0"
                        , style "border-radius" "5px"
                        , style "background-color" currentTheme.form.inputFieldBackground
                        , style "color" currentTheme.text.text
                        ]
                        []
                    ]
                ]
            , div
                [ style "padding" "0.5em"
                , style "align-self" "center"
                , style "background-color" currentTheme.form.background
                , style "cursor" "pointer"
                ]
                [ button
                    [ type_ "submit"
                    , value "Search"
                    , style "border" "0"
                    , style "background-color" currentTheme.form.background
                    ]
                    [ i
                        [ class [ "fa-2x", "fas fa-play" ]
                        , style "color" currentTheme.form.button
                        , style "background-color" currentTheme.form.background
                        ]
                        []
                    ]
                , button
                    [ type_ "button"
                    , value "Clear"
                    , onClick ClearAll
                    , style "border" "0"
                    , style "background-color" currentTheme.form.background
                    ]
                    [ i
                        [ class [ "fa-2x", "fas fa-trash-alt" ]
                        , style "color" currentTheme.form.button
                        , style "background-color" currentTheme.form.background
                        ]
                        []
                    ]
                ]
            ]
        ]


linkElement edge =
    line
        [ strokeWidth 1
        , stroke currentTheme.graph.link.background
        , x1 edge.source.x
        , y1 edge.source.y
        , x2 edge.target.x
        , y2 edge.target.y
        ]
        []


onMouseDown : { a | id : Model.Id } -> Attribute Msg
onMouseDown node =
    Mouse.onDown (.clientPos >> DragStart node.id)


nodeElement : Model.Nodes -> Bool -> Simulation.Node Model.Id -> List (Html Msg)
nodeElement nodes selected simulationNode =
    let
        fullTitle =
            Dict.get simulationNode.id nodes
                |> Maybe.Extra.unwrap simulationNode.id
                    (\x ->
                        case x of
                            Model.TagNode y ->
                                y.tag

                            Model.ArticleNode y ->
                                y.title
                    )

        trimmedTitle =
            fullTitle
                |> String.split " "
                |> List.foldl
                    (\a b ->
                        if String.length b < 10 then
                            let
                                s =
                                    (b ++ " " ++ a)
                                        |> String.trimLeft
                            in
                            if String.length s > 13 then
                                String.slice 0 12 s ++ "."

                            else
                                s

                        else
                            b
                    )
                    ""

        strokeWidth_ =
            if selected then
                6.0

            else
                4.0

        { fillColor, strokeColor, textColor } =
            Dict.get simulationNode.id nodes
                |> Maybe.Extra.unwrap currentTheme.graph.node.unknown
                    (\x ->
                        case ( selected, x ) of
                            ( True, Model.TagNode _ ) ->
                                currentTheme.graph.node.selectedTag

                            ( False, Model.TagNode _ ) ->
                                currentTheme.graph.node.tag

                            ( True, Model.ArticleNode _ ) ->
                                currentTheme.graph.node.selectedArticle

                            ( False, Model.ArticleNode _ ) ->
                                currentTheme.graph.node.article
                    )
    in
    [ circle
        [ InEm.r 2.3
        , fill (Fill fillColor)
        , stroke strokeColor
        , strokeWidth strokeWidth_
        , cx simulationNode.x
        , cy simulationNode.y
        , style "cursor" "pointer"
        , onMouseDown simulationNode
        , onClick <| ShowNode simulationNode.id
        , onDoubleClick <| GetRelated simulationNode.id
        ]
        [ title [] [ text fullTitle ]
        ]
    , text_
        [ InEm.fontSize 0.72
        , fontFamily [ "Helvetica", "Arial", "sans-serif" ]
        , fontWeight FontWeightLighter
        , InPx.x simulationNode.x
        , InPx.y simulationNode.y
        , lengthAdjust LengthAdjustSpacingAndGlyphs
        , textAnchor AnchorMiddle
        , color textColor
        , fill (Fill textColor)
        , stroke textColor
        , style "cursor" "pointer"
        , onMouseDown simulationNode
        , onClick <| ShowNode simulationNode.id
        , onDoubleClick <| GetRelated simulationNode.id
        ]
        [ text trimmedTitle ]
    ]


drawGraph : Model -> Svg Msg
drawGraph model =
    let
        simEdges =
            Simulation.edges model.simulation

        edges : Svg Msg
        edges =
            simEdges
                |> List.map linkElement
                |> g [ class [ "links" ] ]

        isSelected : Simulation.Node Model.Id -> Bool
        isSelected node =
            case ( model.selectedNode, node ) of
                ( Model.Selected (Model.ArticleNode x), y ) ->
                    x.id == y.id

                ( Model.Selected (Model.TagNode x), y ) ->
                    x.id == y.id

                ( _, _ ) ->
                    False

        toNodeElement : Simulation.Node Model.Id -> List (Html Msg)
        toNodeElement x =
            nodeElement model.nodes (isSelected x) x

        nodes : List (Svg Msg)
        nodes =
            Simulation.nodes model.simulation
                |> List.map toNodeElement
                |> List.map (g [ class [ "nodes" ] ])

        width_ =
            TypedSvg.Types.percent 100

        height_ =
            TypedSvg.Types.percent 100
    in
    div
        [ id "graph"
        , style "background-color" currentTheme.graph.background
        , style "border-radius" "5px"
        , style "height" "100%"
        ]
        [ svg
            [ TypedSvg.Attributes.width width_
            , TypedSvg.Attributes.height height_
            ]
            (edges :: nodes)
        ]


drawTimeLine : Model -> Html Msg
drawTimeLine model =
    let
        articlesByDate =
            model.nodes
                |> Dict.values
                |> List.map
                    (\x ->
                        case x of
                            Model.ArticleNode a ->
                                Just a

                            Model.TagNode _ ->
                                Nothing
                    )
                |> Maybe.Extra.values
                |> List.foldl
                    (\a byDate ->
                        Dict.get a.date byDate
                            |> Maybe.Extra.unwrap [] identity
                            |> (\xs -> a :: xs)
                            |> (\xs -> Dict.insert a.date xs byDate)
                    )
                    Dict.empty

        sortedDates : List String
        sortedDates =
            Dict.keys articlesByDate
                |> List.sort
                |> List.reverse

        listTags : List Model.Tag -> List (Html Msg)
        listTags tags =
            tags
                |> List.map (\x -> renderTag div x.tag)

        listDays articles =
            articles
                |> List.map
                    (\x ->
                        li []
                            [ div
                                [ style "display" "flex", style "flex-direction" "row" ]
                                (a
                                    [ href "#"
                                    , onClick <| ShowNode x.id
                                    , style "color" currentTheme.text.text
                                    , style "text-decoration" "none"
                                    , style "margin" "0.1em"
                                    , style "padding" "0.2em"
                                    ]
                                    [ text <| x.title ]
                                    :: listTags x.tags
                                )
                            ]
                    )
    in
    div
        [ id "timeline"
        , style "background-color" currentTheme.graph.background
        , style "border-radius" "5px"
        , style "height" "100%"
        , style "display" "flex"
        ]
        [ ul [ style "list-style-type" "none" ]
            (sortedDates
                |> List.map
                    (\day ->
                        li []
                            [ span [ style "color" currentTheme.text.title ] [ text day ]
                            , ul [ style "list-style-type" "none" ]
                                (Dict.get
                                    day
                                    articlesByDate
                                    |> Maybe.Extra.unwrap [] listDays
                                )
                            ]
                    )
            )
        ]
