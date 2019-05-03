module Main exposing (init, main, update, view)

import Array exposing (Array)
import Browser
import Browser.Events
import Color exposing (Color)
import Dict exposing (Dict)
import Force exposing (State)
import Graph exposing (Edge, Graph, Node, NodeContext, NodeId)
import Html exposing (..)
import Html.Attributes exposing (autofocus, class, placeholder, style, type_, value)
import Html.Events exposing (onClick, onDoubleClick, onInput, onMouseDown, onSubmit)
import Html.Events.Extra.Mouse as Mouse
import Http
import HttpBuilder exposing (..)
import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Decode.Pipeline exposing (optional, required)
import List.Extra
import Maybe.Extra
import Time
import TypedSvg exposing (circle, g, line, rect, svg, text_, title)
import TypedSvg.Attributes exposing (class, color, fill, fontFamily, fontWeight, lengthAdjust, stroke, textAnchor, viewBox)
import TypedSvg.Attributes.InEm as InEm
import TypedSvg.Attributes.InPx as InPx exposing (cx, cy, r, strokeWidth, x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute, Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Fill(..), FontWeight(..), LengthAdjust(..))


w : Float
w =
    1200


h : Float
h =
    900


type Msg
    = ArticleSearchResult (Result Http.Error (List Article))
    | ArticleSelectedResult (Result Http.Error (List Article))
    | AllTags (Result Http.Error (List Tag))
    | TagFilterInput String
    | SubmitSearch
    | GetRelated NodeId
    | ShowNode NodeId
    | DragStart NodeId ( Float, Float )
    | DragAt ( Float, Float )
    | DragEnd ( Float, Float )
    | Tick Time.Posix


type alias Model =
    { nodes : Nodes
    , showNode : Maybe Node
    , allTags : List Tag
    , tagFilter : String
    , articleFilter : String
    , drag : Maybe Drag
    , simulation : Force.State NodeId
    , graph : Graph Entity ()
    }


type alias Drag =
    { start : ( Float, Float )
    , current : ( Float, Float )
    , index : NodeId
    }


type alias Id =
    String


type alias Tags =
    Dict Id Tag


type alias Articles =
    Dict Id Article


type alias Base a =
    { a | id : String, index : Int }


type alias Tag =
    Base { tag : String }


type alias Article =
    Base
        { date : String
        , title : String
        , text : String
        , tags : List Tag
        }


type Node
    = ArticleNode Article
    | TagNode Tag


type alias Nodes =
    Dict Id Node


type RemoteData a
    = Suspended
    | Loading
    | Loaded a
    | Error String


type alias Entity =
    Force.Entity NodeId { value : String }



{--main --}


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


initializeNode : NodeContext String () -> NodeContext Entity ()
initializeNode ctx =
    { node = { id = ctx.node.id, label = Force.entity ctx.node.id ctx.node.label }
    , incoming = ctx.incoming
    , outgoing = ctx.outgoing
    }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        model : Model
        model =
            { nodes = Dict.empty
            , showNode = Nothing
            , allTags = []
            , tagFilter = ""
            , articleFilter = ""
            , drag = Nothing
            , simulation = Force.simulation []
            , graph = buildGraph Dict.empty
            }
    in
    ( model, Cmd.batch [ getAllTags ] )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.drag of
        Nothing ->
            if Force.isCompleted model.simulation then
                Sub.none

            else
                Browser.Events.onAnimationFrame Tick

        Just _ ->
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map (.clientPos >> DragAt) Mouse.eventDecoder)
                , Browser.Events.onMouseUp (Decode.map (.clientPos >> DragEnd) Mouse.eventDecoder)
                , Browser.Events.onAnimationFrame Tick
                ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TagFilterInput s ->
            ( { model | tagFilter = s }, Cmd.none )

        SubmitSearch ->
            ( model, search model )

        AllTags (Ok tags) ->
            ( { model | allTags = tags }, Cmd.none )

        AllTags (Err e) ->
            ( model, Cmd.none )

        ArticleSearchResult (Ok articles) ->
            articleSearchResult model articles

        ArticleSearchResult (Err e) ->
            ( model, Cmd.none )

        ArticleSelectedResult (Ok articles) ->
            let
                articleId =
                    case model.showNode of
                        Just (ArticleNode a) ->
                            a.id

                        _ ->
                            ""

                theArticle =
                    articles
                        |> List.filter (\x -> x.id == articleId)
                        |> List.foldl
                            (\x dict ->
                                dict
                                    |> Dict.get articleId
                                    |> Maybe.Extra.unwrap x (\y -> { x | tags = x.tags ++ y.tags })
                                    |> (\y -> Dict.insert articleId y dict)
                            )
                            Dict.empty
                        |> Dict.get articleId
                        |> Maybe.map ArticleNode
            in
            ( { model | showNode = theArticle }, Cmd.none )

        ArticleSelectedResult (Err e) ->
            ( model, Cmd.none )

        GetRelated index ->
            let
                node =
                    model.graph
                        |> Graph.get index
                        |> Maybe.Extra.unwrap Nothing (\n -> Dict.get n.node.label.value model.nodes)
            in
            case node of
                Nothing ->
                    ( model, Cmd.none )

                Just (TagNode x) ->
                    ( model, getArticlesWithTag x )

                Just (ArticleNode x) ->
                    ( model, getTagsForArticle model.nodes x ArticleSearchResult )

        ShowNode index ->
            updateShowNode model index

        Tick t ->
            case model.drag of
                Nothing ->
                    let
                        ( newState, list ) =
                            Force.tick model.simulation <| List.map .label <| Graph.nodes model.graph
                    in
                    ( { model
                        | graph = updateGraphWithList model.graph list
                        , simulation = newState
                      }
                    , Cmd.none
                    )

                Just { current, index } ->
                    let
                        draggedNodePos =
                            model.graph
                                |> Graph.get index
                                |> Maybe.Extra.unwrap current (\x -> ( x.node.label.x, x.node.label.y ))

                        ( newState, list ) =
                            Force.tick model.simulation <| List.map .label <| Graph.nodes model.graph
                    in
                    ( { model
                        | graph =
                            Graph.update index
                                (Maybe.map (updateNode draggedNodePos))
                                (updateGraphWithList model.graph list)
                        , simulation = newState
                      }
                    , Cmd.none
                    )

        DragStart index xy ->
            let
                pos =
                    Graph.get index model.graph
                        |> Maybe.Extra.unwrap ( 0, 0 ) (\x -> ( x.node.label.x, x.node.label.y ))
            in
            ( { model | drag = Just (Drag xy xy index) }, Cmd.none )

        DragAt xy ->
            case model.drag of
                Just { start, index } ->
                    let
                        ( deltax, deltay ) =
                            ( Tuple.first xy - Tuple.first start, Tuple.second xy - Tuple.second start )

                        newPos =
                            Graph.get index model.graph
                                |> Maybe.Extra.unwrap ( deltax, deltay ) (\x -> ( x.node.label.x + deltax, x.node.label.y + deltay ))
                    in
                    ( { model
                        | drag = Just (Drag xy xy index)
                        , graph = Graph.update index (Maybe.map (updateNode newPos)) model.graph
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( { model | drag = Nothing }, Cmd.none )

        DragEnd xy ->
            case model.drag of
                Just { start, index } ->
                    let
                        ( deltax, deltay ) =
                            ( Tuple.first xy - Tuple.first start, Tuple.second xy - Tuple.second start )

                        newPos =
                            Graph.get index model.graph
                                |> Maybe.Extra.unwrap ( deltax, deltay ) (\x -> ( x.node.label.x + deltax, x.node.label.y + deltay ))
                    in
                    ( { model
                        | drag = Nothing
                        , graph = Graph.update index (Maybe.map (updateNode newPos)) model.graph
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( { model | drag = Nothing }, Cmd.none )


updateGraphWithList : Graph Entity () -> List Entity -> Graph Entity ()
updateGraphWithList =
    let
        graphUpdater value =
            Maybe.map (\ctx -> updateContextWithValue ctx value)
    in
    List.foldr (\node graph -> Graph.update node.id (graphUpdater node) graph)


updateNode : ( Float, Float ) -> NodeContext Entity () -> NodeContext Entity ()
updateNode ( x, y ) nodeCtx =
    let
        nodeValue =
            nodeCtx.node.label
    in
    updateContextWithValue nodeCtx { nodeValue | x = x, y = y }


updateContextWithValue : NodeContext Entity () -> Entity -> NodeContext Entity ()
updateContextWithValue nodeCtx value =
    let
        node =
            nodeCtx.node
    in
    { nodeCtx | node = { node | label = value } }


updateShowNode : Model -> Int -> ( Model, Cmd Msg )
updateShowNode model index =
    let
        node =
            model.graph
                |> Graph.get index
                |> Maybe.Extra.unwrap Nothing (\n -> Dict.get n.node.label.value model.nodes)

        cmd =
            case node of
                Just (ArticleNode a) ->
                    getTagsForArticle Dict.empty a ArticleSelectedResult

                _ ->
                    Cmd.none
    in
    ( { model | showNode = node }, cmd )


articleSearchResult : Model -> List Article -> ( Model, Cmd Msg )
articleSearchResult model articlesFound =
    let
        nextId =
            model.nodes |> Dict.keys |> List.length

        newTags : List Tag
        newTags =
            articlesFound
                |> List.foldl (\a b -> a.tags ++ b) []
                |> List.foldl (\t dict -> Dict.insert t.id t dict) Dict.empty
                |> Dict.values
                |> List.filter (\x -> not <| Dict.member x.id model.nodes)
                |> List.indexedMap (\idx x -> { id = x.id, index = idx + nextId, tag = x.tag })

        nodesWithNewTags : Nodes
        nodesWithNewTags =
            List.foldl (\tag dict -> Dict.insert tag.id (TagNode tag) dict) model.nodes newTags

        getTagFromNode : Node -> Maybe Tag
        getTagFromNode n =
            case n of
                TagNode t ->
                    Just t

                ArticleNode _ ->
                    Nothing

        updateTags tags =
            tags
                |> List.map (\t -> Dict.get t.id nodesWithNewTags)
                |> Maybe.Extra.values
                |> List.map (\node -> getTagFromNode node)
                |> Maybe.Extra.values

        newArticles =
            articlesFound
                |> List.filter (\x -> not <| Dict.member x.id model.nodes)
                |> List.foldl (\x dict -> Dict.insert x.id x dict) Dict.empty
                |> Dict.values
                |> List.indexedMap
                    (\idx article ->
                        { article | index = idx + nextId + List.length newTags }
                    )

        nodesWithNewArticles : Nodes
        nodesWithNewArticles =
            List.foldl (\article dict -> Dict.insert article.id (ArticleNode article) dict) nodesWithNewTags newArticles

        updatedNodes : Nodes
        updatedNodes =
            Dict.values nodesWithNewArticles
                |> List.map
                    (\node ->
                        case node of
                            TagNode n ->
                                ( n.id, TagNode n )

                            ArticleNode a ->
                                let
                                    tags =
                                        (articlesFound
                                            |> List.filter (\x -> x.id == a.id)
                                            |> List.map (\x -> x.tags)
                                            |> List.foldl (\xs ys -> xs ++ ys) a.tags
                                        )
                                            |> List.Extra.uniqueBy (\x -> x.id)
                                in
                                ( a.id, ArticleNode { a | tags = updateTags tags } )
                    )
                |> Dict.fromList

        link { from, to } =
            ( from, to )

        graph =
            buildGraph updatedNodes

        forces =
            [ Force.center (w / 2) (h / 2)
            , Force.customLinks 1 <|
                List.map (\x -> { source = x.from, target = x.to, distance = 150, strength = Just 0.2 }) <|
                    Graph.edges graph
            , Force.manyBodyStrength 0.7 <| List.map .id <| Graph.nodes graph
            ]

        newModel =
            { model
                | nodes = updatedNodes
                , simulation = Force.simulation forces
                , graph = graph
            }
    in
    case model.showNode of
        Just x ->
            ( newModel, Cmd.none )

        Nothing ->
            updateShowNode newModel 0


type alias BuildGraphTemp a =
    { idx : Int, id : Id, value : a }


buildGraph : Nodes -> Graph Entity ()
buildGraph nodes =
    let
        stringList : List String
        stringList =
            nodes
                |> Dict.values
                |> List.map
                    (\n ->
                        case n of
                            TagNode x ->
                                ( x.index, x.id )

                            ArticleNode x ->
                                ( x.index, x.id )
                    )
                |> List.sortBy Tuple.first
                |> List.map Tuple.second

        nodegraph : List ( NodeId, NodeId )
        nodegraph =
            nodes
                |> Dict.values
                |> List.map
                    (\n ->
                        case n of
                            TagNode x ->
                                []

                            ArticleNode x ->
                                let
                                    xs : List Tag
                                    xs =
                                        x.tags
                                in
                                xs
                                    |> List.map
                                        (\t ->
                                            ( x.index, t.index )
                                        )
                    )
                |> List.foldl (\a b -> a ++ b) []
    in
    Graph.fromNodeLabelsAndEdgePairs stringList nodegraph
        |> Graph.mapContexts initializeNode



{----}


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

        doTag : ( String, Tag ) -> List ParsedText -> List ParsedText
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


showNode : Model -> Node -> Html Msg
showNode model node =
    case node of
        TagNode n ->
            div []
                [ span [ style "font-weight" "bold" ] [ text "Tag:" ]
                , p [] []
                , span [] [ text n.tag ]
                ]

        ArticleNode article ->
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
                            TagNode y ->
                                y.tag

                            ArticleNode y ->
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
                            TagNode _ ->
                                ( Color.green, Color.darkGreen, Color.black )

                            ArticleNode _ ->
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
        [ svg [ viewBox 0 0 w h ]
            (edges :: nodes)
        ]



{----}


getAllTags : Cmd Msg
getAllTags =
    let
        allTagsDecoder : Decoder (List Tag)
        allTagsDecoder =
            Decode.list (field "tag" tagDecoder)
    in
    HttpBuilder.get "/api/tags"
        |> withHeader "Content-Type" "application/json"
        |> withExpectJson allTagsDecoder
        -- |> withTimeout (10 * Time.second)
        |> send AllTags


search : Model -> Cmd Msg
search model =
    let
        tag =
            if model.tagFilter == "" then
                Nothing

            else
                Just ( "tagFilter", model.tagFilter )

        article =
            if model.articleFilter == "" then
                Nothing

            else
                Just ( "articleFilter", model.articleFilter )
    in
    HttpBuilder.get "/api/articles"
        |> withHeader "Content-Type" "application/json"
        |> withQueryParams (Maybe.Extra.values [ tag, article ])
        |> withExpectJson searchResultDecoder
        -- |> withTimeout (10 * Time.second)
        |> send ArticleSearchResult


getArticlesWithTag : Tag -> Cmd Msg
getArticlesWithTag tag =
    --TODO: as with getTagsForArticle,
    HttpBuilder.get ("/api/tags/" ++ tag.id ++ "/articles")
        |> withHeader "Content-Type" "application/json"
        |> withExpectJson searchResultDecoder
        -- |> withTimeout (10 * Time.second)
        |> send ArticleSearchResult


getTagsForArticle : Nodes -> Article -> (Result Http.Error (List Article) -> Msg) -> Cmd Msg
getTagsForArticle nodes article msg =
    let
        include =
            Dict.values nodes
                |> List.map
                    (\x ->
                        case x of
                            TagNode _ ->
                                Nothing

                            ArticleNode a ->
                                Just a.id
                    )
                |> Maybe.Extra.values
    in
    --
    HttpBuilder.get ("/api/articles/" ++ article.id ++ "/tags")
        |> withHeader "Content-Type" "application/json"
        |> withQueryParams [ ( "includeArticles", String.join "," include ) ]
        |> withExpectJson searchResultDecoder
        -- |> withTimeout (10 * Time.second)
        |> send msg


searchResultDecoder : Decoder (List Article)
searchResultDecoder =
    let
        f : Article -> Decoder Article
        f a =
            field "tag" tagDecoder
                |> Decode.map
                    (\t ->
                        { a | tags = [ t ] }
                    )
    in
    Decode.list
        (field "article" articleDecoder
            |> Decode.andThen (\a -> f a)
        )


tagListDecoder : Decoder (List Tag)
tagListDecoder =
    Decode.list tagDecoder


tagDecoder : Decoder Tag
tagDecoder =
    let
        ctor : String -> String -> Tag
        ctor id tag =
            { id = id, index = -1, tag = tag }
    in
    Decode.succeed ctor
        |> required "id" string
        |> required "tag" string


articleListDecoder : Decoder (List Article)
articleListDecoder =
    Decode.list articleDecoder


articleDecoder : Decoder Article
articleDecoder =
    let
        ctor : String -> String -> String -> String -> List Tag -> Article
        ctor id date title text tags =
            { id = id, index = -1, date = date, title = title, text = text, tags = tags }
    in
    Decode.succeed ctor
        |> required "id" string
        |> required "date" string
        |> required "title" string
        |> required "text" string
        |> optional "tags" tagListDecoder []
