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
            ( { model | searchFilter = { tagFilter = s, articleFilter = s } }, Cmd.none )

        SubmitSearch ->
            ( model, search model )

        ClearAll ->
            ( { model
                | viewState = Model.Empty
                , searchFilter = { tagFilter = "", articleFilter = "" }
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
                doUpdate nodeData =
                    case nodeData.selectedNode of
                        ArticleNode article ->
                            articles
                                |> List.filter (\x -> x.id == article.id)
                                |> List.foldl
                                    (\x acc -> { x | tags = x.tags ++ acc.tags })
                                    article
                                |> (\x -> { x | tags = List.Extra.uniqueBy (\t -> t.id) x.tags })
                                |> ArticleNode
                                |> (\x -> { nodeData | selectedNode = x })

                        TagNode x ->
                            nodeData
            in
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine x ->
                    ( { model | viewState = Model.TimeLine (doUpdate x) }, Cmd.none )

                Model.Nodes x ->
                    ( { model | viewState = Model.Nodes (doUpdate x) }, Cmd.none )

                Model.DragNode { drag, nodeData } ->
                    ( { model | viewState = Model.DragNode { drag = drag, nodeData = doUpdate nodeData } }, Cmd.none )

        ArticleSelectedResult (Err e) ->
            let
                _ =
                    Debug.log "fail" e
            in
            ( model, Cmd.none )

        GetRelated id ->
            let
                getRelated viewState =
                    case Dict.get id viewState.nodes of
                        Nothing ->
                            ( model, Cmd.none )

                        Just (TagNode x) ->
                            ( model, getArticlesWithTag model x )

                        Just (ArticleNode x) ->
                            ( model, getTagsForArticle model viewState.nodes x ArticleSearchResult )
            in
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine nodeData ->
                    getRelated nodeData

                Model.Nodes nodeData ->
                    getRelated { nodeData | showMenu = False }

                Model.DragNode { nodeData } ->
                    getRelated nodeData

        ShowNode id ->
            updateShowNode model id

        ToggleShowMenu ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine nodeData ->
                    ( model, Cmd.none )

                Model.Nodes nodeData ->
                    ( { model | viewState = Model.Nodes { nodeData | showMenu = not nodeData.showMenu } }, Cmd.none )

                Model.DragNode { nodeData } ->
                    ( model, Cmd.none )

        Tick t ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine _ ->
                    ( model, Cmd.none )

                Model.Nodes nodeData ->
                    ( { model | simulation = Simulation.tick model.simulation }
                    , Cmd.none
                    )

                Model.DragNode d ->
                    ( { model | simulation = Simulation.tick model.simulation }
                    , Cmd.none
                    )

        DragStart id xy ->
            let
                newSim =
                    Simulation.lockPosition id model.simulation
            in
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine { nodes, selectedNode } ->
                    ( { model | simulation = newSim, viewState = Model.DragNode { drag = Drag xy xy id, nodeData = { nodes = nodes, selectedNode = selectedNode, showMenu = False } } }, Cmd.none )

                Model.Nodes x ->
                    ( { model
                        | simulation = newSim
                        , viewState = Model.DragNode { drag = Drag xy xy id, nodeData = x }
                      }
                    , Cmd.none
                    )

                Model.DragNode x ->
                    ( { model | simulation = newSim, viewState = Model.DragNode { drag = Drag xy xy id, nodeData = x.nodeData } }, Cmd.none )

        DragAt xy ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine x ->
                    ( model, Cmd.none )

                Model.Nodes x ->
                    ( model, Cmd.none )

                Model.DragNode x ->
                    let
                        ( deltax, deltay ) =
                            ( Tuple.first xy - Tuple.first x.drag.start, Tuple.second xy - Tuple.second x.drag.start )

                        sim =
                            Simulation.node x.drag.id model.simulation
                                |> Maybe.Extra.unwrap model.simulation
                                    (\node ->
                                        Simulation.movePosition x.drag.id ( node.x + deltax, node.y + deltay ) model.simulation
                                    )

                        nodeData =
                            x.nodeData
                                |> (\nodeData_ -> { nodeData_ | showMenu = False })
                    in
                    ( { model | viewState = Model.DragNode { drag = Drag xy xy x.drag.id, nodeData = nodeData }, simulation = sim }, Cmd.none )

        DragEnd xy ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine x ->
                    ( model, Cmd.none )

                Model.Nodes x ->
                    ( model, Cmd.none )

                Model.DragNode x ->
                    let
                        ( deltax, deltay ) =
                            ( Tuple.first xy - Tuple.first x.drag.start, Tuple.second xy - Tuple.second x.drag.start )

                        sim =
                            Simulation.node x.drag.id model.simulation
                                |> Maybe.Extra.unwrap model.simulation
                                    (\node ->
                                        Simulation.movePosition x.drag.id ( node.x + deltax, node.y + deltay ) model.simulation
                                    )

                        viewState =
                            x.nodeData
                                -- |> (\nodeData -> { nodeData | showMenu = True })
                                |> Model.Nodes
                    in
                    ( { model | viewState = viewState, simulation = sim }, Cmd.none )

        SwitchToTimeLineView ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine x ->
                    ( model, Cmd.none )

                Model.Nodes { nodes, selectedNode } ->
                    ( { model | viewState = Model.TimeLine { nodes = nodes, selectedNode = selectedNode } }, Cmd.none )

                Model.DragNode { drag, nodeData } ->
                    ( { model | viewState = Model.TimeLine { nodes = nodeData.nodes, selectedNode = nodeData.selectedNode } }, Cmd.none )

        SwitchToNodesView ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine { nodes, selectedNode } ->
                    ( { model | viewState = Model.Nodes { nodes = nodes, selectedNode = selectedNode, showMenu = False } }, Cmd.none )

                Model.Nodes x ->
                    ( model, Cmd.none )

                Model.DragNode x ->
                    ( { model | viewState = Model.Nodes x.nodeData }, Cmd.none )

        MenuMsg menuMsg ->
            updateMenuMsg model menuMsg


updateMenuMsg : Model -> Model.MenuMsg -> ( Model, Cmd Msg )
updateMenuMsg model msg =
    case msg of
        Model.Unlock id ->
            let
                newSim =
                    Simulation.unlockAll model.simulation

                newViewState =
                    case model.viewState of
                        Model.Empty ->
                            model.viewState

                        Model.Nodes nodeData ->
                            Model.Nodes { nodeData | showMenu = False }

                        Model.TimeLine _ ->
                            model.viewState

                        Model.DragNode _ ->
                            model.viewState
            in
            ( { model | simulation = newSim, viewState = newViewState }, Cmd.none )

        Model.Remove id ->
            let
                sim =
                    Simulation.remove id model.simulation

                viewState =
                    removeNode id model.viewState
            in
            ( { model | simulation = sim }, Cmd.none )

        Model.RemoveConnected id ->
            ( model, Cmd.none )

        Model.RemoveNotConnected id ->
            ( model, Cmd.none )

        Model.ConnectTo id ->
            ( model, Cmd.none )


removeNode : Model.Id -> Model.ViewState -> Model.ViewState
removeNode id state =
    case state of
        Model.Empty ->
            state

        Model.TimeLine _ ->
            state

        Model.DragNode _ ->
            state

        Model.Nodes data ->
            let
                nodes =
                    data.nodes
                        |> Dict.filter (\key _ -> key /= id)
                        |> Dict.map
                            (\_ v ->
                                case v of
                                    TagNode t ->
                                        v

                                    ArticleNode a ->
                                        ArticleNode { a | tags = a.tags |> List.filter (\x -> x.id /= id) }
                            )

                selectedNode =
                    if id == Model.getNodeId data.selectedNode then
                        nodes
                            |> Dict.values
                            |> List.head

                    else
                        Just data.selectedNode
            in
            Maybe.Extra.unwrap
                Model.Empty
                (\selected ->
                    Model.Nodes { data | nodes = nodes, selectedNode = selected, showMenu = False }
                )
                selectedNode


updateShowNode : Model -> Model.Id -> ( Model, Cmd Msg )
updateShowNode model id =
    let
        getNode nodes =
            Maybe.Extra.or
                (Dict.get id nodes)
                (Dict.values nodes |> List.head)

        cmd node =
            case node of
                ArticleNode x ->
                    getTagsForArticle model Dict.empty x ArticleSelectedResult

                TagNode x ->
                    Cmd.none

        doUpdate : { a | nodes : Model.Nodes, selectedNode : Model.Node } -> ({ a | nodes : Model.Nodes, selectedNode : Model.Node } -> Model.ViewState) -> ( Model, Cmd Msg )
        doUpdate nodeData f =
            nodeData.nodes
                |> getNode
                |> Maybe.Extra.unwrap
                    ( model, Cmd.none )
                    (\n ->
                        ( { model | viewState = f { nodeData | selectedNode = n } }, cmd n )
                    )
    in
    case model.viewState of
        Model.Empty ->
            ( model, Cmd.none )

        Model.TimeLine x ->
            doUpdate x Model.TimeLine

        Model.Nodes x ->
            doUpdate { x | showMenu = False } Model.Nodes

        Model.DragNode { drag, nodeData } ->
            doUpdate nodeData (\x -> Model.DragNode { drag = drag, nodeData = x })


search : Model -> Cmd Msg
search model =
    let
        tag =
            if model.searchFilter.tagFilter == "" then
                Nothing

            else
                Just ( "tagFilter", model.searchFilter.tagFilter )

        article =
            if model.searchFilter.articleFilter == "" then
                Nothing

            else
                Just ( "articleFilter", model.searchFilter.articleFilter )
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
        nodes =
            case model.viewState of
                Model.Empty ->
                    Dict.empty

                Model.TimeLine nodeData ->
                    nodeData.nodes

                Model.Nodes nodeData ->
                    nodeData.nodes

                Model.DragNode { nodeData } ->
                    nodeData.nodes

        newTags : List Tag
        newTags =
            articlesFound
                |> List.foldl (\a b -> a.tags ++ b) []
                |> List.foldl (\t dict -> Dict.insert t.id t dict) Dict.empty
                |> Dict.values
                |> List.filter (\x -> not <| Dict.member x.id nodes)

        nodesWithNewTags : Nodes
        nodesWithNewTags =
            List.foldl (\tag dict -> Dict.insert tag.id (TagNode tag) dict) nodes newTags

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
                |> List.filter (\x -> not <| Dict.member x.id nodes)
                |> List.foldl (\x dict -> Dict.insert x.id x dict) Dict.empty
                |> Dict.values

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

        showDefault =
            newTags
                |> List.head
                |> Maybe.Extra.unwrap { id = "dummy", tag = "dummy" } identity
    in
    case model.viewState of
        Model.Empty ->
            updateShowNode
                { model | simulation = graph, viewState = Model.Nodes { nodes = updatedNodes, selectedNode = TagNode showDefault, showMenu = False } }
                showDefault.id

        Model.TimeLine nodeData ->
            updateShowNode
                { model | simulation = graph, viewState = Model.TimeLine { nodes = updatedNodes, selectedNode = nodeData.selectedNode } }
                (Model.getNodeId nodeData.selectedNode)

        Model.Nodes nodeData ->
            updateShowNode
                { model | simulation = graph, viewState = Model.Nodes { nodes = updatedNodes, selectedNode = nodeData.selectedNode, showMenu = False } }
                (Model.getNodeId nodeData.selectedNode)

        Model.DragNode { drag, nodeData } ->
            let
                newNodeData =
                    { nodeData | nodes = updatedNodes }
            in
            updateShowNode
                { model | simulation = graph, viewState = Model.DragNode { drag = drag, nodeData = newNodeData } }
                (Model.getNodeId nodeData.selectedNode)


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
            { id = id, tag = tag }
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
