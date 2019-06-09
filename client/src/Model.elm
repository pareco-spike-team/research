module Model exposing (Article, Drag, Id, Index, Model, Msg(..), Node(..), Nodes, ParsedText, SelectedNode(..), Tag, TextType(..), WindowSize)

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
    | DragStart Id ( Float, Float )
    | DragAt ( Float, Float )
    | DragEnd ( Float, Float )
    | Tick Time.Posix


type alias Model =
    { nodes : Nodes
    , selectedNode : SelectedNode
    , allTags : List Tag
    , tagFilter : String
    , articleFilter : String
    , drag : Maybe Drag
    , simulation : Simulation.Simulation String
    , window : WindowSize
    }


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
    { a | id : String, index : Int }


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


type SelectedNode
    = NoneSelected
    | Selected Node


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
