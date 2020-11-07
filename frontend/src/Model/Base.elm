module Model.Base exposing (Base, Id)


type alias Id =
    String


type alias Base a =
    { a | id : Id }
