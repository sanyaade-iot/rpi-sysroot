(* ::Package:: *)

Begin["System`Convert`BitmapDump`"]


ImportExport`RegisterImport[
  "BMP",
  ImportBMP,
  {
		"Graphics" :> System`ConvertersDump`ElementsToRaster,
		"Image" :> (System`ConvertersDump`GraphicToImage[System`ConvertersDump`ElementsToRaster[Sequence@@getBMPImageElements[##]]]&),
		"Data" :> System`ConvertersDump`ElementsToRasterData,
		"RGBColorArray" :> System`ConvertersDump`ElementsToColorData[RGBColor, Heads -> True],
		"GrayLevels" :> System`ConvertersDump`ElementsToColorData[GrayLevel, Heads -> False],
		"BitDepth" :> ImportBMPBitDepth,
		"ImageCompression" :> ImportBMPCompression
  },
  "FunctionChannels" -> {"Streams"},
  "DefaultElement" -> "Image",
  "Sources" -> ImportExport`DefaultSources["Bitmap"],
  "AvailableElements" -> {
	"BitDepth", "ColorDepth", "ColorMap", "ColorSpace", "Data", "DataType", "Graphics", "GrayLevels",
	"Image", "ImageCompression", "ImageResolution", "ImageSize", "RawData", "RGBColorArray"
  },
  "Options" -> {"DataType", "BitDepth", "ColorSpace", "ImageSize", "HorizontalResolution", "RLECompression", "VerticalResolution"},
  "BinaryFormat" -> True,
  "AlphaChannel" -> True
]


End[]