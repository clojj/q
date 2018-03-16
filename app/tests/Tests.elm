module Tests exposing (..)

import Test exposing (..)
import Expect

import Json.Decode as Decode
import Main exposing (WsMsg, decodeWsMsg, encodeWsMsg)
import Fuzz exposing (Fuzzer)

-- Check out http://package.elm-lang.org/packages/elm-community/elm-test/latest to learn more about testing in Elm!

wsMsg : Fuzzer WsMsg
wsMsg =
  Fuzz.map2 WsMsg Fuzz.string Fuzz.string


all : Test
all =
    describe "A Test Suite"
        [ fuzz wsMsg "round trip" <|
            \msg ->
                msg
                    |> encodeWsMsg
                    |> Decode.decodeValue decodeWsMsg
                    |> Expect.equal (Ok msg)
        ]
