module View exposing (view)

import ColorTheme exposing (currentTheme)
import Dict exposing (Dict)
import Html exposing (Html, a, br, button, div, form, h1, i, input, li, menu, menuitem, p, span, ul)
import Html.Attributes exposing (autofocus, class, href, id, placeholder, style, type_, value)
import Html.Events
    exposing
        ( onClick
        , onDoubleClick
        , onInput
        , onMouseDown
        , onSubmit
        )
import Html.Events.Extra.Mouse as Mouse
import Http
import Json.Decode as JD
import Maybe.Extra
import Model exposing (Link, Model, Msg(..), Node(..), NodeViewState(..))
import Model.Article exposing (Article)
import Model.Base exposing (Base, Id)
import Model.ParsedText exposing (ParsedText, TextType(..))
import Model.Tag exposing (Tag)
import Path.LowLevel as LL
import Simulation
import TagEdit.TagEdit as TagEdit
import TypedSvg as Svg exposing (circle, g, line, svg, text_, title)
import TypedSvg.Attributes as SvgAttr exposing (color, fill, fontFamily, fontWeight, lengthAdjust, stroke, textAnchor)
import TypedSvg.Attributes.InEm as InEm
import TypedSvg.Attributes.InPx as InPx exposing (cx, cy, r, strokeWidth, x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute, Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Fill(..), FontWeight(..), LengthAdjust(..))
import Util
import Util.ColorPicker as ColorPicker
import Util.CustomRightClickEvent exposing (onRightClick)
import Util.LightBox as LightBox
import Util.RemoteData exposing (RemoteData(..))


view : Model -> Html Msg
view model =
    let
        heightInPx =
            (model.window.height |> floor |> String.fromInt) ++ "px"

        mainIcon =
            getViewModeIcon model.viewState

        ( selectedNodeView, mainWindow ) =
            case model.viewState of
                Model.Empty ->
                    ( text "", text "" )

                Model.TimeLine nodeData ->
                    ( viewSelectedNode nodeData.selectedNode
                    , drawTimeLine nodeData
                    )

                Model.Nodes nodeData ->
                    ( viewSelectedNode nodeData.selectedNode
                    , drawGraph model.simulation nodeData
                    )

                Model.DragNode { nodeData } ->
                    ( viewSelectedNode nodeData.selectedNode
                    , drawGraph model.simulation nodeData
                    )

                Model.EditTags viewState selected ->
                    ( viewSelectedNode selected
                    , TagEdit.view TagEditTagger model.tagEditState
                    )
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
            , selectedNodeView
            ]
        , showError model
        ]


showError : Model -> Html Msg
showError model =
    case model.user of
        Suspended ->
            text ""

        InFlight ->
            text ""

        Success _ ->
            text ""

        Fail e ->
            LightBox.view
                LightBox.Normal
                (errorPopup e)
                Nothing


errorPopup : Http.Error -> Html Msg
errorPopup error =
    let
        cssContainer =
            [ style "display" "flex"
            , style "flex-direction" "column"
            , style "background-color" "white"
            ]

        cssHeader =
            [ style "background-color" "red" ]

        cssBody =
            [ style "padding" "2rem"
            , style "font-size" "x-large"
            ]

        cssFooter =
            []
    in
    div
        cssContainer
        [ div cssHeader
            [ h1 [] [ text "An error occurred" ] ]
        , div cssBody
            (case error of
                Http.BadStatus statusCode ->
                    case statusCode of
                        401 ->
                            [ div
                                []
                                [ text "You are not logged in." ]
                            , div
                                []
                                [ text "You can login ", a [ href "auth/signin" ] [ text "here" ], text "." ]
                            ]

                        _ ->
                            [ div [] [ text ("Request failed, server return status code " ++ String.fromInt statusCode) ]
                            ]

                _ ->
                    [ text (Util.httpErrorToString error) ]
            )
        , div cssFooter
            []
        ]


getViewModeIcon : Model.ViewState -> Html Msg
getViewModeIcon viewMode =
    let
        create icon msg =
            i
                [ SvgAttr.class [ icon ]
                , style "background-color" currentTheme.graph.background
                , style "color" currentTheme.text.title
                , style "padding" "5px"
                , onClick msg
                ]
                []
    in
    case viewMode of
        Model.Empty ->
            text ""

        Model.DragNode _ ->
            create "fas fa-calendar-alt" SwitchToTimeLineView

        Model.Nodes _ ->
            create "fas fa-calendar-alt" SwitchToTimeLineView

        Model.TimeLine _ ->
            create "fas fa-project-diagram" SwitchToNodesView

        Model.EditTags _ _ ->
            text ""


viewSelectedNode : Model.Node -> Html Msg
viewSelectedNode selectedNode_ =
    div
        [ style "background-color" currentTheme.nodeBackground
        , style "border-radius" "5px"
        , style "padding" "0.5em"
        , style "margin-left" "0.8em"
        , style "margin-right" "0.3em"
        , style "width" "25%"
        , style "min-height" "100%"
        ]
        [ selectedNode selectedNode_ ]


renderTag : (List (Attribute Msg) -> List (Html Msg) -> Html Msg) -> String -> Html Msg
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


selectedNode : Node -> Html Msg
selectedNode selectedNode_ =
    case selectedNode_ of
        Model.LinkNode _ ->
            div []
                [ span [ style "font-weight" "bold", style "color" currentTheme.text.text ] [ text "" ]
                , p [] []
                , span [ style "color" currentTheme.text.text ] [ text "this is a link between 2 nodes." ]
                ]

        Model.TagNode n ->
            div []
                [ span [ style "font-weight" "bold", style "color" currentTheme.text.text ] [ text "Tag:" ]
                , p [] []
                , span [ style "color" currentTheme.text.text ] [ text n.tag ]
                ]

        Model.ArticleNode article ->
            viewArticle article


viewArticle : Article -> Html Msg
viewArticle article =
    let
        tags =
            article.tags
                |> List.map .tag
    in
    div
        []
        [ div [ style "font-weight" "bold" ]
            [ div [ style "color" currentTheme.text.text ] [ text article.date ]
            , div [ style "color" currentTheme.text.text ] [ text article.title ]
            ]
        , p [] []
        , span [] (articleToHtml article)
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
        , div []
            [ button [ class "button", onClick (OpenTagEditor article) ] [ text "Edit Tags" ] ]
        ]


articleToHtml : Article -> List (Html Msg)
articleToHtml article =
    let
        tags =
            article.tags
                |> List.map .tag
    in
    article.parsedText
        |> List.map
            (\( _, text_, type_ ) ->
                case type_ of
                    TypeText ->
                        span [ style "color" currentTheme.text.text ] [ text text_ ]

                    TypeTag ->
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

                    NewLine ->
                        br [] []
            )


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
                            [ SvgAttr.class [ "fas fa-dollar-sign" ]
                            , style "color" currentTheme.form.button
                            , style "background-color" currentTheme.form.background
                            ]
                            []
                        ]
                    , input
                        [ type_ "search"
                        , placeholder "type search query"
                        , autofocus True
                        , value model.searchFilter.tagFilter
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
                        [ SvgAttr.class [ "fa-2x", "fas fa-play" ]
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
                        [ SvgAttr.class [ "fa-2x", "fas fa-trash-alt" ]
                        , style "color" currentTheme.form.button
                        , style "background-color" currentTheme.form.background
                        ]
                        []
                    ]
                ]
            ]
        ]


linkElementMenu : Model.NodeData -> Simulation.Edge String -> Svg Msg
linkElementMenu nodeData edge =
    let
        nodeId =
            Model.getNodeId nodeData.selectedNode

        edgeId =
            edge.source.id ++ "->" ++ edge.target.id

        link : Maybe Link
        link =
            getLinkByEdge nodeData.nodes edge

        selected =
            nodeId == edgeId

        ( centerX, centerY ) =
            ( (edge.source.x + edge.target.x) / 2
            , (edge.source.y + edge.target.y) / 2
            )

        menus =
            case ( selected, nodeData.nodeViewState, link ) of
                ( False, _, _ ) ->
                    []

                ( True, Default, _ ) ->
                    []

                ( True, ShowMenu, Nothing ) ->
                    []

                ( True, ShowColorPalette _, Nothing ) ->
                    []

                ( True, ShowMenu, Just lnk ) ->
                    [ TypedSvg.Core.foreignObject
                        [ InPx.x centerX
                        , InPx.y centerY
                        , InPx.width 400
                        , InPx.height 300
                        ]
                        [ div
                            [ class "html-in-svg link-menu" ]
                            [ menu
                                [ class "box-shadow link-menu-content" ]
                                [ menuitem
                                    [ class "link-menu-item"
                                    , onClick ShowColourPalette
                                    ]
                                    [ text "Set Color" ]
                                , menuitem
                                    [ class "link-menu-item"
                                    , onClick (RemoveLinkColor lnk)
                                    ]
                                    [ text "Remove Color" ]

                                -- , div
                                --     [ class "link-menu-item", onClick (RemoveLinkColor link) ]
                                --     [ text "Add Note" ]
                                ]
                            ]
                        ]
                    ]

                ( True, ShowColorPalette currentColor, Just lnk ) ->
                    [ TypedSvg.Core.foreignObject
                        [ InPx.x centerX
                        , InPx.y centerY
                        , InPx.width 400
                        , InPx.height 300
                        ]
                        [ div
                            [ class "html-in-svg" ]
                            [ ColorPicker.view lnk currentColor
                            ]
                        ]
                    ]
    in
    g [] menus


getLinkByEdge : Model.Nodes -> Simulation.Edge String -> Maybe Link
getLinkByEdge nodes edge =
    let
        edgeId =
            edge.source.id ++ "->" ++ edge.target.id

        node : Maybe Node
        node =
            Dict.get edgeId nodes

        link : Maybe Link
        link =
            node
                |> Maybe.Extra.unwrap
                    Nothing
                    (\x ->
                        case x of
                            Model.ArticleNode _ ->
                                Nothing

                            Model.TagNode _ ->
                                Nothing

                            Model.LinkNode l ->
                                Just l
                    )
    in
    link


preventBrowserContextMenu : Attribute Msg
preventBrowserContextMenu =
    Html.Events.preventDefaultOn "contextmenu" (JD.succeed ( NoOp, True ))


linkElement : Model.NodeData -> Simulation.Edge String -> Svg Msg
linkElement nodeData edge =
    let
        nodeId =
            Model.getNodeId nodeData.selectedNode

        edgeId =
            edge.source.id ++ "->" ++ edge.target.id

        selected =
            nodeId == edgeId

        link : Maybe Link
        link =
            getLinkByEdge nodeData.nodes edge

        color =
            Maybe.Extra.unwrap
                currentTheme.graph.link.background
                (\l ->
                    Maybe.Extra.unwrap
                        currentTheme.graph.link.background
                        identity
                        l.color
                )
                link
    in
    Maybe.Extra.unwrap
        (text "")
        (\lnk ->
            line
                [ strokeWidth 5
                , stroke color
                , x1 edge.source.x
                , y1 edge.source.y
                , x2 edge.target.x
                , y2 edge.target.y
                , onRightClick (ShowAndToggleMenu (Model.getNodeId (Model.LinkNode lnk)))
                , preventBrowserContextMenu
                , SvgAttr.id "link"
                ]
                []
        )
        link


onMouseDown : { a | id : Id } -> Attribute Msg
onMouseDown node =
    Mouse.onDown (.clientPos >> DragStart node.id)


svgFontSize =
    16


circleRadius =
    2.3


drawArc circleX circleY circleRadiusInEm angleWidth { startAngle, icon, onClickMsg, helpText } =
    let
        radius =
            1.1 * circleRadiusInEm

        endAngle =
            startAngle + angleWidth

        sliceSize =
            1.9

        ( textX, textY ) =
            ( circleX - svgFontSize / 2 + svgFontSize * (radius + sliceSize / 2) * cos (degrees (startAngle + angleWidth / 2))
            , circleY - svgFontSize / 2 + svgFontSize * (radius + sliceSize / 2) * sin (degrees (startAngle + angleWidth / 2))
            )

        ( x11, y11 ) =
            ( circleX + svgFontSize * radius * cos (degrees startAngle)
            , circleY + svgFontSize * radius * sin (degrees startAngle)
            )

        ( x12, y12 ) =
            ( circleX + svgFontSize * (radius + sliceSize) * cos (degrees startAngle)
            , circleY + svgFontSize * (radius + sliceSize) * sin (degrees startAngle)
            )

        ( x21, y21 ) =
            ( circleX + svgFontSize * radius * cos (degrees endAngle)
            , circleY + svgFontSize * radius * sin (degrees endAngle)
            )

        ( x22, y22 ) =
            ( circleX + svgFontSize * (radius + sliceSize) * cos (degrees endAngle)
            , circleY + svgFontSize * (radius + sliceSize) * sin (degrees endAngle)
            )

        ( xb1, yb1 ) =
            ( circleX + 1.16 * svgFontSize * (radius + sliceSize) * cos (degrees (startAngle + angleWidth / 2))
            , circleY + 1.16 * svgFontSize * (radius + sliceSize) * sin (degrees (startAngle + angleWidth / 2))
            )

        ( xb2, yb2 ) =
            ( circleX + 1.16 * svgFontSize * radius * cos (degrees (startAngle + angleWidth / 2))
            , circleY + 1.16 * svgFontSize * radius * sin (degrees (startAngle + angleWidth / 2))
            )

        myPath : List LL.SubPath
        myPath =
            [ { moveto = LL.MoveTo LL.Absolute ( x11, y11 )
              , drawtos =
                    [ LL.LineTo LL.Absolute [ ( x12, y12 ) ]
                    , LL.QuadraticBezierCurveTo LL.Absolute [ ( ( xb1, yb1 ), ( x22, y22 ) ) ]
                    , LL.LineTo LL.Absolute [ ( x21, y21 ) ]
                    , LL.QuadraticBezierCurveTo LL.Absolute [ ( ( xb2, yb2 ), ( x11, y11 ) ) ]
                    ]
              }
            ]

        dsString =
            LL.toString myPath
    in
    [ Svg.path
        [ SvgAttr.d dsString
        , SvgAttr.class [ "article-menu-back" ]
        , onClick onClickMsg
        ]
        []
    , svg
        [ SvgAttr.width (TypedSvg.Types.em 1)
        , SvgAttr.height (TypedSvg.Types.em 1)
        , InPx.x textX
        , InPx.y textY
        ]
        [ Svg.use
            [ SvgAttr.xlinkHref <| "./fontawesome/sprites/solid.svg#" ++ icon
            , SvgAttr.class [ "icon" ]
            , onClick onClickMsg
            ]
            []
        ]
    , Svg.path
        [ SvgAttr.d dsString
        , SvgAttr.class [ "article-menu" ]
        , onClick onClickMsg
        ]
        [ title [] [ text helpText ] ]
    ]


nodeElement : Model.NodeData -> Simulation.Node Id -> List (Html Msg)
nodeElement nodeData simulationNode =
    let
        nodeId =
            Model.getNodeId nodeData.selectedNode

        selected =
            nodeId == simulationNode.id

        fullTitle =
            Dict.get simulationNode.id nodeData.nodes
                |> Maybe.Extra.unwrap simulationNode.id
                    (\x ->
                        case x of
                            Model.TagNode y ->
                                y.tag

                            Model.ArticleNode y ->
                                y.title

                            Model.LinkNode _ ->
                                "<LinkNode>"
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

        { fillColor, strokeColor, textColor, id } =
            Dict.get simulationNode.id nodeData.nodes
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

                            ( _, Model.LinkNode _ ) ->
                                currentTheme.graph.node.article
                    )

        menus =
            -- lock/unlock, hide this, hide connected, hide not connected, hide all but this, connectTo
            -- icons to use? hubspot,project-diagram,code-branch,
            case ( selected, nodeData.nodeViewState ) of
                ( False, _ ) ->
                    []

                ( True, Default ) ->
                    []

                ( True, ShowMenu ) ->
                    [ { helpText = "Unlock nodes and re-layout", startAngle = 270, icon = "lock-open", onClickMsg = Model.MenuMsg <| Model.Unlock simulationNode.id }
                    , { helpText = "Remove this node", startAngle = 342, icon = "trash", onClickMsg = Model.MenuMsg <| Model.Remove simulationNode.id }
                    , { helpText = "Remove this and connected nodes", startAngle = 54, icon = "unlink", onClickMsg = Model.MenuMsg <| Model.RemoveConnected simulationNode.id }
                    , { helpText = "Not implemented yet", startAngle = 126, icon = "space-shuttle", onClickMsg = Model.MenuMsg <| Model.RemoveNotConnected simulationNode.id }
                    , { helpText = "Not implemented yet", startAngle = 198, icon = "space-shuttle", onClickMsg = Model.MenuMsg <| Model.ConnectTo simulationNode.id }
                    ]
                        |> List.concatMap (drawArc simulationNode.x simulationNode.y circleRadius 70)

                ( True, ShowColorPalette _ ) ->
                    []

        clickEvent =
            if selected then
                ToggleMenu

            else
                ShowNode simulationNode.id
    in
    [ circle
        [ InEm.r circleRadius
        , fill (Fill fillColor)
        , stroke strokeColor
        , strokeWidth strokeWidth_
        , cx simulationNode.x
        , cy simulationNode.y
        , style "cursor" "pointer"
        , onMouseDown simulationNode
        , onClick clickEvent
        , onDoubleClick <| GetRelated simulationNode.id
        , SvgAttr.id id
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
        , onClick clickEvent
        , onDoubleClick <| GetRelated simulationNode.id
        ]
        [ text trimmedTitle ]
    ]
        ++ menus


drawGraph : Simulation.Simulation String -> Model.NodeData -> Svg Msg
drawGraph simulation nodeData =
    let
        simEdges : List (Simulation.Edge String)
        simEdges =
            Simulation.edges simulation

        edges : Svg Msg
        edges =
            simEdges
                |> List.map (linkElement nodeData)
                |> g [ SvgAttr.class [ "links" ] ]

        edgeMenu =
            simEdges
                |> List.map (linkElementMenu nodeData)

        toNodeElement : Simulation.Node Id -> List (Html Msg)
        toNodeElement x =
            nodeElement nodeData x

        nodes : List (Svg Msg)
        nodes =
            Simulation.nodes simulation
                |> List.map toNodeElement
                |> List.map (g [ SvgAttr.class [ "nodes" ] ])

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
        , style "font-size" (String.fromInt svgFontSize ++ "px")
        ]
        [ svg
            [ SvgAttr.width width_
            , SvgAttr.height height_
            ]
            (edges :: (nodes ++ edgeMenu))
        ]


drawTimeLine : Model.TimeLineData -> Html Msg
drawTimeLine { nodes } =
    let
        articlesByDate : Dict String (List Article)
        articlesByDate =
            nodes
                |> Dict.values
                |> List.map
                    (\x ->
                        case x of
                            Model.ArticleNode a ->
                                Just a

                            Model.TagNode _ ->
                                Nothing

                            Model.LinkNode _ ->
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

        listTags : List Tag -> List (Html Msg)
        listTags tags =
            tags
                |> List.map (\x -> renderTag div x.tag)

        listDays : List Article -> List (Html Msg)
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
                                    :: listTags (getArticleTags nodes x)
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


getArticleTags : Model.Nodes -> Article -> List Tag
getArticleTags nodes article =
    nodes
        |> Dict.filter
            (\_ n ->
                case n of
                    Model.ArticleNode _ ->
                        False

                    Model.TagNode _ ->
                        False

                    Model.LinkNode l ->
                        l.from == article.id
            )
        |> Dict.values
        |> List.map
            (\n ->
                case n of
                    Model.ArticleNode _ ->
                        Nothing

                    Model.TagNode _ ->
                        Nothing

                    Model.LinkNode l ->
                        Dict.get l.to nodes
            )
        |> Maybe.Extra.values
        |> List.foldl
            (\n acc ->
                case n of
                    Model.TagNode t ->
                        t :: acc

                    Model.ArticleNode _ ->
                        acc

                    Model.LinkNode _ ->
                        acc
            )
            []
        |> List.sortBy (\t -> t.tag)
