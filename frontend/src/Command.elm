module Command exposing
    ( getAllTags
    , getArticlesWithTag
    , getTagsForArticle
    , getUser
    , search
    )

import Dict
import Http
import HttpBuilder exposing (request, withExpect, withHeader)
import Json.Decode as Decode exposing (Decoder, field, string)
import Maybe.Extra
import Model exposing (Article, Model, Msg(..), Node(..), Nodes, Tag, TextType(..))
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
            Decode.list (field "tag" Model.tagDecoder)
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
    UrlBuilder.relative
        [ "api", "articles", article.id, "tags" ]
        [ UrlBuilder.string "includeArticles" (String.join "," include) ]
        |> HttpBuilder.get
        --("/api/articles/" ++ article.id ++ "/tags")
        |> withHeader "Content-Type" "application/json"
        |> withExpect (Http.expectJson msg (Model.searchResultDecoder model))
        -- |> withTimeout (10 * Time.second)
        |> request
        
--|> withQueryParams [ ( "includeArticles", String.join "," include ) ]


createTag : Model -> Cmd Msg
createTag =
    let
        tagName =
            if model.createTag.tagName == "" then
                Nothing

            else
                Just ( "tagName", model.createTag.tagName )
    in
    HttpBuilder.get "/api/tags/create"
        |> withQueryParams [ ( "tagName", tagName ) ]
        -- |> withHeader "Content-Type" "application/json"
        -- |> withExpect (Http.expectString GotText)
        -- |> withTimeout (10 * Time.second)
        |> request
