module Model exposing (Article, Drag, Id, Index, MenuMsg(..), Model, Msg(..), Node(..), NodeData, Nodes, ParsedText, SearchFilter, Tag, TextType(..), TimeLineData, ViewState(..), WindowSize, getNodeId)

import Browser.Dom exposing (Viewport)
import Dict exposing (Dict)
import Http
import Simulation
import Time


type Msg
    = ResizeWindow ( Int, Int )
    | GotViewport Viewport
    | ArticleSearchResult (Result Http.Error (List Article))
    | ArticleSelectedResult (Result Http.Error (List Article))
    | AllTags (Result Http.Error (List Tag))
    | TagFilterInput String
    | SubmitSearch
    | ClearAll
    | GetRelated Id
    | ShowNode Id
    | ToggleShowMenu
    | DragStart Id ( Float, Float )
    | DragAt ( Float, Float )
    | DragEnd ( Float, Float )
    | Tick Time.Posix
    | SwitchToTimeLineView
    | SwitchToNodesView
    | MenuMsg MenuMsg


type MenuMsg
    = Unlock Id
    | Remove Id
    | RemoveConnected Id
    | RemoveNotConnected Id
    | ConnectTo Id


type alias Model =
    { viewState : ViewState
    , allTags : List Tag
    , searchFilter : SearchFilter
    , simulation : Simulation.Simulation String
    , window : WindowSize
    }


type ViewState
    = Empty
    | Nodes NodeData
    | TimeLine TimeLineData
    | DragNode { drag : Drag, nodeData : NodeData }


type alias SearchFilter =
    { tagFilter : String, articleFilter : String }


type alias NodeData =
    { nodes : Nodes, selectedNode : Node, showMenu : Bool }


type alias TimeLineData =
    { nodes : Nodes, selectedNode : Node }


type alias WindowSize =
    { width : Float, height : Float }


type alias Drag =
    { start : ( Float, Float )
    , current : ( Float, Float )
    , id : Id
    }


type alias Id =
    String


type alias Base a =
    { a | id : Id }


type alias Tag =
    Base { tag : String }


type alias Article =
    Base
        { date : String
        , title : String
        , text : String
        , tags : List Tag
        , parsedText : List ParsedText
        }


type Node
    = ArticleNode Article
    | TagNode Tag


getNodeId : Node -> Id
getNodeId n =
    case n of
        ArticleNode x ->
            x.id

        TagNode x ->
            x.id


type alias Nodes =
    Dict Id Node


type alias Index =
    Int


type alias ParsedText =
    ( Index, String, TextType )


type TextType
    = TypeText
    | TypeTag
    | NewLine
