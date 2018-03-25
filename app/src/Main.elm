module Main exposing (..)

import Html exposing (Html, text, div, h1, h2, h3, img, input, button)
import Html.Attributes exposing (src, placeholder, disabled)
import Html.Events exposing (onInput, onClick)
import Set exposing (Set, empty, insert, toList)
import Dict as D
import Json.Encode exposing (encode, Value, string, int, float, bool, list, object)
import Json.Decode exposing (Decoder, decodeString)
import Maybe exposing (map)
import WebSocket as WS
import Http
import Model exposing (..)


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { error = Nothing
      , name = ""
      , users = empty -- TODO List
      , items = D.empty
      }
    , wsMessageOut (joining "NEW")
    )


fetchItems : Cmd Msg
fetchItems =
    Http.send AllItems <|
        Http.get "http://localhost:8080/items" itemsDecoder


type Msg
    = WsMessageIn String
    | InputName String
    | Join
    | SetItem
    | AllItems (Result Http.Error Items)


wsURL : String
wsURL =
    "ws://localhost:8080/chat"


wsMessageOut : String -> Cmd msg
wsMessageOut msg =
    WS.send wsURL msg



---- UPDATE ----


joining : String -> String
joining name =
    encode 2 (encodeWsMsg (JoinMsg name))


setting : String -> String -> String
setting item name =
    let
        setMsg =
            SetMsg
                { item = item
                , name = name
                }
    in
        encode 2 (encodeWsMsg setMsg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AllItems (Ok theItems) ->
            let
                pairs =
                    List.map (\itemAndName -> ( itemAndName.item, itemAndName.name )) theItems.items
            in
                ( { model | items = D.fromList pairs }, Cmd.none )

        AllItems (Err _) ->
            ( { model | error = Just "Error getting items" }, Cmd.none )

        InputName s ->
            ( { model | name = s }, Cmd.none )

        SetItem ->
            ( model, wsMessageOut (setting "dev1" model.name) )

        Join ->
            ( model, wsMessageOut (joining model.name) )

        WsMessageIn msg ->
            let
                result =
                    decodeString decodeWsMsg msg
            in
                case result of
                    Ok (JoinMsg name) ->
                        ( { model | users = insert name model.users }, Cmd.none )

                    Ok (SetMsg itemAndName) ->
                        --                        let
                        --                            _ =
                        --                                Debug.log "itemAndName: " itemAndName
                        --                        in
                        ( { model | items = D.insert itemAndName.item itemAndName.name model.items }, Cmd.none )

                    Ok (AllItemsMsg theItems) ->
                        let
                            pairs =
                                List.map (\itemAndName -> ( itemAndName.item, itemAndName.name )) theItems.items
                        in
                            ( { model | items = D.fromList pairs }, Cmd.none )

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
        [ h2 [] [ text "Stellwerk" ]
        , input [ placeholder "Name", onInput InputName, Html.Attributes.value model.name ] []
        , button [ onClick Join, disabled (model.name == "") ] [ text "Login" ]
        , h2 [] [ text "Items" ]
        , Html.div [] (List.map (\( item, name ) -> Html.div [] [ Html.div [] [ Html.text item ], Html.div [] [ Html.text name ] ]) (D.toList model.items))
        , button [ onClick SetItem ] [ text "Set" ]
        , h2 [] [ text "Benutzer" ]
        , Html.div [] (List.map (\name -> Html.div [] [ Html.text name ]) (toList model.users))
        , h2 [] [ text "Fehler" ]
        , Html.div []
            [ case model.error of
                Just err ->
                    text err

                Nothing ->
                    text "Alles Ok"
            ]
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
