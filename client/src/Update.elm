module Update exposing (buildGraph, getAllTags, update)

import Dict exposing (Dict)
import Force
import Graph exposing (Graph, NodeContext, NodeId)
import Http
import HttpBuilder exposing (..)
import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Decode.Pipeline exposing (optional, required)
import List.Extra
import Maybe.Extra
import Model exposing (Article, Drag, Entity, Model, Msg(..), Node(..), Nodes, Tag)


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


updateNode : ( Float, Float ) -> NodeContext Entity () -> NodeContext Entity ()
updateNode ( x, y ) nodeCtx =
    let
        nodeValue =
            nodeCtx.node.label
    in
    updateContextWithValue nodeCtx { nodeValue | x = x, y = y }


updateGraphWithList : Graph Entity () -> List Entity -> Graph Entity ()
updateGraphWithList =
    let
        graphUpdater value =
            Maybe.map (\ctx -> updateContextWithValue ctx value)
    in
    List.foldr (\node graph -> Graph.update node.id (graphUpdater node) graph)


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
            [ Force.center (Model.width / 2) (Model.height / 2)
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


initializeNode : NodeContext String () -> NodeContext Entity ()
initializeNode ctx =
    { node = { id = ctx.node.id, label = Force.entity ctx.node.id ctx.node.label }
    , incoming = ctx.incoming
    , outgoing = ctx.outgoing
    }
