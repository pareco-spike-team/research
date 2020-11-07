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
        , test "should not include ‘ and ’ in ‘Youscape’ " <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "title"
                        , text = "where the unique work ‘Youscape’ was stolen"
                        , tags = []
                    }
                    |> Expect.equalLists
                        [ PossibleTag "Youscape"
                        ]
        , test "should remove ,:; from possible tags " <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "title"
                        , text = "tags Colon: Semicolon; Comma, Dot. and ‘Multiple’:, "
                        , tags = []
                    }
                    |> Expect.equalLists
                        [ PossibleTag "Colon"
                        , PossibleTag "Comma"
                        , PossibleTag "Dot"
                        , PossibleTag "Multiple"
                        , PossibleTag "Semicolon"
                        ]
        , test "should treat 'of' as starting with a capital letter" <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "title"
                        , text = "system during the Alliance Festival of Culture."
                        , tags = []
                    }
                    |> Expect.equalLists
                        [ PossibleTag "Alliance Festival of Culture"
                        ]
        , test "should always treat 'The' as starting with small letter" <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "title"
                        , text = "It is true. The Alliance is __."
                        , tags = []
                    }
                    |> Expect.equalLists
                        [ PossibleTag "Alliance"
                        ]
        , test "should treat ’ in words like 'Turner’s World' together" <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "title"
                        , text = "Thing on Turner’s World is cool."
                        , tags = []
                    }
                    |> Expect.equalLists
                        [ PossibleTag "Turner’s World"
                        ]
        , test "should treat 'Xyz system' as a tag" <|
            \_ ->
                TagFinder.find
                    { article
                        | title = "title"
                        , text = "word Xyz system is cool."
                        , tags = []
                    }
                    |> Expect.equalLists
                        [ PossibleTag "Xyz system"
                        ]
        ]
