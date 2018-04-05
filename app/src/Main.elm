port module Main exposing (..)

import Html exposing (Html, text, div, h1, h2, h3, img, input, button)
import Html.Attributes exposing (src, placeholder, disabled, class, id)
import Html.Events exposing (onInput, onClick, on, keyCode)
import Dom exposing (focus)
import Set as S
import List as L
import Json.Encode exposing (encode, Value, string, int, float, bool, list, object)
import Json.Decode exposing (Decoder, decodeString)
import Maybe exposing (map)
import WebSocket as WS
import Http
import Model exposing (..)
import Time exposing (..)
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Row as Row
import Bootstrap.Grid.Col as Col
import Bootstrap.Utilities.Spacing as Spc
import Task


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


port windowFocus : (String -> msg) -> Sub msg


fetchItems : Cmd Msg
fetchItems =
    Http.send AllItems <|
        Http.get "http://localhost:8080/items" itemsDecoder


wsURL : String
wsURL =
    "ws://localhost:8080/ws"


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


setItemState : List ItemAndState -> Item -> ItemState -> List ItemAndState
setItemState items item newState =
    L.map
        (\itemAndState ->
            if (item == itemAndState.item) then
                { itemAndState | state = newState }
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
        FocusResult result ->
            case result of
                Err (Dom.NotFound id) ->
                    { model | error = Just ("Could not find dom id: " ++ id) } ! []

                Ok () ->
                    { model | error = Nothing } ! []

        WindowFocus _ ->
            ( model, wsMessageOut (joining "NEW") )

        Tick newtime ->
            ( { model | time = newtime }, Cmd.none )

        -- fetch
        AllItems (Ok theItems) ->
            ( { model | items = toStateList theItems }, Cmd.none )

        AllItems (Err _) ->
            ( { model | error = Just "Error getting items" }, Cmd.none )

        SetItem item name expiry ->
            ( model, wsMessageOut (setting item name expiry) )

        InputName item expiry domId name ->
            let
                cmd =
                    case domId of
                        "" ->
                            Cmd.none

                        _ ->
                            Task.attempt FocusResult (focus domId)
            in
                { model | items = setItemState model.items item (Setting name expiry) } ! [ cmd ]

        InputExpiry item name domId expiry ->
            let
                cmd =
                    case domId of
                        "" ->
                            Cmd.none

                        _ ->
                            Task.attempt FocusResult (focus domId)
            in
                { model | items = setItemState model.items item (Setting name expiry) } ! [ cmd ]

        FreeItem item name ->
            ( { model | items = setItemState model.items item (Set name model.time) }, wsMessageOut (setting item "" 0) )

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
                                setItemState model.items
                                    toggle.item
                                    (Set toggle.name toggle.expiry)
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
        , windowFocus WindowFocus
        ]



---- VIEW ----


view : Model -> Html Msg
view model =
    Grid.container []
        [ Grid.row [ Row.centerXs ]
            [ Grid.col [ Col.xs12 ]
                [ h3 [] [ text "Stellwerk" ]
                ]
            ]
        , Html.div []
            (List.map
                (\{ item, state } ->
                    let
                        remaining =
                            case state of
                                Set _ expiry ->
                                    if (expiry /= 0 && model.time > 0) then
                                        expiry - model.time
                                    else
                                        0

                                Setting _ _ ->
                                    0

                        status =
                            case model.time of
                                0 ->
                                    "bg-info"

                                _ ->
                                    case state of
                                        Set _ _ ->
                                            if remaining > 0 then
                                                "bg-danger"
                                            else
                                                "bg-success"

                                        Setting _ _ ->
                                            "bg-warning"

                        label =
                            Block.titleH4 [] [ text item ]
                    in
                        Grid.row [ Row.attrs [ Spc.mt3 ], Row.middleXs ]
                            [ Grid.col [ Col.xs12 ]
                                [ Card.config [ Card.attrs [ class status ] ]
                                    |> Card.block []
                                        (case model.time of
                                            0 ->
                                                [ label
                                                , Block.text [] [ text "Initialisierung..." ]
                                                ]

                                            _ ->
                                                (case state of
                                                    Set name expiry ->
                                                        if remaining > 0 then
                                                            [ label
                                                            , Block.text [] [ text name ]
                                                            , Block.text [] [ text <| toDurationString <| remaining ]

                                                            -- TODO use Bootstrap's Button everywhere
                                                            , Block.custom <| button [ onClick (FreeItem item name), class "btn btn-default bg-primary" ] [ text "freigabe" ]
                                                            ]
                                                        else
                                                            [ label
                                                            , Block.text [] [ text "frei" ]
                                                            , Block.text [] [ text "" ]
                                                            , Block.custom <| button [ onClick (InputName item "" "inputName" ""), class "btn btn-default bg-primary" ] [ text "belegen" ]
                                                            ]

                                                    Setting name expiry ->
                                                        [ label
                                                        , Block.text [] [ input [ id "inputName", placeholder "Name", onInput (InputName item expiry ""), onEnter (InputExpiry item name "inputDauer" expiry) ] [] ]
                                                        , Block.text [] [ input [ id "inputDauer", placeholder "Dauer [Stunden:]Minuten", onInput (InputExpiry item name ""), onEnter (SetItem item name (parseDuration expiry)) ] [] ]
                                                        , Block.custom <| button [ onClick (SetItem item name (parseDuration expiry)), class "btn btn-default bg-primary" ] [ text "belegen" ]
                                                        ]
                                                )
                                        )
                                    |> Card.view
                                ]
                            ]
                )
                model.items
            )

        -- , h2 [] [ text "Benutzer" ]
        -- , Html.div [] (List.map (\name -> Html.div [] [ Html.text name ]) (S.toList model.users))
        , Html.div []
            [ case model.error of
                Just err ->
                    h3 [] [ text err ]

                Nothing ->
                    text ""
            ]
        ]


onEnter : Msg -> Html.Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Json.Decode.succeed msg
            else
                Json.Decode.fail "not ENTER"
    in
        on "keydown" (Json.Decode.andThen isEnter keyCode)


onChange : (String -> msg) -> Html.Attribute msg
onChange msgCreator =
    Html.Events.on "change" (Json.Decode.map msgCreator Html.Events.targetValue)


toDurationString : Time -> String
toDurationString duration =
    let
        hours =
            truncate (duration / 3600000)

        hh =
            if hours > 0 then
                toString hours ++ " Std "
            else
                ""

        durationMinutes =
            duration - toFloat (hours * 3600000)

        minutes =
            truncate (durationMinutes / 60000)

        mm =
            if minutes > 0 then
                toString minutes ++ " Min "
            else
                ""

        durationSeconds =
            durationMinutes - toFloat (minutes * 60000)

        seconds =
            truncate (durationSeconds / 1000)
    in
        hh ++ mm ++ toString seconds ++ " Sek"


parseDuration : String -> Time
parseDuration input =
    case input of
        "" ->
            0

        str ->
            let
                duration =
                    String.split ":" str
            in
                case duration of
                    [ hh, mm ] ->
                        let
                            hhValid =
                                min 8 <| Result.withDefault 0 (String.toFloat hh)

                            hhTime =
                                3600000 * hhValid

                            mmValid =
                                min 59 <| Result.withDefault 0 (String.toFloat mm)

                            mmTime =
                                60000 * mmValid
                        in
                            hhTime + mmTime

                    [ mm ] ->
                        let
                            mmValid =
                                min 59 <| Result.withDefault 0 (String.toFloat mm)
                        in
                            60000 * mmValid

                    [] ->
                        0

                    _ :: _ ->
                        0



---- PROGRAM ----


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
