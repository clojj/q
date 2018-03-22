module Model exposing (..)

import Set exposing (Set, empty, insert, toList)
import Dict
import Json.Encode as ENC
import Json.Decode as DEC
import Json.Decode.Pipeline as DECP


type alias Flags =
    {}


type alias Model =
    { error : Maybe String
    , name : String
    , users : Set String
    , items : List ItemAndName
    }



-------------------------------------------------------------------------


type alias WsMsg =
    { msgType : String
    , data : WsMsgData
    }


type WsMsgData
    = JoinMsg String
    | SetMsg ItemAndName


type alias ItemAndName =
    { item : String
    , name : String
    }


encodeItemAndName : ItemAndName -> ENC.Value
encodeItemAndName itemAndName =
    ENC.object
        [ ( "item", ENC.string itemAndName.item )
        , ( "name", ENC.string itemAndName.name )
        ]


itemAndNameDecoder : DEC.Decoder ItemAndName
itemAndNameDecoder =
    DECP.decode ItemAndName
        |> DECP.required "item" DEC.string
        |> DECP.required "name" DEC.string


encodeWsMsg : WsMsgData -> ENC.Value
encodeWsMsg wsMsgData =
    case wsMsgData of
        JoinMsg name ->
            ENC.object
                [ ( "msgType", ENC.string "join" )
                , ( "data", ENC.string name )
                ]

        SetMsg { item, name } ->
            ENC.object
                [ ( "msgType", ENC.string "set" )
                , ( "data"
                  , ENC.object
                        [ ( "item", ENC.string item )
                        , ( "name", ENC.string name )
                        ]
                  )
                ]

-- TODO try elm-json-extra "when"
decodeWsMsg : DEC.Decoder WsMsgData
decodeWsMsg =
    let
        decoderWsMsgData : String -> DEC.Decoder WsMsgData
        decoderWsMsgData tag =
            case tag of
                "join" ->
                    DEC.field "data" (DEC.map JoinMsg DEC.string)

                "set" ->
                    DEC.field "data" (DEC.map SetMsg itemAndNameDecoder)

                _ ->
                    DEC.fail ("I only know how to decode 'join' and 'set', not \"" ++ tag ++ "\"")
    in
        DEC.field "msgType" DEC.string |> DEC.andThen decoderWsMsgData



-------------------------------------------------------------------------


type alias Items =
    { items : List ItemAndName
    }


itemsDecoder : DEC.Decoder Items
itemsDecoder =
    DECP.decode Items
        |> DECP.required "items" (DEC.list itemAndNameDecoder)



