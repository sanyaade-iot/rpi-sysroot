(* ::Package:: *)

Begin["System`Convert`JPEG2000Dump`"]


ImportExport`RegisterImport[
  "JPEG2000",
  { (*Raw Importers*)
	"Tiles":>(grToImage[ImportTileElements[][##]]&),
	{"Tiles", "Elements"} :> ImportTileElements["Elements"],
    {"Tiles", c_Integer} :> (grToImage[ImportTileElements[c][##]]&),
    {"Tiles", c_Integer, "Elements"} :> ImportTileElements[c, "Elements"],
    {"Tiles", c_Integer, r_Integer} :> ImportTile[1][{c, r}],
    {"Tiles", c_Integer, r_Integer, "Elements"} :> TileElements[c, r],
    {"Tiles", c_Integer, r_Integer, "Graphics"} :> ImportTile[1][{c, r}],
    {"Tiles", c_Integer, r_Integer, "Data"} :> ImportTile[2][{c, r}],
	"Graphics" :> ImportJPEG2000[1],
	"Image" :> ({"Image"->System`ConvertersDump`GraphicToImage["Graphics" /. ImportJPEG2000[1][##]]}&),
	"ImageSize" | "BitDepth" | "ColorSpace"|"TileDimensions"|"TileSize"|"Subsampling" :> System`Convert`JPEG2000Dump`getMetadata,
	"Data" :> ImportJPEG2000[2],
	ImportJPEG2000[2]
  },
  { (*Post - Converters*)
	"RGBColorArray" :> System`ConvertersDump`ElementsToColorData[RGBColor, Heads -> True],
	"GrayLevels" :> System`ConvertersDump`ElementsToColorData[GrayLevel, Heads -> False],
	{"Tiles", c_Integer, r_Integer} :> (grToImage[("Graphics" /.(r /.(c /. ("Tiles" /. #))))]&)
  },
  "Options" -> {"BitDepth", "ColorSpace", "ImageSize", "Subsampling", "TileDimensions", "TileSize"},
  "AvailableElements" -> {"BitDepth", "ColorSpace", "Data", "DataType", "Graphics",
			"GrayLevels", "Image", "ImageSize", "RGBColorArray", "Subsampling",
			"TileDimensions", "Tiles", "TileSize"},
  "DefaultElement" -> "Image",
  "Sources" -> {"JLink`", "Convert`JPEG2000`"},
  "BinaryFormat" -> True,
  "AlphaChannel" -> True
]


End[]