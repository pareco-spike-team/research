module TagEdit.TagEdit exposing
    ( Action(..)
    , Msg(..)
    , State
    , empty
    , getActions
    , getArticle
    , init
    , update
    , view
    )

import ColorTheme exposing (currentTheme)
import Html exposing (Html, button, div, h1, h2, input, p, span, text)
import Html.Attributes exposing (class, id, placeholder, style, title, type_, value)
import Html.Events
    exposing
        ( onClick
        , onDoubleClick
        , onInput
        , onMouseDown
        , onSubmit
        )
import Model.Article exposing (Article)
import Model.Tag exposing (Tag)
import TagFinder exposing (PossibleTag(..))
import Util.FontAwesome as FA
import Util.LightBox as LightBox


type Msg
    = AddNewSuggestion String
    | EditSuggestion String String
    | RemoveSuggested String
    | DeleteThis Tag
    | DeleteAll Tag
    | AddThis String
    | AddAll String
    | UndoAction Action
    | OnCancel
    | OnSave


type State
    = State TagModel


type alias TagModel =
    { article : Article
    , possibleTags : List PossibleTag
    , actions : List Action
    }


type Action
    = AddThis_ String
    | AddAll_ String
    | DeleteThis_ Tag
    | DeleteAll_ Tag


empty : State
empty =
    State
        { article = { id = "", date = "1984-09-20", title = "Elite", text = "", tags = [], parsedText = [] }
        , possibleTags = []
        , actions = []
        }


init : Article -> State
init article =
    let
        possibleTags =
            TagFinder.find article
    in
    State
        { article = article
        , possibleTags = possibleTags
        , actions = []
        }


getActions : State -> List Action
getActions (State model) =
    model.actions


getArticle : State -> Article
getArticle (State model) =
    model.article


update : Msg -> State -> ( State, Cmd msg )
update msg (State model) =
    case msg of
        AddNewSuggestion s ->
            ( State { model | possibleTags = model.possibleTags ++ [ PossibleTag s ] }, Cmd.none )

        EditSuggestion existing edit ->
            let
                possibleTags =
                    List.map
                        (\(PossibleTag x) ->
                            if x == existing then
                                PossibleTag edit

                            else
                                PossibleTag x
                        )
                        model.possibleTags
            in
            ( State { model | possibleTags = possibleTags }, Cmd.none )

        RemoveSuggested tag ->
            let
                possibleTags =
                    List.filter
                        (\(PossibleTag x) -> x /= tag)
                        model.possibleTags
            in
            ( State { model | possibleTags = possibleTags }, Cmd.none )

        DeleteThis tag ->
            deleteTag DeleteThis_ model tag

        DeleteAll tag ->
            deleteTag DeleteAll_ model tag

        AddThis tag ->
            addTag AddThis_ model tag

        AddAll tag ->
            addTag AddAll_ model tag

        UndoAction action ->
            let
                actions =
                    List.filter
                        (\x -> x /= action)
                        model.actions
            in
            undoActions model actions [ action ]

        OnCancel ->
            undoActions model [] model.actions

        OnSave ->
            ( State model, Cmd.none )


undoActions : TagModel -> List Action -> List Action -> ( State, Cmd msg )
undoActions model actionsToKeep undoActions_ =
    let
        article =
            model.article

        ( possibleTags, tags ) =
            List.foldl
                (\action ( xs, ys ) ->
                    case action of
                        AddThis_ tag ->
                            ( PossibleTag tag :: xs, ys )

                        AddAll_ tag ->
                            ( PossibleTag tag :: xs, ys )

                        DeleteThis_ tag ->
                            ( xs, tag :: ys )

                        DeleteAll_ tag ->
                            ( xs, tag :: ys )
                )
                ( model.possibleTags, article.tags )
                undoActions_
    in
    ( State
        { model
            | actions = actionsToKeep
            , possibleTags = possibleTags
            , article = { article | tags = tags }
        }
    , Cmd.none
    )


deleteTag : (Tag -> Action) -> TagModel -> Tag -> ( State, Cmd msg )
deleteTag action model tag =
    let
        article =
            model.article

        tags =
            List.filter
                (\t -> t.tag /= tag.tag)
                article.tags
    in
    ( State
        { model
            | article = { article | tags = tags }
            , actions = action tag :: model.actions
        }
    , Cmd.none
    )


addTag : (String -> Action) -> TagModel -> String -> ( State, Cmd msg )
addTag action model tag =
    let
        possibleTags =
            List.filter
                (\(PossibleTag x) -> x /= tag)
                model.possibleTags
    in
    ( State
        { model
            | possibleTags = possibleTags
            , actions = action tag :: model.actions
        }
    , Cmd.none
    )


view : (Msg -> msg) -> State -> Html msg
view tagger (State model) =
    let
        tags =
            List.map .tag model.article.tags
    in
    div
        [ class "tagedit-container" ]
        [ h1 [ style "font-weight" "bold" ]
            [ div [ style "color" currentTheme.text.text ] [ text "Tag edit" ]
            ]
        , div [ class "tagedit-container-edit" ]
            [ div [ class "tagedit-tags-container" ]
                [ h2 [] [ text "Existing Tags" ]
                , div
                    [ class "tagedit-tags" ]
                    (model.article.tags
                        |> List.map
                            (\tag ->
                                div [ class "tagedit-tag-row" ]
                                    [ div
                                        [ class "tagedit-tag" ]
                                        [ input [ type_ "text", class "tagedit-input", value tag.tag ] [] ]
                                    , div [ class "tagedit-buttons" ]
                                        [ button [ class "button", onClick (DeleteThis tag) ]
                                            [ text "Delete this" ]
                                        , button
                                            [ class "button button-danger", onClick (DeleteAll tag) ]
                                            [ text "Delete all" ]
                                        ]
                                    ]
                            )
                    )
                ]
            , div [ class "tagedit-tags-container" ]
                [ h2 [] [ text "Suggested Tags" ]
                , div
                    [ class "tagedit-tags" ]
                    ((model.possibleTags
                        |> List.map
                            (\(PossibleTag pt) ->
                                div [ class "tagedit-tag-row" ]
                                    [ div
                                        [ class "tagedit-tag" ]
                                        [ input
                                            [ type_ "text"
                                            , class "tagedit-input"
                                            , value pt
                                            , onInput (EditSuggestion pt)
                                            ]
                                            []
                                        ]
                                    , div [ class "tagedit-buttons" ]
                                        [ button
                                            [ class "button", title "Add on this article only", onClick (AddThis pt) ]
                                            [ text "Add this" ]
                                        , button
                                            [ class "button", title "Add on all articles with this phrase", onClick (AddAll pt) ]
                                            [ text "Add all" ]
                                        , button
                                            [ class "button", title "Remove this suggestion", onClick (RemoveSuggested pt) ]
                                            [ text "Remove" ]
                                        ]
                                    ]
                            )
                     )
                        ++ [ div [ class "tagedit-tag-row" ]
                                [ div
                                    [ class "tagedit-tag" ]
                                    [ input
                                        [ type_ "text"
                                        , class "tagedit-input"
                                        , value ""
                                        , placeholder "Add tag"
                                        , onInput AddNewSuggestion
                                        ]
                                        []
                                    ]
                                ]
                           ]
                    )
                ]
            , div [ class "tagedit-tags-container" ]
                [ h2 [] [ text "Tag Changes" ]
                , div
                    [ class "tagedit-tags" ]
                    (model.actions
                        |> List.map
                            (\action ->
                                let
                                    undo =
                                        span [ class "tagedit-buttons" ]
                                            [ button [ class "button", onClick (UndoAction action) ]
                                                [ text "Undo" ]
                                            ]
                                in
                                div [ class "tagedit-tag-row" ]
                                    [ case action of
                                        AddThis_ tag ->
                                            div [ style "display" "flex" ]
                                                [ div
                                                    [ class "tagedit-tag" ]
                                                    [ text tag ]
                                                , div
                                                    [ title "Add tag to this article" ]
                                                    [ FA.render "icon icon-green" FA.AddOne ]
                                                , undo
                                                ]

                                        AddAll_ tag ->
                                            div [ style "display" "flex" ]
                                                [ div
                                                    [ class "tagedit-tag" ]
                                                    [ text tag ]
                                                , div
                                                    [ title "Add tag to all matching articles" ]
                                                    [ FA.render "icon icon-green" FA.AddMany ]
                                                , undo
                                                ]

                                        DeleteThis_ tag ->
                                            div [ style "display" "flex" ]
                                                [ div
                                                    [ class "tagedit-tag" ]
                                                    [ text tag.tag ]
                                                , div
                                                    [ title "Remove tag from this article" ]
                                                    [ FA.render "icon icon-red" FA.DeleteOne ]
                                                , undo
                                                ]

                                        DeleteAll_ tag ->
                                            div [ style "display" "flex" ]
                                                [ div
                                                    [ class "tagedit-tag" ]
                                                    [ text tag.tag ]
                                                , div
                                                    [ title "Remove tag from all articles" ]
                                                    [ FA.render "icon icon-red" FA.DeleteMany ]
                                                , undo
                                                ]
                                    ]
                            )
                    )
                ]
            ]
        , div
            [ class "button-row" ]
            [ button [ class "button", onClick OnCancel ] [ text "Cancel" ]
            , button [ class "button", onClick OnSave ] [ text "Save" ]
            ]
        ]
        |> Html.map tagger
