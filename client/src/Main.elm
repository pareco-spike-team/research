module Main exposing (init, main)

import Browser
import Browser.Events
import Dict exposing (Dict)
import Force
import Html.Events.Extra.Mouse as Mouse
import Json.Decode as Decode
import Model exposing (Id, Model, Msg(..))
import Update exposing (buildGraph, getAllTags, update)
import View exposing (view)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        model : Model
        model =
            { nodes = Dict.empty
            , showNode = Nothing
            , allTags = []
            , tagFilter = ""
            , articleFilter = ""
            , drag = Nothing
            , simulation = Force.simulation []
            , graph = buildGraph Dict.empty
            }
    in
    ( model, Cmd.batch [ getAllTags ] )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.drag of
        Nothing ->
            if Force.isCompleted model.simulation then
                Sub.none

            else
                Browser.Events.onAnimationFrame Tick

        Just _ ->
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map (.clientPos >> DragAt) Mouse.eventDecoder)
                , Browser.Events.onMouseUp (Decode.map (.clientPos >> DragEnd) Mouse.eventDecoder)
                , Browser.Events.onAnimationFrame Tick
                ]


type alias BuildGraphTemp a =
    { idx : Int, id : Id, value : a }
