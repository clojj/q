module Main exposing (..)

import Html exposing (Html, text, div, h1, img)
import Html.Attributes exposing (src)
import Process
import Task
import Time
import WebSocket.Explicit as WebSocket exposing (WebSocket)


---- MODEL ----


type alias Model =
    { websocket : Maybe WebSocket
    , events : List String
    }


init : ( Model, Cmd Msg )
init =
    ( { websocket = Nothing
      , events = []
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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        log event details model =
            { model | events = (event ++ ": " ++ details) :: model.events }
    in
        case msg of
            Connect ->
                ( model, connect )

            WSOpen (Ok ws) ->
                ( { model | websocket = Just ws }
                    |> log "open" "success"
                , WebSocket.send ws "join" WSSendingError
                )

            WSOpen (Err err) ->
                ( model |> log "open" err
                , Task.perform (always Connect) <| Process.sleep (5 * Time.second)
                )

            WSMessage msg ->
                ( model |> log "reply" msg, Cmd.none )

            WSClose reason ->
                ( { model | websocket = Nothing } |> log "close" reason, Cmd.none )

            WSSendingError err ->
                ( model |> log "send" err, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Schalttafel" ]
        , Html.ul []
            (List.map (\event -> Html.li [] [ Html.text event ]) model.events)
        ]



---- PROGRAM ----


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }
