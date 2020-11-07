module Model exposing
    ( ColorToChange(..)
    , Drag
    , Link
    , MenuMsg(..)
    , Model
    , Msg(..)
    , Node(..)
    , NodeData
    , NodeViewState(..)
    , Nodes
    , SearchFilter
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
import Color exposing (Color)
import Dict exposing (Dict)
import Http
import Json.Decode as JD exposing (Decoder, at, fail, field, int, list, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, optional, required, requiredAt)
import Maybe.Extra
import Model.Article exposing (Article)
import Model.Base exposing (Base, Id)
import Model.ParsedText exposing (ParsedText, TextType(..))
import Model.Tag exposing (Tag)
import Simulation
import TagEdit.TagEdit as TagEdit
import Time
import Util.RemoteData exposing (RemoteData(..))


type Msg
    = ResizeWindow ( Int, Int )
    | GotViewport Viewport
    | ArticleSearchResult (Result Http.Error (List Node))
    | ArticleSelectedResult (Result Http.Error (List Node))
    | AllTags (Result Http.Error (List Tag))
    | GotUser (Result Http.Error User)
    | TagFilterInput String
    | SubmitSearch
    | ClearAll
    | GetRelated Id
    | ShowNode Id
    | ToggleMenu
    | ShowAndToggleMenu Id
    | DragStart Id ( Float, Float )
    | DragAt ( Float, Float )
    | DragEnd ( Float, Float )
    | Tick Time.Posix
    | SwitchToTimeLineView
    | SwitchToNodesView
    | MenuMsg MenuMsg
    | ShowColourPalette
    | ColourPaletteChangeColor Float ColorToChange
    | SetLinkColor Link Color
    | RemoveLinkColor Link
    | NoOp
    | OpenTagEditor Article
    | TagEditTagger TagEdit.Msg
    | TagEditSaved (Result Http.Error (List Node))


type alias TODO =
    ()


type alias ModifiedTag =
    TODO


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
    , tagEditState : TagEdit.State
    }


type ViewState
    = Empty
    | Nodes NodeData
    | TimeLine TimeLineData
    | DragNode { drag : Drag, nodeData : NodeData }
    | EditTags ViewState Node


type alias SearchFilter =
    { tagFilter : String
    , articleFilter : String
    }


type alias CreateTag =
    { tagName : String
    }


type alias NodeData =
    { nodes : Nodes
    , selectedNode : Node
    , nodeViewState : NodeViewState
    }


type alias TimeLineData =
    { nodes : Nodes
    , selectedNode : Node
    }


type NodeViewState
    = Default
    | ShowMenu
    | ShowColorPalette Color.Color


type ColorToChange
    = Red
    | Green
    | Blue


type alias WindowSize =
    { width : Float
    , height : Float
    }


type alias Drag =
    { start : ( Float, Float )
    , current : ( Float, Float )
    , id : Id
    }


colorDecoder : Decoder (Maybe Color.Color)
colorDecoder =
    list int
        |> JD.andThen
            (\res ->
                case res of
                    [ r, g, b ] ->
                        succeed (Just (Color.rgb255 r g b))

                    _ ->
                        JD.fail "Color needs array to contain 3 elements"
            )


tagDecoder : Decoder Tag
tagDecoder =
    let
        ctor : String -> String -> Tag
        ctor id tag =
            { id = id
            , tag = tag
            }
    in
    succeed ctor
        |> required "id" string
        |> required "tag" string


articleDecoder : Model -> Decoder Article
articleDecoder model =
    let
        ctor : String -> String -> String -> String -> Article
        ctor id date title text =
            let
                a =
                    { id = id
                    , date = date
                    , title = title
                    , text = text
                    , tags = []
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


type alias Link =
    { from : Id
    , to : Id
    , color : Maybe Color.Color
    }


linkDecoder : Decoder Link
linkDecoder =
    succeed Link
        |> requiredAt [ "_meta", "from" ] string
        |> requiredAt [ "_meta", "to" ] string
        |> optional "color" colorDecoder Nothing


type Node
    = ArticleNode Article
    | TagNode Tag
    | LinkNode Link


nodeDecoder : Model -> Decoder Node
nodeDecoder model =
    let
        metaDecoder : Decoder ( String, String )
        metaDecoder =
            JD.map2
                (\type_ label ->
                    ( type_, label )
                )
                (at [ "_meta", "type" ] string)
                (at [ "_meta", "label" ] string)
    in
    metaDecoder
        |> JD.andThen
            (\( type_, label ) ->
                case ( type_, label ) of
                    ( "Label", "Article" ) ->
                        articleDecoder model |> JD.map ArticleNode

                    ( "Label", "Tag" ) ->
                        tagDecoder |> JD.map TagNode

                    ( "Tag", "Link" ) ->
                        linkDecoder |> JD.map LinkNode

                    _ ->
                        JD.fail ("Unknown case (" ++ type_ ++ ", " ++ label ++ ").")
            )


searchResultDecoder : Model -> Decoder (List Node)
searchResultDecoder model =
    list (nodeDecoder model)
        |> JD.map
            (\nodes ->
                let
                    tags =
                        nodes
                            |> List.map
                                (\node ->
                                    case node of
                                        TagNode t ->
                                            Just ( t.id, t )

                                        ArticleNode _ ->
                                            Nothing

                                        LinkNode _ ->
                                            Nothing
                                )
                            |> Maybe.Extra.values
                            |> Dict.fromList

                    links =
                        nodes
                            |> List.map
                                (\node ->
                                    case node of
                                        LinkNode x ->
                                            Just x

                                        TagNode _ ->
                                            Nothing

                                        ArticleNode _ ->
                                            Nothing
                                )
                            |> Maybe.Extra.values

                    addTags article =
                        links
                            |> List.filter (\link -> link.from == article.id)
                            |> List.map (\link -> Dict.get link.to tags)
                            |> Maybe.Extra.values
                            |> (\xs -> { article | tags = xs })
                in
                nodes
                    |> List.map
                        (\node ->
                            case node of
                                ArticleNode x ->
                                    addTags x |> ArticleNode

                                TagNode _ ->
                                    node

                                LinkNode _ ->
                                    node
                        )
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


getNodeId : Node -> Id
getNodeId n =
    case n of
        ArticleNode x ->
            x.id

        TagNode x ->
            x.id

        LinkNode x ->
            x.from ++ "->" ++ x.to


type alias Nodes =
    Dict Id Node


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
