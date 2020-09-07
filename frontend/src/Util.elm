module Util exposing (delay, httpErrorToString, idDecoder)

import Http exposing (Error(..))
import Json.Decode as Decode
import Process
import Task


idDecoder : (String -> a) -> Decode.Decoder a
idDecoder f =
    Decode.string
        |> Decode.map f


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        BadUrl s ->
            s

        Timeout ->
            "Request timed out"

        NetworkError ->
            "Request failed"

        BadStatus statusCode ->
            "Request failed, server return status code " ++ String.fromInt statusCode

        BadBody body ->
            "Bad body: " ++ body


delay : Float -> msg -> Cmd msg
delay time msg =
    Process.sleep time
        |> Task.andThen (always <| Task.succeed msg)
        |> Task.perform identity
