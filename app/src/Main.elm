module Main exposing (..)

import Html exposing (Html, text, div, h1, h2, h3, img, input, button)
import Html.Attributes exposing (src, placeholder, disabled)
import Html.Events exposing (onInput, onClick)
import Set as S
import List as L
import Json.Encode exposing (encode, Value, string, int, float, bool, list, object)
import Json.Decode exposing (Decoder, decodeString)
import Maybe exposing (map)
import WebSocket as WS
import Http
import Model exposing (..)
import Time exposing (..)
import Time.Format exposing (format)


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { error = Nothing
      , users = S.empty -- TODO List
      , items = []
      , time = 0
      }
      -- TODO also 'join' on page visibility: http://package.elm-lang.org/packages/elm-lang/page-visibility/1.0.1/PageVisibility
    , wsMessageOut (joining "NEW")
    )


fetchItems : Cmd Msg
fetchItems =
    Http.send AllItems <|
        Http.get "http://localhost:8080/items" itemsDecoder


type Msg
    = WsMessageIn String
    | SetItem String String Time
    | InputName String Time String
    | InputExpiry String String Time
    | FreeItem String
    | AllItems (Result Http.Error (List Toggle))
    | Tick Time


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


setting : String -> String -> Time -> String
setting item name expiry =
    let
        setMsg =
            SetMsg
                { item = item
                , name = name
                , expiry = expiry
                }
    in
        encode 2 (encodeWsMsg setMsg)


updateInItems : List ItemAndState -> Item -> (ItemState -> ItemState) -> List ItemAndState
updateInItems items item fn =
    L.map
        (\itemAndState ->
            if (item == itemAndState.item) then
                { itemAndState | state = fn itemAndState.state }
            else
                itemAndState
        )
        items



--                        let
--                            _ =
--                                Debug.log "..." xyz
--                        in


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick newtime ->
            ( { model | time = newtime }, Cmd.none )

        -- fetch
        AllItems (Ok theItems) ->
            ( { model | items = toStateList theItems }, Cmd.none )

        AllItems (Err _) ->
            ( { model | error = Just "Error getting items" }, Cmd.none )

        SetItem item name expiry ->
            ( model, wsMessageOut (setting item name expiry) )

        InputName item expiry name ->
            ( { model | items = updateInItems model.items item (\_ -> Setting name expiry) }, Cmd.none )

        InputExpiry item name expiry ->
            ( { model | items = updateInItems model.items item (\_ -> Setting name expiry) }, Cmd.none )

        FreeItem item ->
            ( { model | items = updateInItems model.items item (\_ -> Free) }, wsMessageOut (setting item "" 0) )

        WsMessageIn msg ->
            let
                result =
                    decodeString decodeWsMsg msg
            in
                case result of
                    Ok (JoinMsg name) ->
                        ( { model | users = S.insert name model.users }, Cmd.none )

                    Ok (SetMsg toggle) ->
                        ( { model
                            | items =
                                updateInItems model.items
                                    toggle.item
                                    (\_ ->
                                        case toggle.name of
                                            "" ->
                                                Free

                                            _ ->
                                                Set toggle.name toggle.expiry
                                    )
                          }
                        , Cmd.none
                        )

                    Ok (AllItemsMsg theItems) ->
                        ( { model | items = toStateList theItems }, Cmd.none )

                    Err err ->
                        ( { model | error = Just err }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ WS.listen wsURL WsMessageIn
        , Time.every second Tick
        ]



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ h2 [] [ text "Stellwerk" ]
        , h2 [] [ text "Items" ]
        , Html.div []
            (List.map
                (\{ item, state } ->
                    Html.div []
                        [ Html.div [] [ Html.text item ]
                        , Html.div []
                            (case state of
                                Set name expiry ->
                                    let
                                        remaining =
                                            if (expiry /= 0) then
                                                expiry - model.time
                                            else
                                                0
                                    in
                                        [ Html.text name
                                        , Html.text " Bis: "
                                        , if (remaining > 0) then
                                            Html.text <| format "%H:%M:%S" <| remaining - 3600000
                                          else
                                            Html.text ""
                                        , button [ onClick (FreeItem item) ] [ text "Freigeben" ]
                                        ]

                                Free ->
                                    [ Html.text "[FREI]", button [ onClick (InputName item 0 "") ] [ text "Belegen" ] ]

                                Setting name expiry ->
                                    [ input [ placeholder "Name", onInput (InputName item expiry), Html.Attributes.value name ] []
                                    , input [ placeholder "Dauer", onInput (\value -> InputExpiry item name (Result.withDefault 0 (String.toFloat value))), Html.Attributes.value (toString expiry) ] []
                                    , button [ onClick (SetItem item name expiry) ] [ text "Belegen" ]
                                    ]
                            )
                        ]
                )
                model.items
            )
        , h2 [] [ text "Benutzer" ]
        , Html.div [] (List.map (\name -> Html.div [] [ Html.text name ]) (S.toList model.users))
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
