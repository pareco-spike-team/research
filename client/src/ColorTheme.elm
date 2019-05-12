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
        }
    , form :
        { background : String
        , inputFieldBackground : String
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
        }
    , form =
        { background = "#E8E8EA"
        , inputFieldBackground = "white"
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


currentTheme : ColorTheme
currentTheme =
    lightNeoTheme
