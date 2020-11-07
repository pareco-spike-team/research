module Command exposing
    ( editTagChanges
    , getAllTags
    , getArticlesWithTag
    , getTagsForArticle
    , getUser
    , removeColorOnLink
    , search
    , setColorOnLink
    )

import Color
import Dict
import Http
import HttpBuilder exposing (request, withExpect, withHeader, withJsonBody)
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE
import Maybe.Extra
import Model exposing (Link, Model, Msg(..), Node(..), Nodes)
import Model.Article exposing (Article)
import Model.Base exposing (Base, Id)
import Model.ParsedText exposing (ParsedText, TextType(..))
import Model.Tag exposing (Tag)
import TagEdit.TagEdit as TagEdit
import Url.Builder as UrlBuilder


getUser : Cmd Msg
getUser =
    HttpBuilder.get "/api/user"
        |> withHeader "Content-Type" "application/json"
        |> withExpect (Http.expectJson GotUser Model.userDecoder)
        -- |> withTimeout (10 * Time.second)
        |> request


getAllTags : Cmd Msg
getAllTags =
    let
        allTagsDecoder : Decoder (List Tag)
        allTagsDecoder =
            JD.list Model.tagDecoder
    in
    HttpBuilder.get "/api/tags"
        |> withHeader "Content-Type" "application/json"
        |> withExpect (Http.expectJson AllTags allTagsDecoder)
        -- |> withTimeout (10 * Time.second)
        |> request


getArticlesWithTag : Model -> Tag -> Cmd Msg
getArticlesWithTag model tag =
    --TODO: as with getTagsForArticle,
    HttpBuilder.get ("/api/tags/" ++ tag.id ++ "/articles")
        |> withHeader "Content-Type" "application/json"
        |> withExpect (Http.expectJson ArticleSearchResult (Model.searchResultDecoder model))
        -- |> withTimeout (10 * Time.second)
        |> request


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
    UrlBuilder.relative
        [ "api", "articles" ]
        (Maybe.Extra.values [ tag, article ]
            |> List.map (\( name, val ) -> UrlBuilder.string name val)
        )
        |> HttpBuilder.get
        |> withHeader "Content-Type" "application/json"
        |> withExpect (Http.expectJson ArticleSearchResult (Model.searchResultDecoder model))
        -- |> withTimeout (10 * Time.second)
        |> request


getTagsForArticle : Model -> Nodes -> Article -> (Result Http.Error (List Node) -> Msg) -> Cmd Msg
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

                            LinkNode _ ->
                                Nothing
                    )
                |> Maybe.Extra.values
    in
    UrlBuilder.relative
        [ "api", "articles", article.id, "tags" ]
        [ UrlBuilder.string "includeArticles" (String.join "," include) ]
        |> HttpBuilder.get
        |> withHeader "Content-Type" "application/json"
        |> withExpect (Http.expectJson msg (Model.searchResultDecoder model))
        -- |> withTimeout (10 * Time.second)
        |> request


setColorOnLink : Model -> Link -> (Result Http.Error (List Node) -> Msg) -> Cmd Msg
setColorOnLink model link msg =
    let
        color : Color.Color -> List Float
        color c =
            c
                |> Color.toRgba
                |> (\{ red, green, blue } -> [ red, green, blue ])

        json =
            JE.object <|
                Maybe.Extra.unwrap
                    []
                    (\c ->
                        [ ( "from", JE.string link.from )
                        , ( "to", JE.string link.to )
                        , ( "color", JE.list JE.float (color c) )
                        ]
                    )
                    link.color
    in
    HttpBuilder.post ("/api/articles/" ++ link.from ++ "/color")
        |> withJsonBody json
        |> withExpect (Http.expectJson msg (Model.searchResultDecoder model))
        |> request


removeColorOnLink : Model -> Link -> (Result Http.Error (List Node) -> Msg) -> Cmd Msg
removeColorOnLink model link msg =
    let
        json =
            JE.object <|
                [ ( "from", JE.string link.from )
                , ( "to", JE.string link.to )
                ]
    in
    HttpBuilder.delete ("/api/articles/" ++ link.from ++ "/color")
        |> withJsonBody json
        |> withExpect (Http.expectJson msg (Model.searchResultDecoder model))
        |> request


editTagChanges : Model -> Article -> List TagEdit.Action -> (Result Http.Error (List Node) -> Msg) -> Cmd Msg
editTagChanges model article actions msg =
    let
        json =
            JE.list
                (\action ->
                    case action of
                        TagEdit.AddThis_ tag ->
                            JE.object
                                [ ( "action", JE.string "add" )
                                , ( "value", JE.string tag )
                                ]

                        TagEdit.AddAll_ tag ->
                            JE.object
                                [ ( "action", JE.string "addAll" )
                                , ( "value", JE.string tag )
                                ]

                        TagEdit.DeleteThis_ tag ->
                            JE.object
                                [ ( "action", JE.string "delete" )
                                , ( "value", JE.string tag.id )
                                ]

                        TagEdit.DeleteAll_ tag ->
                            JE.object
                                [ ( "action", JE.string "deleteAll" )
                                , ( "value", JE.string tag.id )
                                ]
                )
                actions
                |> (\xs -> JE.object [ ( "actions", xs ) ])
    in
    if List.isEmpty actions then
        Cmd.none

    else
        UrlBuilder.relative
            [ "api", "articles", article.id, "tags" ]
            []
            |> HttpBuilder.post
            |> withJsonBody json
            |> withExpect (Http.expectJson msg (Model.searchResultDecoder model))
            -- |> withTimeout (10 * Time.second)
            |> request
