module Main exposing (..)

import Html exposing (Html, text, div, h1, h3, img, input, button)
import Html.Attributes exposing (src, placeholder, disabled)
import Html.Events exposing (onInput, onClick)
import Set exposing (Set, empty, insert, toList)
import Json.Encode exposing (encode, Value, string, int, float, bool, list, object)
import Json.Decode exposing (Decoder, decodeString)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)
import Maybe exposing (map)
import WebSocket as WS


---- MODEL ----


type alias Model =
    { error : Maybe String
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


wsURL : String
wsURL =
    "ws://localhost:8080/chat"


wsMessageOut : String -> Cmd msg
wsMessageOut msg =
    WS.send wsURL msg


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { error = Nothing
      , name = ""
      , users = empty
      }
    , wsMessageOut (joining "newly joined")
    )



---- UPDATE ----


type Msg
    = WsMessageIn String
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
            ( model, wsMessageOut (joining model.name) )

        WsMessageIn msg ->
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    WS.listen wsURL WsMessageIn



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Stellwerk" ]
        , h3 [] [ text "Fehler" ]
        , Html.div []
            [ case model.error of
                Just err ->
                    text err

                Nothing ->
                    text "Alles Ok"
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
        , subscriptions = subscriptions
        }
