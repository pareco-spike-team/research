module ColorTheme exposing (ColorTheme, GraphNodeColor, currentTheme, lightNeoTheme)

import Color exposing (Color)


type alias GraphNodeColor =
    { fillColor : Color.Color
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
                { fillColor = Color.green
                , strokeColor = Color.darkGreen
                , textColor = Color.black
                }
            , article =
                { fillColor = Color.lightBlue
                , strokeColor = Color.blue
                , textColor = Color.black
                }
            , unknown =
                { fillColor = Color.brown
                , strokeColor = Color.darkBrown
                , textColor = Color.black
                }
            }
        }
    }


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
            Color.rgb255 109 206 158

        green2 =
            Color.rgb255 96 181 139

        yellow1 =
            Color.rgb255 255 216 110

        yellow2 =
            Color.rgb255 237 186 57

        brownish =
            Color.rgb255 76 54 10
    in
    { background = "#282C32"
    , nodeBackground = "#4A4F5B"
    , text =
        { tag = "#31343D"
        , possibleTag = "#7C7600"
        , text = "#FFFFFF"
        , title = "#EEEEEF"
        }
    , form =
        { background = "#4A4F5B"
        , inputFieldBackground = "#282C32"
        , button = "#D2D4D7"
        }
    , graph =
        { background = "#4A4F5B"
        , link =
            { background = gray
            }
        , node =
            { tag =
                { fillColor = yellow1
                , strokeColor = yellow2
                , textColor = brownish
                }
            , article =
                { fillColor = green1
                , strokeColor = green2
                , textColor = brownish
                }
            , unknown =
                { fillColor = purple1
                , strokeColor = purple2
                , textColor = white
                }
            }
        }
    }


currentTheme : ColorTheme
currentTheme =
    darkNeoTheme
