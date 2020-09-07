module Util.FontAwesome exposing (Icon(..), render)

import Html exposing (Html, i)
import Html.Attributes exposing (class)


type Icon
    = Close


render : Icon -> Html msg
render icon =
    wrap <|
        case icon of
            Close ->
                "fa fa-times"


wrap : String -> Html msg
wrap cls =
    i [ class cls ] []
