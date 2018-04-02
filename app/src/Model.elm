module Model exposing (..)

import Set as S
import List as L
import Json.Encode as ENC
import Json.Decode as DEC
import Json.Decode.Pipeline as DECP
import Time exposing (..)
import Http


type alias Flags =
    {}


type alias Model =
    { error : Maybe String
    , users : S.Set String
    , items : List ItemAndState
    , time : Time
    }


type alias Item =
    String


type alias Name =
    String


type Msg
    = WsMessageIn String
    | SetItem Item Name Time
    | InputName Item String Name
    | InputExpiry Item Name String
    | FreeItem Item
    | AllItems (Result Http.Error (List Toggle))
    | Tick Time



-------------------------------------------------------------------------


type alias WsMsg =
    { msgType : String
    , data : WsMsgData
    }


type WsMsgData
    = JoinMsg String
    | SetMsg Toggle
    | AllItemsMsg (List Toggle)


type ItemState
    = Set Name Time
    | Free
    | Setting Name String


type alias Toggle =
    { item : Item
    , name : Name
    , expiry : Time
    }



-- merge the next 2 functions


toStateList : List Toggle -> List ItemAndState
toStateList toggles =
    L.map toItemAndState toggles


toItemAndState : Toggle -> ItemAndState
toItemAndState { item, name, expiry } =
    { item = item
    , state =
        case name of
            "" ->
                Free

            _ ->
                Set name expiry
    }


type alias ItemAndState =
    { item : Item
    , state : ItemState
    }


encodeToggle : Toggle -> ENC.Value
encodeToggle toggle =
    ENC.object
        [ ( "item", ENC.string toggle.item )
        , ( "name", ENC.string toggle.name )
        , ( "expiry", ENC.float toggle.expiry )
        ]


decodeToggle : DEC.Decoder Toggle
decodeToggle =
    DECP.decode Toggle
        |> DECP.required "item" DEC.string
        |> DECP.required "name" DEC.string
        |> DECP.required "expiry" DEC.float


encodeWsMsg : WsMsgData -> ENC.Value
encodeWsMsg wsMsgData =
    case wsMsgData of
        JoinMsg name ->
            ENC.object
                [ ( "msgType", ENC.string "join" )
                , ( "data", ENC.string name )
                ]

        SetMsg { item, name, expiry } ->
            ENC.object
                [ ( "msgType", ENC.string "set" )
                , ( "data"
                  , ENC.object
                        [ ( "item", ENC.string item )
                        , ( "name", ENC.string name )
                        , ( "expiry", ENC.float expiry )
                        ]
                  )
                ]

        _ ->
            ENC.null



-- TODO try elm-json-extra "when"


decodeWsMsg : DEC.Decoder WsMsgData
decodeWsMsg =
    let
        decoderWsMsgData : String -> DEC.Decoder WsMsgData
        decoderWsMsgData tag =
            case tag of
                "join" ->
                    DEC.field "data" (DEC.map JoinMsg DEC.string)

                "allItems" ->
                    DEC.field "data" (DEC.map AllItemsMsg itemsDecoder)

                "set" ->
                    DEC.field "data" (DEC.map SetMsg decodeToggle)

                _ ->
                    DEC.fail ("I only know how to decode 'join' and 'set', not \"" ++ tag ++ "\"")
    in
        DEC.field "msgType" DEC.string |> DEC.andThen decoderWsMsgData



-------------------------------------------------------------------------


itemsDecoder : DEC.Decoder (List Toggle)
itemsDecoder =
    DEC.list decodeToggle
