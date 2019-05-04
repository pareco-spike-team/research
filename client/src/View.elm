module View exposing (view)

import Color exposing (Color)
import Dict exposing (Dict)
import Force
import Graph exposing (Edge, Graph, Node, NodeId)
import Html exposing (..)
import Html.Attributes exposing (autofocus, class, placeholder, style, type_, value)
import Html.Events exposing (onClick, onDoubleClick, onInput, onMouseDown, onSubmit)
import Html.Events.Extra.Mouse as Mouse
import Maybe.Extra
import Model exposing (Article, Model, Msg(..), Node)
import TypedSvg exposing (circle, g, line, rect, svg, text_, title)
import TypedSvg.Attributes exposing (class, color, fill, fontFamily, fontWeight, lengthAdjust, stroke, textAnchor, viewBox)
import TypedSvg.Attributes.InEm as InEm
import TypedSvg.Attributes.InPx as InPx exposing (cx, cy, r, strokeWidth, x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute, Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Fill(..), FontWeight(..), LengthAdjust(..))


view : Model -> Html Msg
view model =
    div
        [ style "background-color" "#D2D5DA"
        , style "padding" "0.5em"
        , style "padding-top" "0"
        ]
        [ searchBox model
        , div [ style "display" "flex", style "flex-direction" "row" ]
            [ div [ style "flex-grow" "1", style "min-width" "75%" ] [ drawGraph model ]
            , Maybe.Extra.unwrap (text "")
                (\nodeToShow ->
                    div
                        [ style "background-color" "#FAFAFA"
                        , style "border-radius" "5px"
                        , style "padding" "0.5em"
                        , style "margin-left" "0.8em"
                        , style "margin-right" "0.3em"
                        , style "width" "25%"
                        ]
                        [ showNode model nodeToShow ]
                )
                model.showNode
            ]
        ]


showNode : Model -> Node -> Html Msg
showNode model node =
    case node of
        Model.TagNode n ->
            div []
                [ span [ style "font-weight" "bold" ] [ text "Tag:" ]
                , p [] []
                , span [] [ text n.tag ]
                ]

        Model.ArticleNode article ->
            let
                tags =
                    article.tags
                        |> List.map (\x -> x.tag)
                        |> List.sort

                theText =
                    [ text article.text ]

                parsedText =
                    parseText model article
                        |> List.map
                            (\( _, text_, type_ ) ->
                                case type_ of
                                    TypeText ->
                                        span [] [ text text_ ]

                                    TypeTag ->
                                        let
                                            bgColor =
                                                if List.any (\x -> String.toLower x == String.toLower text_) tags then
                                                    "lightgreen"

                                                else
                                                    "yellow"
                                        in
                                        span [ style "background-color" bgColor ] [ text text_ ]

                                    NewLine ->
                                        br [] []
                            )
            in
            div
                []
                [ div [ style "font-weight" "bold" ]
                    [ div [] [ text article.date ]
                    , div [] [ text article.title ]
                    ]
                , p [] []
                , span [] parsedText
                , p [] []
                , div [] [ text "Tags: " ]
                , div []
                    (tags
                        |> List.map (\x -> span [] [ text x ])
                        |> List.intersperse (br [] [])
                    )
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
            , style "background-color" "#E8E8EA"
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
                    , style "background-color" "white"
                    , style "border-radius" "5px"
                    ]
                    [ span
                        [ style "padding" "0.5em"
                        , style "line-height" "2em"
                        , style "border" "0"
                        ]
                        [ i [ class [ "fas fa-dollar-sign" ] ] [] ]
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
                        ]
                        []
                    ]
                ]
            , div
                [ style "padding" "0.5em"
                , style "align-self" "center"
                , style "background-color" "#E8E8EA"
                , style "cursor" "pointer"
                ]
                [ button
                    [ type_ "submit"
                    , value "Search"
                    , style "border" "0"
                    , style "background-color" "#E8E8EA"
                    ]
                    [ i [ class [ "fa-2x", "fas fa-play" ] ] [] ]
                ]
            ]
        ]


linkElement graph edge =
    let
        source =
            Maybe.withDefault (Force.entity 0 "") <| Maybe.map (.node >> .label) <| Graph.get edge.from graph

        target =
            Maybe.withDefault (Force.entity 0 "") <| Maybe.map (.node >> .label) <| Graph.get edge.to graph
    in
    line
        [ strokeWidth 1
        , stroke (Color.rgb255 170 170 170)
        , x1 source.x
        , y1 source.y
        , x2 target.x
        , y2 target.y
        ]
        []


onMouseDown : { a | id : NodeId } -> Attribute Msg
onMouseDown node =
    Mouse.onDown (.clientPos >> DragStart node.id)


nodeElement nodes node =
    let
        fullTitle =
            Dict.get node.label.value nodes
                |> Maybe.Extra.unwrap node.label.value
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

        ( fillColor, strokeColor, textColor ) =
            Dict.get node.label.value nodes
                |> Maybe.Extra.unwrap ( Color.brown, Color.darkBrown, Color.black )
                    (\x ->
                        case x of
                            Model.TagNode _ ->
                                ( Color.green, Color.darkGreen, Color.black )

                            Model.ArticleNode _ ->
                                ( Color.lightBlue, Color.blue, Color.black )
                    )
    in
    [ circle
        [ InEm.r 2.3
        , fill (Fill fillColor)
        , stroke strokeColor
        , strokeWidth 3
        , cx node.label.x
        , cy node.label.y
        , style "cursor" "pointer"
        , onMouseDown node
        , onClick <| ShowNode node.id
        , onDoubleClick <| GetRelated node.id
        ]
        [ title [] [ text fullTitle ]
        ]
    , text_
        [ InEm.fontSize 0.72
        , fontFamily [ "Helvetica", "Arial", "sans-serif" ]
        , fontWeight FontWeightLighter
        , InPx.x node.label.x
        , InPx.y node.label.y
        , lengthAdjust LengthAdjustSpacingAndGlyphs
        , textAnchor AnchorMiddle
        , color textColor
        , fill (Fill textColor)
        , stroke textColor
        , style "cursor" "pointer"
        , onMouseDown node
        , onClick <| ShowNode node.id
        , onDoubleClick <| GetRelated node.id
        ]
        [ text trimmedTitle ]
    ]


drawGraph : Model -> Svg Msg
drawGraph model =
    let
        edges : Svg Msg
        edges =
            Graph.edges model.graph
                |> List.map (linkElement model.graph)
                |> g [ class [ "links" ] ]

        nodes : List (Svg Msg)
        nodes =
            Graph.nodes model.graph
                |> List.map (nodeElement model.nodes)
                |> List.map (g [ class [ "nodes" ] ])
    in
    div [ style "background-color" "#FAFAFA", style "border-radius" "5px" ]
        [ svg [ viewBox 0 0 Model.width Model.height ]
            (edges :: nodes)
        ]



{----}


type alias Index =
    Int


type alias ParsedText =
    ( Index, String, TextType )


type TextType
    = TypeText
    | TypeTag
    | NewLine


parseText : Model -> Article -> List ParsedText
parseText model article =
    let
        lowerCaseText =
            String.toLower article.text

        tagsLower =
            model.allTags |> List.map (\x -> ( String.toLower x.tag, x ))

        doTag : ( String, Model.Tag ) -> List ParsedText -> List ParsedText
        doTag ( strTag, tag ) acc =
            let
                parts : List ( Int, String, TextType )
                parts =
                    String.indexes strTag lowerCaseText
                        |> List.map (\x -> ( x, tag.tag, TypeTag ))
            in
            parts ++ acc

        parsed : List ParsedText
        parsed =
            tagsLower
                |> List.foldl doTag []
                |> List.sortBy (\( a, _, _ ) -> a)
                |> List.foldl
                    (\( tidx, ttag, ttype ) acc ->
                        case acc of
                            ( idx, tag, type_ ) :: tail ->
                                if (idx + String.length tag) > tidx then
                                    if String.length ttag > String.length tag then
                                        ( tidx, ttag, ttype ) :: tail

                                    else
                                        ( idx, tag, type_ ) :: tail

                                else
                                    ( tidx, ttag, ttype ) :: acc

                            _ ->
                                ( tidx, ttag, ttype ) :: acc
                    )
                    []
    in
    List.foldl
        (\p acc ->
            let
                hh =
                    List.head acc

                ( index, text, _ ) =
                    Maybe.withDefault ( 0, article.text, TypeText ) hh

                ( idx, tag, _ ) =
                    p

                left =
                    ( index, String.slice index idx article.text, TypeText )

                strLen =
                    String.length tag

                center =
                    ( idx, String.slice idx (idx + strLen) article.text, TypeTag )

                rest =
                    ( idx + strLen, String.dropLeft (idx + strLen) article.text, TypeText )
            in
            rest :: center :: left :: (List.tail acc |> Maybe.withDefault [])
        )
        []
        (parsed
            |> List.reverse
        )
        |> List.foldl
            (\x acc ->
                case x of
                    ( idx, text, TypeText ) ->
                        (String.split "\n" text
                            |> List.map
                                (\i ->
                                    if i == "" then
                                        ( idx, "\n", NewLine )

                                    else
                                        ( idx, i, TypeText )
                                )
                        )
                            ++ acc

                    _ ->
                        x :: acc
            )
            []
