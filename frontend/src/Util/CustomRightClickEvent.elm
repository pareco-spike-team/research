module Util.CustomRightClickEvent exposing (onRightClick)

import Html exposing (Attribute)
import Html.Events
import Json.Decode as JD


mouseClickDecoder : JD.Decoder ()
mouseClickDecoder =
    JD.field "button" JD.int
        |> JD.andThen
            (\button ->
                if button /= 2 then
                    JD.fail "ignore"

                else
                    JD.succeed ()
            )


onRightClick : msg -> Attribute msg
onRightClick msg =
    Html.Events.on "mousedown" (JD.map (\_ -> msg) mouseClickDecoder)
