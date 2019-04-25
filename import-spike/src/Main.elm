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
import TypedSvg.Attributes exposing (class, color, fill, stroke, textAnchor, viewBox)
import TypedSvg.Attributes.InEm as InEm
import TypedSvg.Attributes.InPx as InPx exposing (cx, cy, r, strokeWidth, x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute, Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Fill(..))


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
    { tags : Tags
    , articles : Articles
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


type alias Tag =
    { id : String
    , tag : String
    }


type alias Articles =
    Dict Id Article


type alias Article =
    { id : String
    , date : String
    , title : String
    , text : String
    , tags : List Tag
    }


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
            { tags = Dict.empty
            , articles = Dict.empty
            , tagFilter = "Duradrive"
            , articleFilter = ""
            , drag = Nothing
            , simulation = Force.simulation []
            , graph =
                buildGraph { tags = Dict.empty, articles = Dict.empty }
            }
    in
    ( model, search model )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.drag of
        Nothing ->
            -- This allows us to save resources, as if the simulation is done, there is no point in subscribing
            -- to the rAF.
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
        tags : Tags
        tags =
            articlesFound
                |> List.foldl (\a b -> a.tags ++ b) []
                |> List.map (\x -> ( x.id, x ))
                |> Dict.fromList
                |> Dict.union model.tags

        updateTags : List Tag -> List Tag
        updateTags xs =
            xs |> List.map (\t -> Dict.get t.id model.tags |> Maybe.withDefault t)

        updateArticleDictionary : Article -> Dict Id Article -> Dict Id Article
        updateArticleDictionary x dict =
            Dict.update
                x.id
                (\existing ->
                    case existing of
                        Nothing ->
                            { x | tags = updateTags x.tags }
                                |> Just

                        Just e ->
                            { e | tags = updateTags e.tags }
                                |> Just
                )
                dict

        articles =
            articlesFound
                |> List.foldl updateArticleDictionary model.articles

        link { from, to } =
            ( from, to )

        graph =
            buildGraph { tags = tags, articles = articles }

        forces =
            [ Force.links <| List.map link <| Graph.edges graph
            , Force.manyBody <| List.map .id <| Graph.nodes graph
            , Force.center (w / 2) (h / 2)
            ]
    in
    ( { model
        | tags = tags
        , articles = articles
        , simulation = Force.simulation forces
        , graph = graph
      }
    , Cmd.none
    )


type alias BuildGraphTemp a =
    { idx : Int, id : Id, value : a }


buildGraph : { a | tags : Tags, articles : Articles } -> Graph Entity ()
buildGraph { tags, articles } =
    let
        _ =
            Debug.log "_tags_" tags

        _ =
            Debug.log "_articles_" articles

        toTemp : Int -> Id -> b -> BuildGraphTemp b
        toTemp idx id value =
            { idx = idx, id = id, value = value }

        tags_ =
            Dict.values tags
                |> List.indexedMap (\idx x -> ( x.id, toTemp idx x.id x ))
                |> Dict.fromList

        tagsLength =
            tags_ |> Dict.keys |> List.length

        articles_ =
            Dict.values articles
                |> List.indexedMap (\idx x -> ( x.id, toTemp (tagsLength + idx) x.id x ))
                |> Dict.fromList

        stringList : List String
        stringList =
            (tags_ |> Dict.values |> List.map .id) ++ (articles_ |> Dict.values |> List.map .id)

        nodegraph : List ( NodeId, NodeId )
        nodegraph =
            articles_
                |> Dict.values
                |> List.map
                    (\a ->
                        let
                            xs : List Tag
                            xs =
                                a.value.tags
                        in
                        xs
                            |> List.map
                                (\t ->
                                    let
                                        idx =
                                            Dict.get t.id tags_ |> Maybe.Extra.unwrap -1 (\x -> x.idx)
                                    in
                                    ( a.idx, idx )
                                )
                    )
                |> List.foldl (\a b -> a ++ b) []

        _ =
            Debug.log "_stringList_" stringList

        _ =
            Debug.log "_nodegraph_" nodegraph
    in
    Graph.fromNodeLabelsAndEdgePairs stringList nodegraph
        |> Graph.mapContexts initializeNode
        |> Debug.log "__graph__"



{----}


view : Model -> Html Msg
view model =
    div [ style "padding" "0.5em 0.5em", style "background-color" "#D2D5DA" ]
        [ searchBox model
        , drawGraph model
        ]


searchBox : Model -> Html Msg
searchBox model =
    div [ style "display" "flex", style "flex-direction" "row" ]
        [ div
            [ style "flex-grow" "1", style "background-color" "#FFFFFF" ]
            [ form [ onSubmit SubmitSearch ]
                [ input [ type_ "search", placeholder "type search query", autofocus True, value model.tagFilter, onInput TagFilterInput ] []
                , input [ type_ "submit" ] [ text "Search" ]
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


nodeElement node =
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
        [ InEm.fontSize 0.55
        , InPx.x node.label.x
        , InPx.y node.label.y
        , textAnchor AnchorMiddle
        , stroke (Color.rgba 0.9 0.9 0.92 0.9)
        ]
        [ text node.label.value ]
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
                |> List.map nodeElement
                |> List.map (g [ class [ "nodes" ] ])
    in
    svg [ viewBox 0 0 w h ]
        (edges :: nodes)



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
    Decode.succeed Tag
        |> required "id" string
        |> required "tag" string


articleListDecoder : Decoder (List Article)
articleListDecoder =
    Decode.list articleDecoder


articleDecoder : Decoder Article
articleDecoder =
    Decode.succeed Article
        |> required "id" string
        |> required "date" string
        |> required "title" string
        |> required "text" string
        |> optional "tags" tagListDecoder []
