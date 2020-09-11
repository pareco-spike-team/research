module Update exposing (update)

import Command
import Dict
import List.Extra
import Maybe.Extra
import Model exposing (Article, Drag, Model, Msg(..), Node(..), Nodes, Tag, TextType(..))
import Simulation
import Util.RemoteData as RemoteData exposing (RemoteData(..))


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
            ( model, Command.search model )

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

        ArticleSearchResult (Ok nodes) ->
            articleSearchResult model nodes

        ArticleSearchResult (Err e) ->
            let
                _ =
                    Debug.log "fail" e
            in
            ( model, Cmd.none )

        ArticleSelectedResult (Ok nodes) ->
            let
                updateSelected selected =
                    case selected of
                        ArticleNode article ->
                            let
                                tags =
                                    nodes
                                        |> List.map
                                            (\x ->
                                                case x of
                                                    TagNode t ->
                                                        Just t

                                                    ArticleNode _ ->
                                                        Nothing

                                                    LinkNode _ ->
                                                        Nothing
                                            )
                                        |> Maybe.Extra.values

                                addTags node =
                                    case node of
                                        ArticleNode x ->
                                            ArticleNode { x | tags = tags }

                                        TagNode _ ->
                                            node

                                        LinkNode _ ->
                                            node
                            in
                            nodes
                                |> List.Extra.find
                                    (\node_ ->
                                        case node_ of
                                            ArticleNode x ->
                                                x.id == article.id

                                            TagNode _ ->
                                                False

                                            LinkNode _ ->
                                                False
                                    )
                                |> Maybe.Extra.unwrap
                                    selected
                                    addTags

                        TagNode _ ->
                            selected

                        LinkNode _ ->
                            selected
            in
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine timeLine ->
                    ( { model
                        | viewState =
                            Model.TimeLine
                                { timeLine
                                    | selectedNode = updateSelected timeLine.selectedNode
                                }
                      }
                    , Cmd.none
                    )

                Model.Nodes nodes_ ->
                    ( { model
                        | viewState =
                            Model.Nodes
                                { nodes_
                                    | selectedNode = updateSelected nodes_.selectedNode
                                }
                      }
                    , Cmd.none
                    )

                Model.DragNode dragNode ->
                    let
                        nodeData =
                            dragNode.nodeData

                        selected =
                            updateSelected nodeData.selectedNode
                    in
                    ( { model
                        | viewState =
                            Model.DragNode
                                { dragNode
                                    | nodeData =
                                        { nodeData
                                            | selectedNode = selected
                                        }
                                }
                      }
                    , Cmd.none
                    )

        ArticleSelectedResult (Err e) ->
            let
                _ =
                    Debug.log "fail" e
            in
            ( model, Cmd.none )

        GotUser (Ok user) ->
            ( { model | user = RemoteData.Success user }
            , if List.length model.allTags == 0 then
                Command.getAllTags

              else
                Cmd.none
            )

        GotUser (Err e) ->
            let
                _ =
                    Debug.log "fail" e
            in
            ( { model | user = RemoteData.Fail e }, Cmd.none )

        GetRelated id ->
            let
                getRelated viewState =
                    case Dict.get id viewState.nodes of
                        Nothing ->
                            ( model, Cmd.none )

                        Just (LinkNode _) ->
                            ( model, Cmd.none )

                        Just (TagNode x) ->
                            ( model, Command.getArticlesWithTag model x )

                        Just (ArticleNode x) ->
                            ( model, Command.getTagsForArticle model viewState.nodes x ArticleSearchResult )
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

                Model.TimeLine _ ->
                    ( model, Cmd.none )

                Model.Nodes nodeData ->
                    ( { model | viewState = Model.Nodes { nodeData | showMenu = not nodeData.showMenu } }, Cmd.none )

                Model.DragNode _ ->
                    ( model, Cmd.none )

        Tick _ ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine _ ->
                    ( model, Cmd.none )

                Model.Nodes _ ->
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

                Model.TimeLine _ ->
                    ( model, Cmd.none )

                Model.Nodes _ ->
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

                Model.DragNode { nodeData } ->
                    ( { model | viewState = Model.TimeLine { nodes = nodeData.nodes, selectedNode = nodeData.selectedNode } }, Cmd.none )

        SwitchToNodesView ->
            case model.viewState of
                Model.Empty ->
                    ( model, Cmd.none )

                Model.TimeLine { nodes, selectedNode } ->
                    ( { model | viewState = Model.Nodes { nodes = nodes, selectedNode = selectedNode, showMenu = False } }, Cmd.none )

                Model.Nodes _ ->
                    ( model, Cmd.none )

                Model.DragNode x ->
                    ( { model | viewState = Model.Nodes x.nodeData }, Cmd.none )

        MenuMsg menuMsg ->
            updateMenuMsg model menuMsg


updateMenuMsg : Model -> Model.MenuMsg -> ( Model, Cmd Msg )
updateMenuMsg model msg =
    case msg of
        Model.Unlock _ ->
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
            ( { model | simulation = sim, viewState = viewState }, Cmd.none )

        Model.RemoveConnected id ->
            removeConnected model id

        Model.RemoveNotConnected _ ->
            ( model, Cmd.none )

        Model.ConnectTo _ ->
            ( model, Cmd.none )


removeConnected : Model -> Model.Id -> ( Model, Cmd Msg )
removeConnected model id =
    case model.viewState of
        Model.Nodes nodeData ->
            let
                nodesToRemove =
                    nodeData.nodes
                        |> Dict.toList
                        |> List.map
                            (\( key, value ) ->
                                case value of
                                    ArticleNode x ->
                                        if x.id == id then
                                            Just [ x.id ]

                                        else
                                            Nothing

                                    TagNode x ->
                                        if x.id == id then
                                            Just [ x.id ]

                                        else
                                            Nothing

                                    LinkNode x ->
                                        if x.from == id || x.to == id then
                                            Just [ key, x.from, x.to ]

                                        else
                                            Nothing
                            )
                        |> Maybe.Extra.values
                        |> List.concat

                newNodes =
                    nodesToRemove
                        |> List.foldl
                            (\nodeId nodes -> Dict.remove nodeId nodes)
                            nodeData.nodes

                newSim =
                    nodesToRemove
                        |> List.foldl
                            (\nodeId sim -> Simulation.remove nodeId sim)
                            model.simulation
            in
            ( { model
                | simulation = newSim
                , viewState = Model.Nodes { nodeData | nodes = newNodes }
              }
            , Cmd.none
            )

        Model.Empty ->
            ( model, Cmd.none )

        Model.TimeLine _ ->
            ( model, Cmd.none )

        Model.DragNode _ ->
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
                        |> Dict.filter
                            (\key value ->
                                case value of
                                    ArticleNode _ ->
                                        key /= id

                                    TagNode _ ->
                                        key /= id

                                    LinkNode x ->
                                        x.from /= id && x.to /= id
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
                    Command.getTagsForArticle model Dict.empty x ArticleSelectedResult

                TagNode _ ->
                    Cmd.none

                LinkNode _ ->
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


articleSearchResult : Model -> List Node -> ( Model, Cmd Msg )
articleSearchResult model nodesFound =
    let
        updatedNodes_ =
            updateNodes model nodesFound

        graph =
            updatedNodes_
                |> buildGraph
                |> List.foldl
                    (\node sim -> Simulation.add node sim)
                    model.simulation

        showDefault =
            nodesFound
                |> List.head
                |> Maybe.Extra.unwrap (TagNode { id = "dummy", tag = "dummy" }) identity
    in
    case model.viewState of
        Model.Empty ->
            updateShowNode
                { model
                    | simulation = graph
                    , viewState =
                        Model.Nodes
                            { nodes = updatedNodes_
                            , selectedNode = showDefault
                            , showMenu = False
                            }
                }
                (Model.getNodeId showDefault)

        Model.TimeLine nodeData ->
            updateShowNode
                { model | simulation = graph, viewState = Model.TimeLine { nodes = updatedNodes_, selectedNode = nodeData.selectedNode } }
                (Model.getNodeId nodeData.selectedNode)

        Model.Nodes nodeData ->
            updateShowNode
                { model | simulation = graph, viewState = Model.Nodes { nodes = updatedNodes_, selectedNode = nodeData.selectedNode, showMenu = False } }
                (Model.getNodeId nodeData.selectedNode)

        Model.DragNode { drag, nodeData } ->
            let
                newNodeData =
                    { nodeData | nodes = updatedNodes_ }
            in
            updateShowNode
                { model | simulation = graph, viewState = Model.DragNode { drag = drag, nodeData = newNodeData } }
                (Model.getNodeId nodeData.selectedNode)


updateNodes : Model -> List Node -> Nodes
updateNodes model nodesFound =
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
    in
    nodesFound
        |> List.foldl
            (\node dict ->
                let
                    key =
                        case node of
                            ArticleNode x ->
                                x.id

                            TagNode x ->
                                x.id

                            LinkNode x ->
                                x.from ++ "->" ++ x.to
                in
                Dict.insert key node dict
            )
            nodes


buildGraph : Nodes -> List ( Model.Id, List Model.Id )
buildGraph nodes =
    let
        nodeList =
            Dict.toList nodes

        linkNodes =
            nodeList
                |> List.map
                    (\( _, node ) ->
                        case node of
                            LinkNode x ->
                                Just x

                            ArticleNode _ ->
                                Nothing

                            TagNode _ ->
                                Nothing
                    )
                |> Maybe.Extra.values
    in
    nodeList
        |> List.map
            (\( id, node ) ->
                case node of
                    TagNode _ ->
                        Just ( id, [] )

                    ArticleNode x ->
                        let
                            children =
                                linkNodes
                                    |> List.filter
                                        (\l -> l.from == x.id || l.to == x.id)
                                    |> List.map
                                        (\l ->
                                            if l.from == x.id then
                                                Just l.to

                                            else
                                                Just l.from
                                        )
                                    |> Maybe.Extra.values
                        in
                        Just ( id, children )

                    LinkNode _ ->
                        Nothing
            )
        |> Maybe.Extra.values
