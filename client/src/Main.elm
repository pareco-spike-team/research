module Main exposing (init, main)

import Browser
import Browser.Events
import Dict exposing (Dict)
import Html.Events.Extra.Mouse as Mouse
import Json.Decode as Decode
import Model exposing (Id, Model, Msg(..))
import Simulation
import Update exposing (getAllTags, update)
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
            , selectedNode = Model.NoneSelected
            , allTags = []
            , tagFilter = ""
            , articleFilter = ""
            , drag = Nothing
            , simulation =
                Simulation.init ( 400.0, 400.0 )
                    |> Simulation.withMaxIterations 500
                    |> Simulation.withNodes []
            }
    in
    ( model, Cmd.batch [ getAllTags ] )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.drag of
        Nothing ->
            if Simulation.isCompleted model.simulation then
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
