module Util.ColorPicker exposing (view)

import Color exposing (Color)
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Html.Events.Extra.Mouse as Mouse
import Model exposing (ColorToChange(..), Link, Msg(..))


view : Link -> Color -> Html Msg
view link currentColor =
    let
        theColor =
            Color.toCssString
                currentColor
    in
    div [ class "box-shadow color-picker" ]
        [ div [ class "color-picker-top" ]
            [ div [ class "color-picker-colorbox", style "background-color" theColor ] []
            ]
        , div
            [ class "color-picker-colorbar color-picker-colorbar-red"
            , Mouse.onClick (\evt -> ColourPaletteChangeColor (Tuple.first evt.offsetPos) Red)
            ]
            [ text "" ]
        , div
            [ class "color-picker-colorbar color-picker-colorbar-green"
            , Mouse.onClick (\evt -> ColourPaletteChangeColor (Tuple.first evt.offsetPos) Green)
            ]
            [ text "" ]
        , div
            [ class "color-picker-colorbar color-picker-colorbar-blue"
            , Mouse.onClick (\evt -> ColourPaletteChangeColor (Tuple.first evt.offsetPos) Blue)
            ]
            [ text "" ]
        , div [ class "color-picker-bottom" ]
            [ button [ class "button", onClick ToggleMenu ] [ text "Cancel" ]
            , button [ class "button", onClick (SetLinkColor link currentColor) ] [ text "Pick" ]
            ]
        ]
