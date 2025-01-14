{-# LANGUAGE DeriveGeneric #-}

module Parser.DrawIO where

import qualified Data.Text as DT
import qualified Data.Text.Lazy as DTL
import qualified Text.Taggy.DOM as TTD
import qualified Text.Taggy.Renderer as TTR
import qualified Text.Taggy.Parser as TTP
import Text.Regex.Posix ((=~~))
import qualified Data.HashMap.Strict as DHS
import qualified Text.Read as TR
import qualified Data.Attoparsec.Text as DAT
import qualified Graphics.Svg.PathParser as GSP
import qualified Graphics.Svg.Types as GST
import qualified Linear.V2 as LV
import qualified Data.Aeson as DAS
import qualified GHC.Generics as GGN
import qualified Data.Text.Lazy.Encoding as DTLE

data Output
    = Container [Output]
    | Translate Float Float [Output]
    | Path [PathCommand]
    | Rect Float Float Float Float 
    | Ellipse Float Float Float Float
--    | Dot Float Float Float Float
    | Text DT.Text
    | Metadata [KindMetadata]
    | Empty
    deriving (Show)

data PathCommand
    = AbsM [GST.RPoint]
    | AbsL [GST.RPoint]
    | RelM [GST.RPoint]
    | RelL [GST.RPoint]
    | Z
    | UnsupportedPathCommand
    deriving (Show)

data KindMetadata
    = KindMetadata
        { kindName :: !DT.Text
        , repo :: !DT.Text
        , ref :: !DT.Text
        , dir :: !DT.Text
        , file :: !DT.Text
        } deriving (Show, GGN.Generic)

instance DAS.FromJSON KindMetadata
instance DAS.ToJSON KindMetadata

parseSVG :: DT.Text -> DT.Text
parseSVG input = output
  where
    nodes = TTD.domify $ TTP.taggyWith True (DTL.fromStrict input)
    collapsed = collapseEmpty $ Container $ map (collapseEmpty . parseNode) nodes
    output = lispify collapsed

wrapInParens :: [DT.Text] -> DT.Text
wrapInParens content = DT.concat ["(", DT.intercalate " " content, ")"]

showToText :: (Show a) => a -> DT.Text
showToText = DT.pack . show

lispify :: Output -> DT.Text
lispify (Container children) = wrapInParens $ map lispify children
lispify (Translate x y children) = wrapInParens ["translate", wrapInParens [showToText x, showToText y], wrapInParens $ map lispify children]
lispify (Path commands)
  -- We assume a heptagon as a speech bubble, as a speech bubble has 7 sides. It's 8 because
  -- we need to count the trailing 'Z'.
  | length commands == 8 = wrapInParens ("speechbubble" : map lispifyPathCommand commands)
  | otherwise = wrapInParens ("line" : map lispifyPathCommand commands)
lispify (Rect x y w h) = wrapInParens ["rect", showToText x, showToText y, showToText w, showToText h]
lispify (Ellipse cx cy rx ry) = wrapInParens ["ellipse", showToText cx, showToText cy, showToText rx, showToText ry]
-- lispify (Dot cx cy rx ry) = wrapInParens ["dot", showToText cx, showToText cy, showToText rx, showToText ry]
lispify (Metadata md) = wrapInParens ["metadata", showToText (DAS.encode md)]
lispify (Text t) = DT.concat ["\"", t, "\""]
lispify Empty = ""

lispifyPathCommand :: PathCommand -> DT.Text
lispifyPathCommand (AbsM points) = lispifyPoints points "absm"
lispifyPathCommand (AbsL points) = lispifyPoints points "absl"
lispifyPathCommand (RelM points) = lispifyPoints points "relm"
lispifyPathCommand (RelL points) = lispifyPoints points "rell"
lispifyPathCommand Z = "(Z)"
lispifyPathCommand UnsupportedPathCommand = ""

lispifyPoints :: [GST.RPoint] -> DT.Text -> DT.Text
lispifyPoints points tag = wrapInParens (tag : concat (map go points))
  where
    go (LV.V2 x y) = map DT.pack [show x, show y]

collapseEmpty :: Output -> Output
collapseEmpty (Container [x, Container []]) = collapseEmpty x
collapseEmpty (Container (Empty : xs)) = collapseEmpty $ Container (map collapseEmpty xs)
collapseEmpty (Container (x : Empty : xs)) = Container (collapseEmpty x : map collapseEmpty xs)
collapseEmpty (Container (Container [] : xs)) = Container $ map collapseEmpty xs
collapseEmpty (Container [x]) = collapseEmpty x
collapseEmpty (Container (x : Container [] : xs)) = Container (x : map collapseEmpty xs)
collapseEmpty (Container xs) = Container $ map collapseEmpty xs
collapseEmpty (Translate x y zs) = Translate x y $ map collapseEmpty zs
collapseEmpty x = x

parseNode :: TTD.Node -> Output
parseNode (TTD.NodeContent content) =
    let
      handleUnparsedNodeContent (TTD.NodeContent text) =
        case DT.strip text of
          "" -> Empty
          t ->
            -- Tag as metadata if in JSON format.
            case (DAS.eitherDecode (DTLE.encodeUtf8 $ DTL.fromStrict t) :: Either String [KindMetadata]) of
              Left _ -> Text t
              Right md -> Metadata md
      handleUnparsedNodeContent element = parseNode element
    in
      Container $ map handleUnparsedNodeContent $ TTD.parseDOM False $ DTL.fromStrict content
parseNode (TTD.NodeElement (TTD.Element { TTD.eltName = name, TTD.eltAttrs = attrs, TTD.eltChildren = children })) =
    let
      rest = map parseNode children
      defaultOutput = Container rest
      lookupAttrIntoString key = fmap DT.unpack (DHS.lookup key attrs) :: Maybe String
      readFloat = maybe 0.0 id . TR.readMaybe :: String -> Float
      readInt = maybe 0 id . TR.readMaybe :: String -> Int
    in
      case name of
        -- Pass through
        "div" -> Container rest
        -- Pass through
        "span" -> Container rest
        "g" ->
          let
            result = do
              source <- lookupAttrIntoString "transform"
              let regexp = "translate\\(([-.0-9]+),([-.0-9]+)\\)" :: String
              (_, _, _, [x, y]) <- (source =~~ regexp :: Maybe (String, String, String, [String]))
              return (readFloat x, readFloat y)
          in
            maybe defaultOutput (\(x, y) -> Translate x y rest) result
        "text" ->
          let
            result = do
              x <- lookupAttrIntoString "x"
              y <- lookupAttrIntoString "y"
              return (readFloat x, readFloat y)
          in
            maybe defaultOutput (\(x, y) -> Translate x y rest) result
        "path" ->
          let
            handleParse (DAT.Done _ r) = Just $ mapPathCommands r
            handleParse (DAT.Fail _ _ _) = Nothing
            handleParse (DAT.Partial cont) = handleParse $ cont ""
            result = DHS.lookup "d" attrs >>= handleParse . DAT.parse GSP.pathParser
          in
            maybe defaultOutput Path result
        "rect" ->
          let
            result = do
              x <- lookupAttrIntoString "x"
              y <- lookupAttrIntoString "y"
              width <- lookupAttrIntoString "width"
              height <- lookupAttrIntoString "height"
              return (Rect (readFloat x) (readFloat y) (readFloat width) (readFloat height))
          in
            maybe defaultOutput id result
        "ellipse" ->
          let
            result = do
              cx <- lookupAttrIntoString "cx"
              cy <- lookupAttrIntoString "cy"
              rx <- lookupAttrIntoString "rx"
              ry <- lookupAttrIntoString "ry"
	      return (Ellipse (readFloat cx) (readFloat cy) (readFloat rx) (readFloat ry))
--              if rx == ry
--                then return (Dot (readFloat cx) (readFloat cy) (readFloat rx) (readFloat ry))
--                else return (Ellipse (readFloat cx) (readFloat cy) (readFloat rx) (readFloat ry))
          in
            maybe defaultOutput id result
        "foreignObject" -> collapseEmpty $ Container rest
        "switch" ->
          case rest of
            [] -> Empty
            (x:_) -> x
        _ -> defaultOutput

mapPathCommands :: [GST.PathCommand] -> [PathCommand]
mapPathCommands = map go
  where
    go (GST.MoveTo origin points) =
      case origin of
        GST.OriginAbsolute -> AbsM points
        GST.OriginRelative -> RelM points
    go (GST.LineTo origin points) =
      case origin of
        GST.OriginAbsolute -> AbsL points
        GST.OriginRelative -> RelL points
    go (GST.HorizontalTo origin coords) = UnsupportedPathCommand
    go (GST.VerticalTo origin coords) = UnsupportedPathCommand
    go (GST.CurveTo _ _) = UnsupportedPathCommand
    go (GST.SmoothCurveTo _ _) = UnsupportedPathCommand
    go (GST.QuadraticBezier _ _) = UnsupportedPathCommand
    go (GST.SmoothQuadraticBezierCurveTo _ _) = UnsupportedPathCommand
    go (GST.EllipticalArc _ _) = UnsupportedPathCommand
    go GST.EndPath = Z
