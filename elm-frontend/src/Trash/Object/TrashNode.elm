-- Do not manually edit this file, it was auto-generated by Graphqelm
-- https://github.com/dillonkearns/graphqelm


module Trash.Object.TrashNode exposing (..)

import Graphqelm.Field as Field exposing (Field)
import Graphqelm.Internal.Builder.Argument as Argument exposing (Argument)
import Graphqelm.Internal.Builder.Object as Object
import Graphqelm.Internal.Encode as Encode exposing (Value)
import Graphqelm.OptionalArgument exposing (OptionalArgument(Absent))
import Graphqelm.SelectionSet exposing (SelectionSet)
import Json.Decode as Decode
import Trash.InputObject
import Trash.Interface
import Trash.Object
import Trash.Scalar
import Trash.Union


{-| Select fields to build up a SelectionSet for this object.
-}
selection : (a -> constructor) -> SelectionSet (a -> constructor) Trash.Object.TrashNode
selection constructor =
    Object.selection constructor


{-| -}
id : Field Trash.Scalar.Id Trash.Object.TrashNode
id =
    Object.fieldDecoder "id" [] (Decode.oneOf [ Decode.string, Decode.float |> Decode.map toString, Decode.int |> Decode.map toString, Decode.bool |> Decode.map toString ] |> Decode.map Trash.Scalar.Id)


{-| -}
date : Field Trash.Scalar.Date Trash.Object.TrashNode
date =
    Object.fieldDecoder "date" [] (Decode.oneOf [ Decode.string, Decode.float |> Decode.map toString, Decode.int |> Decode.map toString, Decode.bool |> Decode.map toString ] |> Decode.map Trash.Scalar.Date)


{-| -}
volume : Field Float Trash.Object.TrashNode
volume =
    Object.fieldDecoder "Volume" [] Decode.float


litres : Field (Maybe Float) Trash.Object.TrashNode
litres =
    Object.fieldDecoder "litres" [] (Decode.float |> Decode.nullable)


gallons : Field (Maybe Float) Trash.Object.TrashNode
gallons =
    Object.fieldDecoder "gallons" [] (Decode.float |> Decode.nullable)
