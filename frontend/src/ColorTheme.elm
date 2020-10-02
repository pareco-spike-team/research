module ColorTheme exposing (ColorTheme, GraphNodeColor, currentTheme, lightNeoTheme)

import Color exposing (Color)


type alias GraphNodeColor =
    { id : String
    , fillColor : Color.Color
    , strokeColor : Color.Color
    , textColor : Color.Color
    }


type alias ColorTheme =
    { background : String
    , nodeBackground : String
    , text :
        { tag : String
        , possibleTag : String
        , text : String
        , title : String
        }
    , form :
        { background : String
        , inputFieldBackground : String
        , button : String
        }
    , graph :
        { background : String
        , link : { background : Color.Color }
        , node :
            { tag : GraphNodeColor
            , article : GraphNodeColor
            , selectedTag : GraphNodeColor
            , selectedArticle : GraphNodeColor
            , unknown : GraphNodeColor
            }
        }
    }


lightNeoTheme : ColorTheme
lightNeoTheme =
    { background = "#D2D5DA"
    , nodeBackground = "#FAFAFA"
    , text =
        { tag = "lightgreen"
        , possibleTag = "yellow"
        , text = "black"
        , title = "black"
        }
    , form =
        { background = "#E8E8EA"
        , inputFieldBackground = "white"
        , button = "black"
        }
    , graph =
        { background = "#FAFAFA"
        , link =
            { background = Color.rgb255 170 170 170
            }
        , node =
            { tag =
                { id = "tag"
                , fillColor = Color.green
                , strokeColor = Color.darkGreen
                , textColor = Color.black
                }
            , selectedTag =
                { id = "tag_selected"
                , fillColor = Color.green
                , strokeColor = Color.darkGreen
                , textColor = Color.black
                }
            , article =
                { id = "article"
                , fillColor = Color.lightBlue
                , strokeColor = Color.blue
                , textColor = Color.black
                }
            , selectedArticle =
                { id = "article_selected"
                , fillColor = Color.lightBlue
                , strokeColor = Color.blue
                , textColor = Color.black
                }
            , unknown =
                { id = "unknown"
                , fillColor = Color.brown
                , strokeColor = Color.darkBrown
                , textColor = Color.black
                }
            }
        }
    }



{--
pick a color for xx1
use this: https://maketintsandshades.com/#6DCE9E
xx2 is 2 shades darker
xx3 is 3 shades lighter
--}


darkNeoTheme : ColorTheme
darkNeoTheme =
    let
        white =
            Color.white

        gray =
            Color.rgb255 165 171 182

        purple1 =
            Color.rgb255 222 155 249

        purple2 =
            Color.rgb255 191 133 214

        green1 =
            -- 6DCE9E
            Color.rgb255 109 206 158

        green2 =
            -- 57A57E
            Color.rgb255 87 165 126

        green3 =
            --99DDBB
            Color.rgb255 153 221 187

        yellow1 =
            -- FFD86E
            Color.rgb255 255 216 110

        yellow2 =
            -- CCAD58
            Color.rgb255 204 173 88

        yellow3 =
            -- FFE49A
            Color.rgb255 255 228 154

        brownish =
            -- 443109
            Color.rgb255 68 49 9
    in
    { background = "#181A1E"
    , nodeBackground = "#282C32"
    , text =
        { tag = "#00635E"
        , possibleTag = "#635E00"
        , text = "#FFFFFF"
        , title = "#EAEAEB"
        }
    , form =
        { background = "#282C32"
        , inputFieldBackground = "#181A1E"
        , button = "#D4D5D6"
        }
    , graph =
        { background = "#282C32"
        , link =
            { background = gray
            }
        , node =
            { tag =
                { id = "tag_background"
                , fillColor = yellow1
                , strokeColor = yellow2
                , textColor = brownish
                }
            , selectedTag =
                { id = "tag_background_selected"
                , fillColor = yellow1
                , strokeColor = yellow3
                , textColor = brownish
                }
            , article =
                { id = "article_background"
                , fillColor = green1
                , strokeColor = green2
                , textColor = brownish
                }
            , selectedArticle =
                { id = "article_background_selected"
                , fillColor = green1
                , strokeColor = green3
                , textColor = brownish
                }
            , unknown =
                { id = "unknown"
                , fillColor = purple1
                , strokeColor = purple2
                , textColor = white
                }
            }
        }
    }


currentTheme : ColorTheme
currentTheme =
    darkNeoTheme
