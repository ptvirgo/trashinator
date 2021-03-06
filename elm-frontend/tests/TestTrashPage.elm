module TestTrashPage exposing (testChangeDay, testChangeVolume, testEntry, testGql, testPage, testRelativeDate, testSetters, testTime, testViewHelpers)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, float, intRange, list, string)
import Graphqelm.Http
import Result
import Test exposing (..)
import Time
import Trash.Enum.Metric exposing (Metric(..))
import Trash.Scalar
import TrashPage.Main
import TrashPage.Model exposing (..)
import TrashPage.Update exposing (..)
import TrashPage.View exposing (..)


testTime : Time.Time
testTime =
    1533006358000


testEntry : TPEntry
testEntry =
    { jwt = Jwt "testing token"
    , date = relativeDate testTime Today
    , metric = Gallons
    , volume = Just 1
    }


testPage : TrashPage
testPage =
    { emptyPage
        | entry = testEntry
        , meta = { timestamp = testTime, error = Nothing, changed = False }
    }



{- Model.elm -}


testRelativeDate : Test
testRelativeDate =
    describe "relativeDate"
        [ test "Today is relatively accurate" <|
            \_ ->
                Expect.equal
                    (relativeDate testTime Today)
                    (Trash.Scalar.Date "2018-07-30")
        , test "Yesterday is relatively accurate" <|
            \_ ->
                Expect.equal
                    (relativeDate testTime Yesterday)
                    (Trash.Scalar.Date "2018-07-29")
        , test "TwoDaysAgo is relatively accurate" <|
            \_ ->
                Expect.equal
                    (relativeDate testTime TwoDaysAgo)
                    (Trash.Scalar.Date "2018-07-28")
        ]


testSetters : Test
testSetters =
    describe "model value setters"
        [ fuzz (intRange 0 10) "setPageVolume applies numeric volume to page" <|
            \i ->
                let
                    x =
                        toFloat i

                    oldEntry =
                        testPage.entry

                    newEntry =
                        { oldEntry | volume = Just x }

                    newPage =
                        { testPage | entry = newEntry }
                in
                Expect.equal (setPageVolume (Just x) testPage) newPage
        , fuzz string "setPageError produces an error message on the page" <|
            \s ->
                let
                    error =
                        Just s

                    oldMeta =
                        testPage.meta

                    newMeta =
                        { oldMeta | error = error }

                    newPage =
                        { testPage | meta = newMeta }
                in
                Expect.equal (setPageError error testPage) newPage
        , test "setPageChanged alters the page.metadata.changed field" <|
            \_ ->
                let
                    oldMeta =
                        testPage.meta

                    newChanged =
                        not oldMeta.changed

                    newMeta =
                        { oldMeta | changed = newChanged }

                    newPage =
                        { testPage | meta = newMeta }
                in
                Expect.equal (setPageChanged newChanged testPage) newPage
        , test "setPageDay alters the page.opts.day field" <|
            \_ ->
                let
                    oldOpts =
                        testPage.opts

                    newOpts =
                        { oldOpts | day = TwoDaysAgo }

                    newPage =
                        { testPage | opts = newOpts }
                in
                Expect.equal (setPageDay TwoDaysAgo testPage) newPage
        ]



{- Update.elm -}


testChangeVolume : Test
testChangeVolume =
    describe "ChangeVolume"
        [ fuzz (intRange 0 10) "ChangeVolume changes the trash volume" <|
            \i ->
                let
                    txt =
                        toString i

                    x =
                        toFloat i

                    newPage =
                        testPage
                            |> setPageVolume (Just x)
                            |> setPageChanged True
                in
                Expect.equal
                    (update (ChangeVolume txt) testPage)
                    ( newPage, Cmd.none )
        , fuzz (intRange -10 -1) "ChangeVolume rejects numbers < 0" <|
            \i ->
                let
                    txt =
                        toString i

                    newPage =
                        testPage
                            |> setPageError (Just "Amount must be 0 or more")
                            |> setPageVolume Nothing
                            |> setPageChanged True
                in
                Expect.equal
                    (update (ChangeVolume txt) testPage)
                    ( newPage, Cmd.none )
        , test "ChangeVolume rejects text strings" <|
            \_ ->
                let
                    newPage =
                        testPage
                            |> setPageError (Just "Amount must be a number")
                            |> setPageVolume Nothing
                            |> setPageChanged True
                in
                Expect.equal
                    (update (ChangeVolume "oops") testPage)
                    ( newPage, Cmd.none )
        , test "ChangeVolume with empty string is Nothing" <|
            \_ ->
                let
                    newPage =
                        testPage
                            |> setPageVolume Nothing
                            |> setPageChanged False
                in
                Expect.equal
                    (update (ChangeVolume "") testPage)
                    ( newPage, Cmd.none )
        ]


testChangeDay : Test
testChangeDay =
    describe "ChangeDay"
        [ test "ChangeDay changes the chosen day" <|
            \_ ->
                let
                    newPage =
                        testPage
                            |> setPageDay TwoDaysAgo
                            |> setPageVolume Nothing

                    ( res, _ ) =
                        update (ChangeDay TwoDaysAgo) testPage
                in
                Expect.equal res newPage
        ]


testGql : Test
testGql =
    describe "GraphQL helpers"
        [ test "gotGqlResponse handles trash = Nothing" <|
            \_ ->
                let
                    newPage =
                        testPage
                            |> setPageVolume Nothing
                            |> setPageError Nothing
                            |> setPageChanged False
                in
                Expect.equal
                    (gotGqlResponse (TrashData Nothing) testPage)
                    newPage
        , fuzz (intRange 0 10) "gotGqlResponse handles trash values" <|
            \i ->
                let
                    x =
                        toFloat i

                    newPage =
                        testPage
                            |> setPageVolume (Just x)
                            |> setPageError Nothing
                            |> setPageChanged False
                in
                Expect.equal
                    (gotGqlResponse (TrashData <| Just { volume = x }) testPage)
                    newPage
        , fuzz3 (intRange 1 10)
            (intRange 1 10)
            (intRange 1 10)
            "gotGqlResponse handles stats"
          <|
            \a b c ->
                let
                    x =
                        toFloat a

                    y =
                        toFloat b

                    z =
                        toFloat c

                    gqlr =
                        { user = { perPersonPerWeek = x }
                        , site = { perPersonPerWeek = y, standardDeviation = z }
                        }

                    newPage =
                        { testPage
                            | stats =
                                { sitePerPersonPerWeek = y
                                , siteStandardDeviation = z
                                , userPerPersonPerWeek = x
                                }
                        }
                in
                Expect.equal (gotGqlResponse (StatsData gqlr) testPage) newPage
        ]


testViewHelpers : Test
testViewHelpers =
    describe "Viewer helpers"
        [ test "capsFirst handles single word" <|
            \_ ->
                Expect.equal (capsFirst "yesterday") "Yesterday"
        , test "capsFirst handles multiple words" <|
            \_ ->
                Expect.equal (capsFirst "two days ago") "Two days ago"
        , test "metricWord uses singular for 1 gallon" <|
            \_ ->
                Expect.equal (metricWord 1 Gallons) "gallon"
        , test "metricWord uses plural for gallons" <|
            \_ ->
                Expect.equal (metricWord 0.5 Gallons) "gallons"
        , test "metricWord uses singular for 1 litre" <|
            \_ ->
                Expect.equal (metricWord 1 Litres) "litre"
        , test "metricWord uses plural for litres" <|
            \_ ->
                Expect.equal (metricWord 2.5 Litres) "litres"
        ]
