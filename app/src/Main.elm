module Main exposing (..)

import Html exposing (Html, text, div, h1, img, input, button)
import Html.Attributes exposing (src, placeholder, disabled)
import Html.Events exposing (onInput, onClick)
import Process
import Task
import Time
import WebSocket.Explicit as WebSocket exposing (WebSocket)
import Json.Encode exposing (encode, Value, string, int, float, bool, list, object)
import Json.Decode exposing (Decoder, decodeString)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)
import Maybe exposing (map)



---- MODEL ----


type alias Model =
    { websocket : Maybe WebSocket
    , name : String
    , users : List User
    , useragent : String
    }


type alias User =
    { name : String
    }

userDecoder : Decoder User
userDecoder =
    decode User
        |> required "name" Json.Decode.string

type alias Flags =
  { agent : String
  }

init : Flags -> ( Model, Cmd Msg )
init { agent } =
    ( { websocket = Nothing
      , name = ""
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
    | InputName String
    | Join


joining : String -> String
joining name =
    let
        joinMsg =
            { msgType = "join"
            , data = name
            }
    in
        encode 2 (encodeWsMsg joinMsg)


type alias WsMsg =
    { msgType : String
    , data : String
    }

encodeWsMsg : WsMsg -> Value
encodeWsMsg wsMsg =
    object
        [ ( "msgType", string wsMsg.msgType )
        , ( "data", string wsMsg.data )
        ]

decodeWsMsg : Decoder WsMsg
decodeWsMsg =
    decode WsMsg
        |> required "msgType" Json.Decode.string
        |> required "data" Json.Decode.string


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of

        InputName s -> ( { model | name = s }, Cmd.none )

        Join ->
            let
                result = map (\ws -> ( model, WebSocket.send ws (joining model.name) WSSendingError )) model.websocket
            in
                case result of
                    Just r -> r
                    Nothing -> ( model, Cmd.none )

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
            let
                result =
                    decodeString decodeWsMsg msg

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
        , input [ placeholder "Name", onInput InputName, Html.Attributes.value model.name ] []
        , button [ onClick Join, disabled (model.name == "") ] [ text "Login" ]
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
