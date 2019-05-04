module Model exposing (Article, Drag, Entity, Id, Model, Msg(..), Node(..), Nodes, Tag, height, width)

import Dict exposing (Dict)
import Force
import Graph exposing (Graph, NodeId)
import Http
import Time


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


width : Float
width =
    1200


height : Float
height =
    900


type alias Drag =
    { start : ( Float, Float )
    , current : ( Float, Float )
    , index : NodeId
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
        }


type Node
    = ArticleNode Article
    | TagNode Tag


type alias Nodes =
    Dict Id Node


type alias Entity =
    Force.Entity NodeId { value : String }
