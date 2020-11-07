module TagFinderTests exposing (suite)

import Expect
import Model.Article exposing (Article)
import TagFinder exposing (PossibleTag(..))
import Test exposing (Test, describe, test)


article : Article
article =
    { id = "", date = "", title = "", text = "", tags = [], parsedText = [] }


suite : Test
suite =
    describe "TagFinder"
        [ test "an empty title suggests no tags" <|
            \_ ->
                TagFinder.find
                    article
                    |> Expect.equalLists []
        , test "a title with no words starting with a capital letter suggests no tags" <|
            \_ ->
                TagFinder.find
                    { article | title = "no capital letters" }
                    |> Expect.equalLists []
        , test "a title starting with a capital letter suggests no tags" <|
            \_ ->
                TagFinder.find
                    { article | title = "No capital letters" }
                    |> Expect.equalLists []
        , test "a title with a word in capital should be suggested as a tag" <|
            \_ ->
                TagFinder.find
                    { article | title = "has Tag in title" }
                    |> Expect.equalLists [ PossibleTag "Tag" ]
        , test "a title with a word in capital as last word should be suggested as a tag" <|
            \_ ->
                TagFinder.find
                    { article | title = "ends with a Tag" }
                    |> Expect.equalLists [ PossibleTag "Tag" ]
        , test "a title with a word in capital should not be suggested as a tag if its i Existing Tags" <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "has Existing in title and Tag"
                        , tags = [ { id = "1", tag = "Existing" }, { id = "2", tag = "Another one" } ]
                    }
                    |> Expect.equalLists [ PossibleTag "Tag" ]
        , test "a title and body with a words in capital should be suggested as a tag unless its in Existing Tags" <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "This title has an Existing in title and Tag"
                        , text = "This is a word with a Tag-2. Not this Existing one But This And This. Bye."
                        , tags = [ { id = "1", tag = "Existing" }, { id = "2", tag = "Another one" } ]
                    }
                    |> Expect.equalLists
                        [ PossibleTag "But This And This"
                        , PossibleTag "Tag"
                        , PossibleTag "Tag-2"
                        ]
        ]
