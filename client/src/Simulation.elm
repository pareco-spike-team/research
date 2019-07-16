module Simulation exposing (Edge, Node, Simulation, add, clear, edges, init, isCompleted, lockPosition, movePosition, node, nodes, remove, setCenter, tick, unlockAll, withGravity, withMass, withMaxIterations, withNodes, withSpringForce, withSpringLength)

import Dict exposing (Dict)
import Maybe.Extra


type alias Vector =
    { x : Float
    , y : Float
    , vx : Float
    , vy : Float
    , fixed : Bool
    }


type alias Delta =
    { xDist : Float
    , yDist : Float
    , xSpeed : Float
    , ySpeed : Float
    }


type VectorNode a
    = VectorNode a Vector


nullVector : Vector
nullVector =
    { x = 0, y = 0, vx = 0, vy = 0, fixed = False }


type alias Simulation a =
    { springLength : Float
    , springForce : Float
    , gravity : Float
    , mass : Float
    , deltaTime : Float
    , closestBodiesCount : Int
    , friction : Float
    , maxTicks : Int
    , tickCount : Int
    , center : CenterPos
    , nodes : Dict a (VectorNode a)
    , graph : Dict a (List a)
    }


type alias CenterPos =
    ( Float, Float )


toPolarCoordinate : Int -> Vector -> Vector -> ( Float, Float )
toPolarCoordinate tickCount a b =
    if a.x == b.x && a.y == b.y then
        ( 0, 0.01 * toFloat tickCount )

    else
        toPolar ( a.x - b.x, a.y - b.y )


calculateGravityEffectOnVector : Simulation comparable -> VectorNode comparable -> List Delta
calculateGravityEffectOnVector sim (VectorNode srcId srcVector) =
    sim.nodes
        |> Dict.values
        |> List.filter
            (\(VectorNode id v) -> id /= srcId && not srcVector.fixed)
        |> List.map (\(VectorNode id v) -> toPolarCoordinate (sim.tickCount + 1) srcVector v)
        |> List.sortBy Tuple.first
        |> List.take sim.closestBodiesCount
        |> List.map
            (\( r, v ) ->
                let
                    {--
                    F = Grav * mass * mass / (r*r)
                    F = m * a

                    v1 = v0 + a*t
                    s = v * t
                    =>
                    v1 = v0 + a*t
                    s = (v0 + a*t) * t
                    --}
                    force =
                        let
                            r_ =
                                if r < 10 then
                                    10

                                else
                                    r
                        in
                        sim.gravity * sim.mass * sim.mass / (r_ * r_)

                    acceleration =
                        force / sim.mass

                    ( dx, dy ) =
                        ( sim.deltaTime * acceleration * cos (radians v), sim.deltaTime * acceleration * sin (radians v) )

                    ( sx, sy ) =
                        ( sim.deltaTime * dx, sim.deltaTime * dy )
                in
                { xDist = sx, yDist = sy, xSpeed = dx, ySpeed = dy }
             -- { xDist = 0, yDist = 0, xSpeed = 0, ySpeed = 0 }
            )


calculateSpringEffectOnVector :
    Simulation comparable
    -> VectorNode comparable
    -> VectorNode comparable
    -> Delta
calculateSpringEffectOnVector sim (VectorNode source sourceVector) (VectorNode target targetVector) =
    let
        ( r, v ) =
            toPolarCoordinate sim.tickCount sourceVector targetVector

        springForce l =
            sim.springForce * (sim.springLength - l)

        f =
            springForce r

        acc =
            f / sim.mass

        ( dx, dy ) =
            ( sim.deltaTime * acc * cos (radians v), sim.deltaTime * acc * sin (radians v) )

        ( sx, sy ) =
            ( sim.deltaTime * dx, sim.deltaTime * dy )
    in
    { xDist = sx, yDist = sy, xSpeed = dx, ySpeed = dy }


reverseDelta : Delta -> Delta
reverseDelta d =
    { d | xDist = -d.xDist, yDist = -d.yDist, xSpeed = -d.xSpeed, ySpeed = -d.ySpeed }


createNewNode : Simulation comparable -> Int -> comparable -> VectorNode comparable
createNewNode sim idx x =
    let
        {--
            0: (360 / 1) % 360
            1: (360/1 + 360/2) % 360
            2: 360/1 + 360/2 + 360 / 3
        --}
        angle =
            List.range 1 idx
                |> List.foldl
                    (\r a ->
                        modBy 360 (a + (360 // r))
                    )
                    0
                |> toFloat

        ( xd, yd ) =
            fromPolar ( 0.7 * sim.springLength + 3 * toFloat idx, degrees angle )
    in
    VectorNode x
        { x = Tuple.first sim.center + xd
        , y = Tuple.second sim.center + yd
        , vx = 0.0
        , vy = 0.0
        , fixed = False
        }



{--public --}


init : ( Float, Float ) -> Simulation comparable
init center =
    { springLength = 200
    , springForce = 2
    , gravity = 8
    , mass = 150
    , deltaTime = 0.5
    , closestBodiesCount = 5
    , friction = 0.15
    , maxTicks = 200
    , tickCount = 0
    , center = center
    , nodes = Dict.empty
    , graph = Dict.empty
    }


clear : Simulation comparable -> Simulation comparable
clear s =
    { s | nodes = Dict.empty, graph = Dict.empty, tickCount = 0 }


tick : Simulation comparable -> Simulation comparable
tick sim =
    let
        currentSpeedDeltas : List ( comparable, List Delta )
        currentSpeedDeltas =
            sim.nodes
                |> Dict.values
                |> List.map
                    (\(VectorNode id vector) ->
                        let
                            delta =
                                { xDist = vector.vx * sim.deltaTime
                                , yDist = vector.vy * sim.deltaTime
                                , xSpeed = -sim.friction * vector.vx
                                , ySpeed = -sim.friction * vector.vy
                                }
                        in
                        ( id, [ delta ] )
                    )

        gravityDeltas : List ( comparable, List Delta )
        gravityDeltas =
            sim.nodes
                |> Dict.values
                |> List.map
                    (\(VectorNode id vector) ->
                        ( id, calculateGravityEffectOnVector sim (VectorNode id vector) )
                    )

        springDeltas : List ( comparable, List Delta )
        springDeltas =
            (sim.graph
                |> Dict.toList
                |> List.map
                    (\( source, targets ) ->
                        let
                            sourceNodeMaybe : Maybe (VectorNode comparable)
                            sourceNodeMaybe =
                                Dict.get source sim.nodes

                            targetNodes : List (VectorNode comparable)
                            targetNodes =
                                targets
                                    |> List.map (\x -> Dict.get x sim.nodes)
                                    |> Maybe.Extra.values

                            deltas : List ( comparable, Delta )
                            deltas =
                                sourceNodeMaybe
                                    |> Maybe.Extra.unwrap []
                                        (\sourceNode ->
                                            targetNodes
                                                |> List.map
                                                    (\(VectorNode targetId targetVector) ->
                                                        let
                                                            springDelta =
                                                                calculateSpringEffectOnVector sim sourceNode (VectorNode targetId targetVector)
                                                        in
                                                        ( targetId, springDelta )
                                                    )
                                        )
                        in
                        deltas
                            |> List.foldl
                                (\( targetId, springDelta ) acc ->
                                    let
                                        ( ( srcId, srcDeltas ), dest ) =
                                            acc
                                    in
                                    ( ( srcId, springDelta :: srcDeltas ), ( targetId, [ reverseDelta springDelta ] ) :: dest )
                                )
                                ( ( source, [] ), [] )
                            |> (\( a, b ) -> a :: b)
                    )
            )
                |> List.concat

        newNodes =
            (currentSpeedDeltas ++ gravityDeltas ++ springDeltas)
                |> List.foldl
                    (\delta nodesDict ->
                        let
                            ( id, deltaList ) =
                                delta
                        in
                        nodesDict
                            |> Dict.update id
                                (\x ->
                                    Maybe.map
                                        (\(VectorNode _ y) ->
                                            if y.fixed then
                                                VectorNode id y

                                            else
                                                let
                                                    maxDeltaMove value =
                                                        clamp -20.0 20.0 value
                                                in
                                                VectorNode id
                                                    { y
                                                        | x =
                                                            deltaList
                                                                |> List.foldl (\a b -> b + a.xDist) 0
                                                                |> maxDeltaMove
                                                                |> (+) y.x
                                                        , y =
                                                            deltaList
                                                                |> List.foldl (\a b -> b + a.yDist) 0
                                                                |> maxDeltaMove
                                                                |> (+) y.y
                                                        , vx = deltaList |> List.foldl (\a b -> b + a.xSpeed) y.vx
                                                        , vy = deltaList |> List.foldl (\a b -> b + a.ySpeed) y.vy
                                                    }
                                        )
                                        x
                                )
                    )
                    sim.nodes
    in
    { sim | nodes = newNodes, tickCount = sim.tickCount + 1 }


setCenter : ( Float, Float ) -> Simulation comparable -> Simulation comparable
setCenter center s =
    { s | center = center }


isCompleted : Simulation comparable -> Bool
isCompleted sim =
    case ( sim.tickCount < 20, sim.tickCount > sim.maxTicks ) of
        ( True, _ ) ->
            False

        ( _, True ) ->
            True

        ( False, False ) ->
            sim.nodes
                |> Dict.values
                |> List.any
                    (\(VectorNode _ v) ->
                        (v.vy + v.vx) > 0.1
                    )
                |> not


type alias Node a =
    { id : a
    , x : Float
    , y : Float
    }


nodes : Simulation comparable -> List (Node comparable)
nodes sim =
    sim.nodes
        |> Dict.values
        |> List.map
            (\x ->
                case x of
                    VectorNode a v ->
                        { id = a, x = v.x, y = v.y }
            )


node : comparable -> Simulation comparable -> Maybe (Node comparable)
node id sim =
    Dict.get id sim.nodes
        |> Maybe.map (\(VectorNode _ x) -> { id = id, x = x.x, y = x.y })


type alias Edge =
    { source : { x : Float, y : Float }
    , target : { x : Float, y : Float }
    }


edges : Simulation comparable -> List Edge
edges sim =
    let
        updateDict a dict =
            Dict.update a (\x -> Just <| Maybe.withDefault (Dict.get a sim.nodes) x) dict

        edgePairs =
            sim.graph
                |> Dict.toList
                |> List.foldl
                    (\( a, xs ) ys ->
                        List.foldl (\b zs -> ( Dict.get a sim.nodes, Dict.get b sim.nodes ) :: zs) ys xs
                    )
                    []
    in
    edgePairs
        |> List.filter
            (\x ->
                case x of
                    ( Just _, Just _ ) ->
                        True

                    _ ->
                        False
            )
        |> List.map
            (\x ->
                case x of
                    ( Just (VectorNode a v1), Just (VectorNode b v2) ) ->
                        { source = { x = v1.x, y = v1.y }, target = { x = v2.x, y = v2.y } }

                    ( _, _ ) ->
                        { source = { x = 0.0, y = 0.0 }, target = { x = 0.0, y = 0.0 } }
            )


lockPosition : comparable -> Simulation comparable -> Simulation comparable
lockPosition x sim =
    let
        updatedNodes =
            sim.nodes
                |> Dict.update x
                    (\x2 ->
                        Maybe.map (\(VectorNode a v) -> VectorNode a { v | fixed = True }) x2
                    )
    in
    { sim | nodes = updatedNodes }


unlockAll : Simulation comparable -> Simulation comparable
unlockAll sim =
    let
        updatedNodes =
            sim.nodes
                |> Dict.map
                    (\key (VectorNode id value) ->
                        VectorNode id { value | fixed = False }
                    )
    in
    { sim | nodes = updatedNodes, tickCount = 0 }


movePosition : comparable -> ( Float, Float ) -> Simulation comparable -> Simulation comparable
movePosition id pos sim =
    let
        xs =
            sim.nodes
                |> Dict.update id
                    (\x ->
                        x
                            |> Maybe.map
                                (\(VectorNode _ v) ->
                                    VectorNode id
                                        { v
                                            | x = Tuple.first pos
                                            , y = Tuple.second pos
                                        }
                                )
                    )
    in
    { sim | nodes = xs, tickCount = 0 }


add : ( comparable, List comparable ) -> Simulation comparable -> Simulation comparable
add ( source, targets ) sim =
    let
        nodes_ =
            let
                idx =
                    Dict.keys sim.nodes |> List.length |> (+) 1

                updatedDict =
                    Dict.update
                        source
                        (\x ->
                            x
                                |> Maybe.withDefault (createNewNode sim idx source)
                                |> Just
                        )
                        sim.nodes
            in
            List.foldl
                (\id dict2 ->
                    let
                        idx2 =
                            Dict.keys dict2 |> List.length |> (+) 1
                    in
                    Dict.update id
                        (\x ->
                            x
                                |> Maybe.withDefault (createNewNode sim idx2 id)
                                |> Just
                        )
                        dict2
                )
                updatedDict
                targets

        graph =
            Dict.insert source targets sim.graph
    in
    { sim | nodes = nodes_, graph = graph, tickCount = 0 }


remove : comparable -> Simulation comparable -> Simulation comparable
remove nodeToRemove sim =
    let
        graph =
            sim.graph
                |> Dict.filter
                    (\key _ -> key /= nodeToRemove)
                |> Dict.map
                    (\_ value ->
                        value
                            |> List.filter (\x -> x /= nodeToRemove)
                    )

        nodes_ =
            sim.nodes
                |> Dict.filter (\key _ -> key /= nodeToRemove)
    in
    { sim | graph = graph, nodes = nodes_, tickCount = 0 }



{--public setup function --}


withSpringForce : Float -> Simulation comparable -> Simulation comparable
withSpringForce x sim =
    { sim | springForce = x }


withSpringLength : Float -> Simulation comparable -> Simulation comparable
withSpringLength x sim =
    { sim | springLength = x }


withGravity : Float -> Simulation comparable -> Simulation comparable
withGravity x sim =
    { sim | gravity = x }


withMass : Float -> Simulation comparable -> Simulation comparable
withMass x sim =
    { sim | mass = x }


withNodes : List ( comparable, List comparable ) -> Simulation comparable -> Simulation comparable
withNodes xs sim =
    let
        nodes_ =
            List.foldl
                (\( y, ys ) dict ->
                    let
                        idx =
                            Dict.keys dict |> List.length |> (+) 1

                        updatedDict =
                            Dict.insert y (createNewNode sim idx y) dict
                    in
                    List.foldl
                        (\z dict2 ->
                            let
                                idx2 =
                                    Dict.keys dict2 |> List.length |> (+) 1
                            in
                            Dict.insert z (createNewNode sim idx2 z) dict2
                        )
                        updatedDict
                        ys
                )
                Dict.empty
                xs

        graph =
            List.foldl
                (\( y, ys ) dict ->
                    Dict.insert y ys dict
                )
                Dict.empty
                xs
    in
    { sim | nodes = nodes_, graph = graph }


withMaxIterations : Int -> Simulation comparable -> Simulation comparable
withMaxIterations x sim =
    { sim | maxTicks = x }
