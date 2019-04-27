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
import Html.Events exposing (onInput, onMouseDown, onSubmit)
import Html.Events.Extra.Mouse as Mouse
import Http
import HttpBuilder exposing (..)
import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Decode.Pipeline exposing (optional, required)
import Maybe.Extra
import Time
import TypedSvg exposing (circle, g, line, rect, svg, text_, title)
import TypedSvg.Attributes exposing (class, color, fill, fontFamily, lengthAdjust, stroke, textAnchor, viewBox)
import TypedSvg.Attributes.InEm as InEm
import TypedSvg.Attributes.InPx as InPx exposing (cx, cy, r, strokeWidth, x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute, Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Fill(..), LengthAdjust(..))


w : Float
w =
    1200


h : Float
h =
    900


type Msg
    = ArticleSearchResult (Result Http.Error (List Article))
    | TagFilterInput String
    | SubmitSearch
    | DragStart NodeId ( Float, Float )
    | DragAt ( Float, Float )
    | DragEnd ( Float, Float )
    | Tick Time.Posix


type alias Model =
    { nodes : Nodes
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
            , tagFilter = "Duradrive"
            , articleFilter = ""
            , drag = Nothing
            , simulation = Force.simulation []
            , graph = buildGraph Dict.empty
            }
    in
    ( model, search model )


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

        ArticleSearchResult (Ok articles) ->
            articleSearchResult model articles

        ArticleSearchResult (Err e) ->
            ( model, Cmd.none )

        Tick t ->
            let
                ( newState, list_ ) =
                    Force.tick model.simulation <| List.map .label <| Graph.nodes model.graph

                fixNan : Float -> Float
                fixNan x =
                    if isNaN x then
                        h / 2

                    else
                        x

                list =
                    list_
                        |> List.map
                            (\x ->
                                { x | vx = fixNan x.vx, vy = fixNan x.vy, x = fixNan x.x, y = fixNan x.y }
                            )
            in
            case model.drag of
                Nothing ->
                    ( { model
                        | graph = updateGraphWithList model.graph list
                        , simulation = newState
                      }
                    , Cmd.none
                    )

                Just { current, index } ->
                    ( { model
                        | graph =
                            Graph.update index
                                (Maybe.map (updateNode current))
                                (updateGraphWithList model.graph list)
                        , simulation = newState
                      }
                    , Cmd.none
                    )

        DragStart index xy ->
            ( { model | drag = Just (Drag xy xy index) }, Cmd.none )

        DragAt xy ->
            case model.drag of
                Just { start, index } ->
                    ( { model
                        | drag = Just (Drag xy xy index)
                        , graph = Graph.update index (Maybe.map (updateNode xy)) model.graph
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( { model | drag = Nothing }, Cmd.none )

        DragEnd xy ->
            case model.drag of
                Just { start, index } ->
                    ( { model
                        | drag = Nothing
                        , graph = Graph.update index (Maybe.map (updateNode xy)) model.graph
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
                                ( a.id, ArticleNode { a | tags = updateTags a.tags } )
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

        _ =
            Debug.log "nextId" nextId
                |> (\_ -> Debug.log "newTags" newTags)
                |> (\_ -> Debug.log "nodesWithNewTags" nodesWithNewTags)
                |> (\_ -> Debug.log "newArticles" newArticles)
                |> (\_ -> Debug.log "nodesWithNewArticles" nodesWithNewArticles)
                |> (\_ -> Debug.log "updatedNodes" updatedNodes)
    in
    ( { model
        | nodes = updatedNodes
        , simulation = Force.simulation forces
        , graph = graph
      }
    , Cmd.none
    )


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
        , drawGraph model
        ]


searchBox : Model -> Html Msg
searchBox model =
    let
        {--
select:focus {
outline: none;
}
    --}
        inputStyle =
            [ ( "padding", "0.5em" ), ( "line-height", "4em" ), ( "border", "0" ), ( "border-radius", "5px" ) ]
                |> List.map (\( a, b ) -> style a b)
    in
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
                , style "padding" "0.5em"
                ]
                [ div
                    [ style "display" "flex"
                    , style "flex-direction" "row"
                    , style "background-color" "white"
                    , style "border-radius" "5px"
                    ]
                    [ span inputStyle [ text " $" ]
                    , input
                        ([ type_ "search"
                         , placeholder "type search query"
                         , autofocus True
                         , value model.tagFilter
                         , onInput TagFilterInput
                         , style "border" "0"
                         , style "flex-grow" "1"
                         ]
                            ++ inputStyle
                        )
                        []
                    ]
                ]
            , div
                [ style "padding" "0.5em"
                , style "line-height" "4em"
                ]
                [ input [ type_ "submit", style "border" "0", value "Search" ] []
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
        txt =
            Dict.get node.label.value nodes
                |> Maybe.Extra.unwrap node.label.value
                    (\x ->
                        case x of
                            TagNode y ->
                                y.tag

                            ArticleNode y ->
                                y.title
                    )
    in
    [ circle
        [ InEm.r 2
        , fill (Fill (Color.rgba 0 0 0.95 1.0))
        , stroke (Color.rgba 0 0 0.8 1.0)
        , strokeWidth 2
        , onMouseDown node
        , cx node.label.x
        , cy node.label.y
        ]
        [ title [] [ text node.label.value ]
        ]
    , text_
        [ InEm.fontSize 0.8
        , fontFamily [ "Helvetica Neue", "Helvetica", "Arial", "sans-serif" ]
        , InPx.x node.label.x
        , InPx.y node.label.y
        , InEm.textLength 3.95
        , lengthAdjust LengthAdjustSpacingAndGlyphs
        , textAnchor AnchorMiddle
        , fill (Fill Color.black)
        , color Color.black
        , stroke (Color.rgba 0.9 0.9 0.92 0.9)
        ]
        [ text txt ]
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
