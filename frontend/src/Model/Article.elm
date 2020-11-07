module Model.Article exposing (Article)

import Model.Base exposing (Base)
import Model.ParsedText exposing (ParsedText)
import Model.Tag exposing (Tag)


type alias Article =
    Base
        { date : String
        , title : String
        , text : String
        , tags : List Tag
        , parsedText : List ParsedText
        }
