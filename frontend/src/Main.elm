module Main exposing (init, main)

import Browser
import Browser.Dom
import Browser.Events
import Command
import Html.Events.Extra.Mouse as Mouse
import Json.Decode as Decode
import Model exposing (Id, Model, Msg(..))
import Simulation
import Task
import Update exposing (update)
import Util.RemoteData as RemoteData exposing (RemoteData(..))
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
            { viewState = Model.Empty
            , user = RemoteData.InFlight
            , searchFilter = { tagFilter = "", articleFilter = "" }
            , allTags = []
            , simulation =
                Simulation.init ( 400.0, 400.0 )
                    |> Simulation.withMaxIterations 500
                    |> Simulation.withNodes []
            , window = { width = 1900, height = 1000 }
            }
    in
    ( model
    , Cmd.batch
        [ Task.perform Model.GotViewport Browser.Dom.getViewport
        , Command.getUser
        ]
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        events =
            case model.viewState of
                Model.Empty ->
                    []

                Model.TimeLine nodeData ->
                    []

                Model.Nodes nodeData ->
                    if Simulation.isCompleted model.simulation then
                        []

                    else
                        [ Browser.Events.onAnimationFrame Tick ]

                Model.DragNode { drag, nodeData } ->
                    [ Browser.Events.onMouseMove (Decode.map (.clientPos >> DragAt) Mouse.eventDecoder)
                    , Browser.Events.onMouseUp (Decode.map (.clientPos >> DragEnd) Mouse.eventDecoder)
                    , Browser.Events.onAnimationFrame Tick
                    ]

        resizeEvent : Sub Msg
        resizeEvent =
            Browser.Events.onResize (\x y -> Model.ResizeWindow ( x, y ))
    in
    Sub.batch (resizeEvent :: events)


type alias BuildGraphTemp a =
    { idx : Int
    , id : Id
    , value : a
    }
