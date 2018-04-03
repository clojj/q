module Tests exposing (..)

import Test exposing (..)
import Expect
import Json.Decode as Decode
import Model exposing (..)
import Main exposing (toDurationString)


-- Check out http://package.elm-lang.org/packages/elm-community/elm-test/latest to learn more about testing in Elm!


all : Test
all =
    describe "q"
        [ describe "JSON WsMsg"
            [ test "roundtrip" <|
                \_ ->
                    let
                        setMsg =
                            (SetMsg { item = "", name = "", expiry = 0 })

                        enc =
                            encodeWsMsg setMsg

                        dec =
                            Decode.decodeValue decodeWsMsg enc
                    in
                        case dec of
                            Ok wsMsgData ->
                                Expect.equal wsMsgData setMsg

                            Err err ->
                                Expect.fail err
            , test "hhmmss full" <|
                \_ ->
                    let
                        duration =
                            3725000

                        durationString =
                            toDurationString duration
                    in
                        Expect.equal durationString "1 Std 2 Min 5 Sek"
            , test "hhmmss minutes" <|
                \_ ->
                    let
                        duration =
                            120000

                        durationString =
                            toDurationString duration
                    in
                        Expect.equal durationString "2 Min 0 Sek"
            ]
        ]
