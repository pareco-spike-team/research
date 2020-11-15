module Util.FontAwesome exposing (Icon(..), render)

import Html exposing (Attribute, Html, i)
import Html.Attributes exposing (class)


type Icon
    = Close
    | DeleteMany
    | DeleteOne
    | AddOne
    | AddMany
    | Spinner


render : String -> Icon -> Html msg
render classes icon =
    wrap <|
        case icon of
            Close ->
                String.join " " [ "fa fa-times", classes ]

            DeleteMany ->
                String.join " " [ "fas fa-exclamation-circle", classes ]

            DeleteOne ->
                String.join " " [ "fas fa-circle", classes ]

            AddOne ->
                String.join " " [ "fas fa-circle", classes ]

            AddMany ->
                String.join " " [ "fas fa-exclamation-circle", classes ]

            Spinner ->
                String.join " " [ "fas fa-space-shuttle", classes ]


wrap : String -> Html msg
wrap cls =
    i [ class cls ] []
