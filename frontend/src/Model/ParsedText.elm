module Model.ParsedText exposing (Index, ParsedText, TextType(..))


type alias ParsedText =
    ( Index, String, TextType )


type TextType
    = TypeText
    | TypeTag
    | NewLine


type alias Index =
    Int
