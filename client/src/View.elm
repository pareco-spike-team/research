module View exposing (view)

import Color exposing (Color)
import ColorTheme exposing (currentTheme)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (autofocus, class, placeholder, style, type_, value)
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
    div
        [ style "background-color" currentTheme.background
        , style "padding" "0.5em"
        , style "padding-top" "0"
        ]
        [ searchBox model
        , div [ style "display" "flex", style "flex-direction" "row" ]
            [ div [ style "flex-grow" "1", style "min-width" "75%" ] [ drawGraph model ]
            , viewSelectedNode model
            ]
        ]


viewSelectedNode : Model -> Html Msg
viewSelectedNode model =
    div
        [ style "background-color" currentTheme.nodeBackground
        , style "border-radius" "5px"
        , style "padding" "0.5em"
        , style "margin-left" "0.8em"
        , style "margin-right" "0.3em"
        , style "width" "25%"
        ]
        [ case model.selectedNode of
            Model.NoneSelected ->
                text ""

            Model.Selected nodeToShow ->
                selectedNode model nodeToShow
        ]


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
                            |> List.map
                                (\x ->
                                    li
                                        [ style "list-style-type" "none"
                                        , style "color" currentTheme.text.text
                                        , style "background-color" currentTheme.text.tag
                                        , style "border-radius" "3px"
                                        , style "margin" "0.1em"
                                        , style "padding" "0.2em"
                                        , style "display" "table"
                                        ]
                                        [ text x ]
                                )
                         -- |> List.intersperse (br [] [])
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


nodeElement : Model.Nodes -> Simulation.Node Model.Id -> List (Html Msg)
nodeElement nodes simulationNode =
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

        { fillColor, strokeColor, textColor } =
            Dict.get simulationNode.id nodes
                |> Maybe.Extra.unwrap currentTheme.graph.node.unknown
                    (\x ->
                        case x of
                            Model.TagNode _ ->
                                currentTheme.graph.node.tag

                            Model.ArticleNode _ ->
                                currentTheme.graph.node.article
                    )
    in
    [ circle
        [ InEm.r 2.3
        , fill (Fill fillColor)
        , stroke strokeColor
        , strokeWidth 3
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

        nodes : List (Svg Msg)
        nodes =
            Simulation.nodes model.simulation
                |> List.map (nodeElement model.nodes)
                |> List.map (g [ class [ "nodes" ] ])
    in
    div [ style "background-color" currentTheme.graph.background, style "border-radius" "5px" ]
        [ svg [ viewBox 0 0 Model.width Model.height ]
            (edges :: nodes)
        ]
