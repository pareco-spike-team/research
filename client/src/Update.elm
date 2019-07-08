module Update exposing (getAllTags, update)

import Dict exposing (Dict)
import Http
import HttpBuilder exposing (..)
import Json.Decode as Decode exposing (Decoder, field, maybe, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import List.Extra
import Maybe.Extra
import Model exposing (Article, Drag, Model, Msg(..), Node(..), Nodes, ParsedText, Tag, TextType(..))
import Simulation exposing (Simulation)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotViewport vp ->
            ( { model
                | window = vp.scene
                , simulation = Simulation.setCenter ( 0.35 * vp.scene.width, 0.35 * vp.scene.height ) model.simulation
              }
            , Cmd.none
            )

        ResizeWindow ( x, y ) ->
            ( { model
                | window = { width = toFloat x, height = toFloat y }
                , simulation = Simulation.setCenter ( 0.35 * toFloat x, 0.35 * toFloat y ) model.simulation
              }
            , Cmd.none
            )

        TagFilterInput s ->
            ( { model | tagFilter = s, articleFilter = s }, Cmd.none )

        SubmitSearch ->
            ( model, search model )

        ClearAll ->
            ( { model
                | nodes = Dict.empty
                , selectedNode = Model.NoneSelected
                , tagFilter = ""
                , articleFilter = ""
                , simulation = Simulation.clear model.simulation
              }
            , Cmd.none
            )

        AllTags (Ok tags) ->
            ( { model | allTags = tags }, Cmd.none )

        AllTags (Err e) ->
            let
                _ =
                    Debug.log "fail" e
            in
            ( model, Cmd.none )

        ArticleSearchResult (Ok articles) ->
            articleSearchResult model articles

        ArticleSearchResult (Err e) ->
            let
                _ =
                    Debug.log "fail" e
            in
            ( model, Cmd.none )

        ArticleSelectedResult (Ok articles) ->
            let
                articleId =
                    case model.selectedNode of
                        Model.Selected (ArticleNode x) ->
                            x.id

                        Model.Selected (TagNode x) ->
                            x.id

                        Model.NoneSelected ->
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
                        |> Maybe.Extra.unwrap model.selectedNode Model.Selected
            in
            ( { model | selectedNode = theArticle }, Cmd.none )

        ArticleSelectedResult (Err e) ->
            let
                _ =
                    Debug.log "fail" e
            in
            ( model, Cmd.none )

        GetRelated id ->
            let
                node =
                    Dict.get id model.nodes
            in
            case node of
                Nothing ->
                    ( model, Cmd.none )

                Just (TagNode x) ->
                    ( model, getArticlesWithTag model x )

                Just (ArticleNode x) ->
                    ( model, getTagsForArticle model model.nodes x ArticleSearchResult )

        ShowNode id ->
            updateShowNode model id

        Tick t ->
            case model.viewMode of
                Model.TimeLine ->
                    ( model, Cmd.none )

                Model.Nodes ->
                    ( { model | simulation = Simulation.tick model.simulation }
                    , Cmd.none
                    )

        DragStart id xy ->
            let
                newSim =
                    Simulation.lockPosition id model.simulation
            in
            ( { model | drag = Just (Drag xy xy id), simulation = newSim }, Cmd.none )

        DragAt xy ->
            case model.drag of
                Just { start, id } ->
                    let
                        ( deltax, deltay ) =
                            ( Tuple.first xy - Tuple.first start, Tuple.second xy - Tuple.second start )

                        sim =
                            Simulation.node id model.simulation
                                |> Maybe.Extra.unwrap model.simulation
                                    (\node ->
                                        Simulation.movePosition id ( node.x + deltax, node.y + deltay ) model.simulation
                                    )
                    in
                    ( { model | drag = Just (Drag xy xy id), simulation = sim }, Cmd.none )

                Nothing ->
                    ( { model | drag = Nothing }, Cmd.none )

        DragEnd xy ->
            case model.drag of
                Just { start, id } ->
                    let
                        ( deltax, deltay ) =
                            ( Tuple.first xy - Tuple.first start, Tuple.second xy - Tuple.second start )

                        sim =
                            Simulation.node id model.simulation
                                |> Maybe.Extra.unwrap model.simulation
                                    (\node ->
                                        Simulation.movePosition id ( node.x + deltax, node.y + deltay ) model.simulation
                                    )
                    in
                    ( { model | drag = Nothing, simulation = sim }, Cmd.none )

                Nothing ->
                    ( { model | drag = Nothing }, Cmd.none )

        SwitchToTimeLineView ->
            ( { model | viewMode = Model.TimeLine }, Cmd.none )

        SwitchToNodesView ->
            ( { model | viewMode = Model.Nodes }, Cmd.none )


updateShowNode : Model -> Model.Id -> ( Model, Cmd Msg )
updateShowNode model id =
    let
        node =
            Maybe.Extra.or
                (Dict.get id model.nodes)
                (Dict.values model.nodes |> List.head)
                |> Maybe.Extra.unwrap Model.NoneSelected (\x -> Model.Selected x)

        cmd =
            case node of
                Model.Selected (ArticleNode x) ->
                    getTagsForArticle model Dict.empty x ArticleSelectedResult

                Model.Selected (TagNode x) ->
                    Cmd.none

                Model.NoneSelected ->
                    Cmd.none
    in
    ( { model | selectedNode = node }, cmd )


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
        |> withExpectJson (searchResultDecoder model)
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
            updatedNodes
                |> buildGraph
                |> List.foldl
                    (\node sim -> Simulation.add node sim)
                    model.simulation

        newModel =
            { model | nodes = updatedNodes, simulation = graph }

        showDefault =
            newTags
                |> List.head
                |> Maybe.Extra.unwrap ""
                    (\x -> x.id)
    in
    case model.selectedNode of
        Model.Selected _ ->
            ( newModel, Cmd.none )

        Model.NoneSelected ->
            updateShowNode newModel showDefault


searchResultDecoder : Model -> Decoder (List Article)
searchResultDecoder model =
    let
        f : Article -> Decoder Article
        f a =
            field "tags" tagListDecoder
                |> Decode.map
                    (\tags ->
                        { a | tags = tags }
                    )
    in
    Decode.list
        (field "article" (articleDecoder model)
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


articleDecoder : Model -> Decoder Article
articleDecoder model =
    let
        ctor : String -> String -> String -> String -> List Tag -> Article
        ctor id date title text tags =
            let
                a =
                    { id = id
                    , index = -1
                    , date = date
                    , title = title
                    , text = text
                    , tags = tags
                    , parsedText = []
                    }
            in
            { a | parsedText = parseText model a }
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


getArticlesWithTag : Model -> Tag -> Cmd Msg
getArticlesWithTag model tag =
    --TODO: as with getTagsForArticle,
    HttpBuilder.get ("/api/tags/" ++ tag.id ++ "/articles")
        |> withHeader "Content-Type" "application/json"
        |> withExpectJson (searchResultDecoder model)
        -- |> withTimeout (10 * Time.second)
        |> send ArticleSearchResult


getTagsForArticle : Model -> Nodes -> Article -> (Result Http.Error (List Article) -> Msg) -> Cmd Msg
getTagsForArticle model nodes article msg =
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
        |> withExpectJson (searchResultDecoder model)
        -- |> withTimeout (10 * Time.second)
        |> send msg


buildGraph : Nodes -> List ( Model.Id, List Model.Id )
buildGraph nodes =
    nodes
        |> Dict.toList
        |> List.map
            (\( id, node ) ->
                case node of
                    TagNode x ->
                        ( id, [] )

                    ArticleNode x ->
                        ( id, x.tags |> List.map (\t -> t.id) )
            )



{----}
{----}


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
                alphabet =
                    "abcdefghijklmnopqrstuvwxyz"

                parts : List ( Int, String, TextType )
                parts =
                    String.indexes strTag lowerCaseText
                        |> List.map (\idx -> ( idx, tag.tag, TypeTag ))
                        |> List.filter
                            (\( idx, tag_, typeTag ) ->
                                let
                                    leftSlice =
                                        String.slice (idx - 1) idx lowerCaseText

                                    len =
                                        String.length tag_

                                    rightSlice =
                                        String.slice (idx + len) (idx + len + 1) lowerCaseText
                                in
                                not
                                    (String.contains leftSlice alphabet
                                        || String.contains rightSlice alphabet
                                    )
                            )
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
    if List.length parsed == 0 then
        [ ( 0, article.text, TypeText ) ]

    else
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
