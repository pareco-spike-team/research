module Model exposing
    ( Article
    , Drag
    , Id
    , Index
    , MenuMsg(..)
    , Model
    , Msg(..)
    , Node(..)
    , NodeData
    , Nodes
    , ParsedText
    , SearchFilter
    , Tag
    , TextType(..)
    , TimeLineData
    , ViewState(..)
    , WindowSize
    , articleDecoder
    , getNodeId
    , searchResultDecoder
    , tagDecoder
    , tagListDecoder
    , userDecoder
    )

import Browser.Dom exposing (Viewport)
import Dict exposing (Dict)
import Http
import Json.Decode as JD exposing (Decoder, fail, field, list, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Simulation
import Time
import Util.RemoteData exposing (RemoteData(..))


type Msg
    = ResizeWindow ( Int, Int )
    | GotViewport Viewport
    | ArticleSearchResult (Result Http.Error (List Article))
    | ArticleSelectedResult (Result Http.Error (List Article))
    | AllTags (Result Http.Error (List Tag))
    | GotUser (Result Http.Error User)
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
    , user : RemoteData User
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
    { tagFilter : String
    , articleFilter : String
    }


type alias NodeData =
    { nodes : Nodes
    , selectedNode : Node
    , showMenu : Bool
    }


type alias TimeLineData =
    { nodes : Nodes
    , selectedNode : Node
    }


type alias WindowSize =
    { width : Float
    , height : Float
    }


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


tagDecoder : Decoder Tag
tagDecoder =
    let
        ctor : String -> String -> Tag
        ctor id tag =
            { id = id, tag = tag }
    in
    succeed ctor
        |> required "id" string
        |> required "tag" string


type alias Article =
    Base
        { date : String
        , title : String
        , text : String
        , tags : List Tag
        , parsedText : List ParsedText
        }


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
    succeed ctor
        |> required "id" string
        |> required "date" string
        |> required "title" string
        |> required "text" string
        |> optional "tags" tagListDecoder []


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


type Email
    = Verified String
    | NotVerified String


type Group
    = ReadOnlyUser
    | User_
    | Admin
    | SuperAdmin


groupDecoder : Decoder Group
groupDecoder =
    string
        |> JD.andThen
            (\grp ->
                case String.toLower grp of
                    "readonlyuser" ->
                        succeed ReadOnlyUser

                    "user" ->
                        succeed User_

                    "admin" ->
                        succeed Admin

                    "superadmin" ->
                        succeed SuperAdmin

                    _ ->
                        fail ("Could not decode Group. No group translates to string '" ++ grp ++ "'")
            )


type alias User =
    { nickname : String
    , givenName : String
    , familyName : String
    , email : Email
    , groups : List Group
    }


userDecoder : Decoder User
userDecoder =
    JD.map2
        (\email verified ->
            if verified == "true" then
                Verified email

            else
                NotVerified email
        )
        (field "Email" string)
        (field "EmailVerified" string)
        |> JD.andThen
            (\email ->
                succeed User
                    |> required "Nickname" string
                    |> required "GivenName" string
                    |> required "FamilyName" string
                    |> hardcoded email
                    |> required "groups" (list groupDecoder)
            )


searchResultDecoder : Model -> Decoder (List Article)
searchResultDecoder model =
    let
        f : Article -> Decoder Article
        f a =
            field "tags" tagListDecoder
                |> JD.map
                    (\tags ->
                        { a | tags = tags }
                    )
    in
    list
        (field "article" (articleDecoder model)
            |> JD.andThen (\a -> f a)
        )


tagListDecoder : Decoder (List Tag)
tagListDecoder =
    list tagDecoder


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
