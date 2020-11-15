module Util.Spinner exposing (spinner, spinnerWithDelay)

--import Svg exposing (..)
--import Svg.Attributes exposing (..)

import Html exposing (..)
import Html.Attributes exposing (class, classList)
import TypedSvg as Svg exposing (svg, use)
import TypedSvg.Attributes as SvgAttr
import TypedSvg.Attributes.InPx as InPx
import Util.FontAwesome as FA


spinner : Html msg
spinner =
    spinner_ False


spinnerWithDelay : Html msg
spinnerWithDelay =
    spinner_ True


spinner_ : Bool -> Html msg
spinner_ withDelay =
    div
        [ class "spinner-on-top" ]
        [ div
            [ classList [ ( "spinner", True ), ( "spinner--delayed", withDelay ) ] ]
            [ FA.render "icon" FA.Spinner ]
        ]
