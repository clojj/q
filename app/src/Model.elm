module Model exposing (..)

import Set as S
import List as L
import Json.Encode as ENC
import Json.Decode as DEC
import Json.Decode.Pipeline as DECP


type alias Flags =
    {}


type alias Model =
    { error : Maybe String
    , users : S.Set String
    , items : List ItemAndState
    }



-------------------------------------------------------------------------


type alias WsMsg =
    { msgType : String
    , data : WsMsgData
    }


type WsMsgData
    = JoinMsg String
    | SetMsg ItemAndName
    | AllItemsMsg (List ItemAndName)


type alias Item =
    String


type alias Name =
    String


type ItemState
    = Set Name
    | Free
    | Setting Name


type alias ItemAndName =
    { item : Item
    , name : Name
    }


toStateList : List ItemAndName -> List ItemAndState
toStateList itemAndNames =
    L.map toItemAndState itemAndNames


toItemAndState : ItemAndName -> ItemAndState
toItemAndState { item, name } =
    { item = item
    , state =
        case name of
            "" ->
                Free

            _ ->
                Set name
    }


toNameList : List ItemAndState -> List ItemAndName
toNameList itemAndStates =
    L.map toItemAndName itemAndStates


toItemAndName : ItemAndState -> ItemAndName
toItemAndName { item, state } =
    { item = item
    , name =
        case state of
            Free ->
                ""

            Set name ->
                name

            Setting name ->
                name
    }


type alias ItemAndState =
    { item : Item
    , state : ItemState
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
                    DEC.field "data" (DEC.map SetMsg itemAndNameDecoder)

                _ ->
                    DEC.fail ("I only know how to decode 'join' and 'set', not \"" ++ tag ++ "\"")
    in
        DEC.field "msgType" DEC.string |> DEC.andThen decoderWsMsgData



-------------------------------------------------------------------------


itemsDecoder : DEC.Decoder (List ItemAndName)
itemsDecoder =
    DEC.list itemAndNameDecoder
