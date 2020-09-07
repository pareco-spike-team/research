module Util.RemoteData exposing (RemoteData(..), map)

import Http


type RemoteData t
    = Suspended
    | InFlight
    | Success t
    | Fail Http.Error


map : (a -> b) -> RemoteData a -> RemoteData b
map f remoteData =
    case remoteData of
        Success data ->
            Success (f data)

        Suspended ->
            Suspended

        InFlight ->
            InFlight

        Fail e ->
            Fail e
