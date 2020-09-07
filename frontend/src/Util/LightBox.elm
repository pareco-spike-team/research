module Util.LightBox exposing (LightBoxStyle(..), view)

import Html exposing (Html, div)
import Html.Attributes exposing (id, style)
import Html.Events exposing (onClick)
import Util.FontAwesome as FA


type LightBoxStyle
    = AlertStyle
    | Normal
    | Wide


cssLightboxOverlay : List (Html.Attribute msg)
cssLightboxOverlay =
    [ ( "transition", "0.1s ease-in opacity" )
    , ( "transition", "0.1s ease-in opacity" )
    , ( "position", "fixed" )
    , ( "top", "0" )
    , ( "right", "0" )
    , ( "bottom", "0" )
    , ( "left", "0" )
    , ( "z-index", "999" )
    , ( "background-color", "fade(#333333, 60%)" )
    , ( "background-image", "data-uri(\"../img/background-striped-transparent.png\")" )
    , ( "background-size", "15px 15px" )
    ]
        |> List.map (\( a, b ) -> style a b)


cssLightBoxContentAlert : List (Html.Attribute msg)
cssLightBoxContentAlert =
    [ ( "width", "90%" )
    , ( "max-width", "900px" )
    ]
        |> List.map (\( a, b ) -> style a b)


cssLightBoxContentWide : List (Html.Attribute msg)
cssLightBoxContentWide =
    [ ( "max-width", "2500px" )
    ]
        |> List.map (\( a, b ) -> style a b)


cssLightBoxContainer : List (Html.Attribute msg)
cssLightBoxContainer =
    [ ( "position", "fixed" )
    , ( "top", "0" )
    , ( "right", "0" )
    , ( "bottom", "0" )
    , ( "left", "0" )
    , ( "overflow", "hidden" )
    , ( "overflow", "y: scroll" )
    , ( "outline", "0" )
    ]
        |> List.map (\( a, b ) -> style a b)


cssLightBoxContent : List (Html.Attribute msg)
cssLightBoxContent =
    [ ( "background-color", "white" )
    , ( "position", "relative" )
    , ( "outline", "0" )
    , ( "width", "90%" )
    , ( "max-width", "1280px" )
    , ( "margin", "6rem auto" )
    ]
        |> List.map (\( a, b ) -> style a b)


cssLightBoxClose : List (Html.Attribute msg)
cssLightBoxClose =
    [ ( "font-size", "2.0rem" )
    , ( "line-height", "4.0rem" )
    , ( "width", "4.0rem" )
    , ( "text-align", "center" )
    , ( "color", "#fff" )
    , ( "position", "absolute" )
    , ( "top", "0" )
    , ( "right", "0" )
    , ( "cursor", "pointer" )
    , ( "z-index", "1" )
    , ( "transition-timing-function", "cubic-bezier(0.775, 0.145, 0.100, 0.905)" )
    , ( "transition-duration", "0.1s" )
    , ( "transition-property", "transform" )

    -- &:hover {
    --     transform: scale(1.1);
    -- }
    ]
        |> List.map (\( a, b ) -> style a b)


view : LightBoxStyle -> Html msg -> Maybe msg -> Html msg
view alertStyle body closeAccept =
    div [ id "nisse" ]
        [ div cssLightboxOverlay
            [ innerView alertStyle closeAccept body ]
        ]


innerView : LightBoxStyle -> Maybe msg -> Html msg -> Html msg
innerView alertStyle closeAccept body =
    let
        contentStyle =
            case alertStyle of
                AlertStyle ->
                    cssLightBoxContentAlert

                Normal ->
                    []

                Wide ->
                    cssLightBoxContentWide
    in
    case closeAccept of
        Nothing ->
            div cssLightBoxContainer
                [ div (cssLightBoxContent ++ contentStyle)
                    [ body ]
                ]

        Just close ->
            div cssLightBoxContainer
                [ div (cssLightBoxContent ++ contentStyle)
                    [ div
                        (onClick close :: cssLightBoxClose)
                        [ FA.render FA.Close ]
                    , body
                    ]
                ]
