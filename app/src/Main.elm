module Main exposing (..)

import Html exposing (Html, text, div, h1, h3, img, input, button)
import Html.Attributes exposing (src, placeholder, disabled)
import Html.Events exposing (onInput, onClick)
import Set exposing (Set, empty, insert, toList)
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
    , error : Maybe String
    , name : String
    , users : Set String
    }


type alias User =
    { name : String
    }


userDecoder : Decoder User
userDecoder =
    decode User
        |> required "name" Json.Decode.string


type alias Flags =
    {}


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { websocket = Nothing
      , error = Nothing
      , name = ""
      , users = empty
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
        InputName s ->
            ( { model | name = s }, Cmd.none )

        Join ->
            let
                result =
                    map (\ws -> ( model, WebSocket.send ws (joining model.name) WSSendingError )) model.websocket
            in
                case result of
                    Just r ->
                        r

                    Nothing ->
                        ( model, Cmd.none )

        Connect ->
            ( model, connect )

        WSOpen (Ok ws) ->
            ( { model | websocket = Just ws }, Cmd.none )

        WSOpen (Err err) ->
            ( model, Task.perform (always Connect) <| Process.sleep (1 * Time.second) )

        WSMessage msg ->
            let
                result =
                    decodeString decodeWsMsg msg
            in
                case result of
                    Ok { msgType, data } ->
                        case msgType of
                            "join" ->
                                ( { model | users = insert data model.users }, Cmd.none )

                            _ ->
                                ( { model | error = Just ("msgType " ++ msgType ++ " not yet implemented !") }, Cmd.none )

                    Err err ->
                        ( { model | error = Just err }, Cmd.none )

        WSClose reason ->
            ( { model | websocket = Nothing }, Cmd.none )

        WSSendingError err ->
            ( model, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Stellwerk" ]
        , h3 [] [ text "Fehler" ]
        , Html.div [] [ case model.error of
                            Just err -> text err
                            Nothing -> text "Alles Ok"
                      ]
        , input [ placeholder "Name", onInput InputName, Html.Attributes.value model.name ] []
        , button [ onClick Join, disabled (model.name == "") ] [ text "Login" ]
        , h1 []
            [ text "Benutzer" ]
        , Html.div [] (List.map (\name -> Html.div [] [ Html.text name ]) (toList model.users))
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
