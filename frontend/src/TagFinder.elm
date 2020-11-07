module TagFinder exposing (PossibleTag(..), find)

import List.Extra
import Maybe.Extra
import Model.Article exposing (Article)
import Model.Tag exposing (Tag)
import Set


type PossibleTag
    = PossibleTag String


type TextPart
    = Word String
    | Separator String
    | Dot


firstCharIsUpper : TextPart -> Bool
firstCharIsUpper textPart =
    case textPart of
        Dot ->
            False

        Separator _ ->
            False

        Word str ->
            let
                s =
                    String.left 1 str
            in
            s == String.toUpper s


separators : List String
separators =
    [ ".", ",", " ", ":", ";", "‘", "’", "”", "“" ]


parse : String -> List String
parse txt =
    let
        toWordsAndSeparators : String -> List TextPart
        toWordsAndSeparators s =
            List.foldl
                (\separator list ->
                    list
                        |> List.concatMap
                            (\part ->
                                part
                                    |> String.split separator
                                    |> List.intersperse separator
                            )
                )
                [ s ]
                separators
                |> List.filter (\x -> x /= "" && x /= " ")
                |> List.map
                    (\x ->
                        if x == "." then
                            Dot

                        else if List.member x separators then
                            Separator x

                        else
                            Word x
                    )

        toListOfCapitalWords words =
            List.foldl
                (\word ( ( previous1, previous2 ), acc ) ->
                    let
                        wordToString w =
                            case w of
                                Dot ->
                                    "."

                                Separator x ->
                                    x

                                Word s ->
                                    s

                        previousStartsWithUpper =
                            firstCharIsUpper previous1

                        wordStartsWithUpper =
                            firstCharIsUpper word

                        -- _ =
                        --     Debug.log (txt ++ "::") ( ( previous1, previous2 ), ( previousStartsWithUpper, wordStartsWithUpper ), ( word, acc, words ) )
                    in
                    case ( ( previous1, previous2 ), ( previousStartsWithUpper, wordStartsWithUpper ) ) of
                        ( ( Dot, _ ), ( _, _ ) ) ->
                            ( ( word, Dot ), acc )

                        -- Ignore The
                        ( ( Word "The", _ ), ( _, True ) ) ->
                            ( ( word, Word "" ), acc )

                        -- Ex: Keep Turner's World as one capital word
                        ( ( Separator "’", Word x ), ( False, False ) ) ->
                            if (Word "s" == word) && firstCharIsUpper previous2 then
                                ( ( Word (wordToString previous2 ++ "’s"), Word "" )
                                , acc |> List.reverse |> List.drop 1
                                )

                            else
                                ( ( word, previous1 ), acc )

                        -- Ex: foo. Bar baz -> Bar is not keyword
                        ( ( _, Dot ), ( True, False ) ) ->
                            ( ( word, previous1 ), acc )

                        -- Ex foo. Bar Baz -> ("Bar Baz", "")
                        ( ( _, _ ), ( True, True ) ) ->
                            ( ( Word (wordToString previous1 ++ " " ++ wordToString word), Word "" ), acc )

                        --Ex Handle Diso system -> as tag "Diso system"
                        ( ( Word _, _ ), ( True, False ) ) ->
                            if List.member (wordToString word) [ "system", "of" ] then
                                ( ( Word (wordToString previous1 ++ " " ++ wordToString word), Word "" ), acc )

                            else
                                ( ( word, previous1 ), previous1 :: acc )

                        ( ( _, _ ), ( True, False ) ) ->
                            ( ( word, previous1 ), previous1 :: acc )

                        ( ( _, _ ), ( False, True ) ) ->
                            ( ( word, previous1 ), acc )

                        ( ( _, _ ), ( False, False ) ) ->
                            ( ( word, previous1 ), acc )
                )
                ( ( Dot, Word "" ), [] )
                words
                |> (\( ( lastWord, _ ), lst ) ->
                        if firstCharIsUpper lastWord then
                            lastWord :: lst

                        else
                            lst
                   )
                |> List.map
                    (\x ->
                        case x of
                            Word s ->
                                Just s

                            _ ->
                                Nothing
                    )
                |> Maybe.Extra.values
    in
    txt
        |> toWordsAndSeparators
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
        |> List.filter (\x -> not <| List.any (\y -> y.tag == x) article.tags)
        |> List.filter (\x -> String.length x > 2)
        |> List.Extra.unique
        |> List.sort
        |> List.map PossibleTag
