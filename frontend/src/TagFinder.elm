module TagFinder exposing (PossibleTag(..), find)

import Model.Article exposing (Article)
import Model.Tag exposing (Tag)


type PossibleTag
    = PossibleTag String


firstCharIsUpper : String -> Bool
firstCharIsUpper str =
    let
        s =
            String.left 1 str
    in
    str /= "." && s == String.toUpper s


parse : String -> List String
parse txt =
    let
        toWordsAndDots s =
            s
                |> String.split " "
                |> List.foldl (\a b -> b ++ String.split "." a) []
                |> List.map
                    (\x ->
                        if x == "" then
                            "."

                        else
                            x
                    )

        toListOfCapitalWords words =
            List.foldl
                (\word ( ( previous1, previous2 ), acc ) ->
                    let
                        previousStartsWithUpper =
                            firstCharIsUpper previous1

                        wordStartsWithUpper =
                            firstCharIsUpper word

                        -- _ =
                        --     Debug.log (txt ++ "::") ( ( previous1, previous2 ), ( previousStartsWithUpper, wordStartsWithUpper ), ( word, acc, words ) )
                    in
                    case ( ( previous1, previous2 ), ( previousStartsWithUpper, wordStartsWithUpper ) ) of
                        ( ( ".", _ ), ( _, _ ) ) ->
                            ( ( word, "." ), acc )

                        -- Ex: foo. Bar baz -> Bar is not keyword
                        ( ( _, "." ), ( True, False ) ) ->
                            ( ( word, previous1 ), acc )

                        -- Ex foo. Bar Baz -> ("Bar Baz", "")
                        ( ( _, _ ), ( True, True ) ) ->
                            ( ( previous1 ++ " " ++ word, "" ), acc )

                        ( ( _, _ ), ( True, False ) ) ->
                            ( ( word, previous1 ), previous1 :: acc )

                        ( ( _, _ ), ( False, True ) ) ->
                            ( ( word, previous1 ), acc )

                        ( ( _, _ ), ( False, False ) ) ->
                            ( ( word, previous1 ), acc )
                )
                ( ( ".", "" ), [] )
                words
                |> (\( ( lastWord, _ ), lst ) ->
                        if firstCharIsUpper lastWord then
                            lastWord :: lst

                        else
                            lst
                   )
    in
    txt
        |> toWordsAndDots
        |> toListOfCapitalWords


find : Article -> List PossibleTag
find article =
    let
        parsedTitle =
            parse article.title

        parsedBody =
            parse article.text
    in
    (parsedTitle ++ parsedBody)
        |> List.filter
            (\x ->
                not <| List.any (\y -> y.tag == x) article.tags
            )
        |> List.sort
        |> List.map PossibleTag
