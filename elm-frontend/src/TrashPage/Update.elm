module TrashPage.Update exposing (Msg(..), changeDay, changeVolume, gotGqlResponse, gotResponse, gqlHost, lookupStats, lookupTrash, optionFor, responseErrorMessage, saveTrash, saveZero, update)

import Graphqelm.Http
import Graphqelm.Operation exposing (RootMutation, RootQuery)
import Graphqelm.OptionalArgument exposing (..)
import Graphqelm.SelectionSet exposing (SelectionSet, with)
import Result
import Time
import Trash.Enum.Metric exposing (Metric(..))
import Trash.Mutation as Mutation
import Trash.Query as Query
import Trash.Scalar
import TrashPage.Model exposing (..)


gqlHost : String
gqlHost =
    "/graphql/"


type Msg
    = ChangeVolume String
    | ChangeDay WhichDay
    | GotResponse (Result (Graphqelm.Http.Error GqlResponse) GqlResponse)
    | Save
    | SaveZero


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeVolume s ->
            ( changeVolume s model, Cmd.none )

        GotResponse r ->
            ( gotResponse r model, Cmd.none )

        Save ->
            ( model, saveTrash model )

        SaveZero ->
            saveZero model

        ChangeDay day ->
            changeDay day model


changeVolume : String -> Model -> Model
changeVolume txt model =
    if txt == "" then
        model
            |> setPageVolume Nothing
            |> setPageError Nothing
            |> setPageChanged False

    else
        case String.toFloat txt of
            Err _ ->
                model
                    |> setPageVolume Nothing
                    |> setPageError (Just "Amount must be a number")
                    |> setPageChanged True

            Ok x ->
                if x < 0 then
                    model
                        |> setPageVolume Nothing
                        |> setPageError (Just "Amount must be 0 or more")
                        |> setPageChanged True

                else
                    model
                        |> setPageVolume (Just x)
                        |> setPageError Nothing
                        |> setPageChanged True


changeDay : WhichDay -> Model -> ( Model, Cmd Msg )
changeDay day model =
    let
        newModel =
            model
                |> setPageDay day
                |> setPageVolume Nothing
    in
    ( newModel, lookupTrash newModel )


gotResponse :
    Result (Graphqelm.Http.Error GqlResponse) GqlResponse
    -> Model
    -> Model
gotResponse r model =
    case r of
        Err error ->
            model
                |> setPageChanged False
                |> setPageError (Just <| responseErrorMessage error)

        Ok gqlResponse ->
            gotGqlResponse gqlResponse model


gotGqlResponse : GqlResponse -> Model -> Model
gotGqlResponse gqlResponse model =
    case gqlResponse of
        TrashData t ->
            case t of
                Nothing ->
                    model
                        |> setPageVolume Nothing
                        |> setPageError Nothing
                        |> setPageChanged False

                Just data ->
                    model
                        |> setPageVolume (Just data.volume)
                        |> setPageError Nothing
                        |> setPageChanged False

        StatsData data ->
            let
                oldStats =
                    model.stats

                newStats =
                    { oldStats
                        | sitePerPersonPerWeek = data.site.perPersonPerWeek
                        , siteStandardDeviation = data.site.standardDeviation
                        , userPerPersonPerWeek = data.user.perPersonPerWeek
                    }
            in
            { model | stats = newStats }



-- GraphQL


lookupTrash : Model -> Cmd Msg
lookupTrash model =
    Query.selection TrashData
        |> with
            (Query.trash
                { token = jwtString model.entry.jwt
                , date = relativeDate model.meta.timestamp model.opts.day
                }
                (parseTrash model.entry.metric)
            )
        |> Graphqelm.Http.queryRequest gqlHost
        |> Graphqelm.Http.send GotResponse


lookupStats : Model -> Cmd Msg
lookupStats model =
    Query.selection StatsData
        |> with
            (Query.stats
                { token = jwtString model.entry.jwt }
                (parsePageStats model.entry.metric)
            )
        |> Graphqelm.Http.queryRequest gqlHost
        |> Graphqelm.Http.send GotResponse


saveTrash : Model -> Cmd Msg
saveTrash model =
    Mutation.selection TrashData
        |> with
            (Mutation.saveTrash
                (\opts ->
                    { opts
                        | metric = Present model.entry.metric
                        , volume = optionFor model.entry.volume
                    }
                )
                { date = relativeDate model.meta.timestamp model.opts.day
                , token = jwtString model.entry.jwt
                }
                (parseSaveTrash model.entry.metric)
            )
        |> Graphqelm.Http.mutationRequest gqlHost
        |> Graphqelm.Http.send GotResponse


saveZero : Model -> ( Model, Cmd Msg )
saveZero model =
    let
        zero =
            changeVolume "0" model
    in
    ( zero, saveTrash zero )



-- GraphQL Helpers


responseErrorMessage : Graphqelm.Http.Error a -> String
responseErrorMessage error =
    case error of
        Graphqelm.Http.HttpError err ->
            "Http Error: " ++ toString err

        Graphqelm.Http.GraphqlError _ errs ->
            "Graphql Error: "
                ++ List.foldr (\err txt -> err.message ++ " " ++ txt) "" errs


optionFor : Maybe a -> OptionalArgument a
optionFor a =
    case a of
        Nothing ->
            Absent

        Just x ->
            Present x
