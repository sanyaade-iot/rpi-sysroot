(* ::Package:: *)

Begin["System`Convert`AudioDump`"]

ImportExport`RegisterImport[
 "MP3",
 ImportAudio["MP3", ##]&,
 {
   (* Post-processors *)
   "Sound" -> ElementsToSound,
   "SampledSoundList" -> ElementsToSampledSoundList,
   "AudioEncoding" -> ElementsToAudioEncoding
 },
 "DefaultElement" -> "Sound",
 "Options" -> {"AudioChannels", "AudioEncoding", "SampleRate"},
 "Sources" -> ImportExport`DefaultSources["Audio"],
 "AvailableElements" -> {"AudioChannels", "Data", "SampledSoundList", "SampleRate", "Sound"},
 "FunctionChannels" -> {"FileNames"},
 "BinaryFormat" -> True
]


End[]