module Main exposing (..)

import Html exposing (Html, text, div, h1, img)
import Html.Attributes exposing (src)
import Process
import Task
import Time
import WebSocket.Explicit as WebSocket exposing (WebSocket)
import Json.Encode exposing (encode, Value, string, int, float, bool, list, object)
import Json.Decode exposing (Decoder, decodeString)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)


---- MODEL ----


type alias Model =
    { websocket : Maybe WebSocket
    , users : List User
    , useragent : String
    }


type alias User =
    { name : String
    }


type alias WsMsg =
    { msgType : String
    , data : String
    }

type alias Flags =
  { agent : String
  }

init : Flags -> ( Model, Cmd Msg )
init { agent } =
    ( { websocket = Nothing
      , users = []
      , useragent = agent
      }
    , connect
    )


connect : Cmd Msg
connect =
    WebSocket.open "ws://localhost:8080/chat"
        { onOpen = WSOpen
        , onMessage = WSMessage
        , onClose = WSClose
        }



---- UPDATE ----


type Msg
    = Connect
    | WSOpen (Result String WebSocket)
    | WSMessage String
    | WSClose String
    | WSSendingError String


type alias Join =
    { msgType : String
    , data : String
    }


joining : String -> String
joining msg =
    let
        json =
            { msgType = "join"
            , data = msg
            }
    in
        joinToJson json


joinToJson : Join -> String
joinToJson join =
    encode 2 (encodeJoin join)


encodeJoin : Join -> Value
encodeJoin join =
    object
        [ ( "msgType", string join.msgType )
        , ( "data", string join.data )
        ]


userDecoder : Decoder User
userDecoder =
    decode User
        |> required "name" Json.Decode.string


wsMsgDecoder : Decoder WsMsg
wsMsgDecoder =
    decode WsMsg
        |> required "msgType" Json.Decode.string
        |> required "data" Json.Decode.string


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Connect ->
            ( model, connect )

        WSOpen (Ok ws) ->
            ( { model | websocket = Just ws }
            , WebSocket.send ws (joining model.useragent) WSSendingError -- TODO remove agent, input username !
            )

        WSOpen (Err err) ->
            ( model
            , Task.perform (always Connect) <| Process.sleep (5 * Time.second)
            )

        WSMessage msg ->
            -- TODO decode JSON
            let
                result =
                    decodeString wsMsgDecoder msg

                { msgType, data } =
                    case result of
                        Ok json ->
                            json

                        Err err ->
                            { msgType = "error", data = err }
            in
                if msgType == "join" then
                    ( { model | users = { name = data } :: model.users }, Cmd.none )
                else
                    ( model, Cmd.none )

        WSClose reason ->
            ( { model | websocket = Nothing }, Cmd.none )

        WSSendingError err ->
            ( model, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Schalttafel" ]
        , Html.ul []
            (List.map (\user -> Html.li [] [ Html.text user.name ]) model.users)
        ]



---- PROGRAM ----


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }
