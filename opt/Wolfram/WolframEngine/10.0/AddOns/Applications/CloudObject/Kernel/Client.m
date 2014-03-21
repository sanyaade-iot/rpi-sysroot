(* Mathematica package *)
BeginPackage["CloudObject`"]

System`CloudPut;
System`CloudSave;
System`LocalizeDefinitions;
System`CloudGet;
System`CloudSymbol;
System`CloudExport;
System`CloudImport;
System`CloudDeploy;
System`ExportForm;
System`CloudFunction;
System`CloudEvaluate;
System`$Permissions;
System`Permissions;
System`Properties;
System`SetProperties;
System`ClearProperties;

LocalizeDefinitions::usage = "LocalizeDefinitions is an option to Put and CloudPut that specifies \
whether to wrap hidden symbols in a separate context.";

ExportForm::usage = "ExportForm[expr, form] specifies that expr should be exported in the specified format in functions like CloudDeploy, and in external results from APIFunction and FormFunction.";

Permissions::usage = "Permissions is an option for CloudObject and related constructs that specifies permissions for classes of users to access or perform operations."

$Permissions::usage = "$Permissions is the default setting used for the Permissions option when cloud objects are created.";

$UseRemoteServer::usage = "$UseRemoteServer controls whether to use the remote cloud or the local server prototype.";
CloudObject::notauth = "Unable to authenticate with Wolfram Cloud server. Please try authenticating again.";
CloudObject::notperm = "Unable to perform the requested operation. Permission denied.";
CloudObject::unavailable = "The cloud service is not available. Please try again shortly.";
CloudObject::notparam = "Invalid parameters were specified.";
CloudObject::notmethod = "The specified method is not allowed.";
CloudObject::rejreq = "The specified request was rejected by the server.";(*rate limit exceeded, etc*)
CloudObject::srverr = "An unknown server error occurred.";
CloudObject::invperm = "Invalid permissions specification `1`.";
CloudObject::notfound = "No CloudObject found at the given address.";

Begin["`Private`"]

Unprotect[CloudPut, CloudSave, LocalizeDefinitions, CloudGet, CloudSymbol, CloudDeploy, ExportForm, CloudFunction, CloudEvaluate]

$Permissions = "Private";

Unprotect[Put, Save, Export, Get, Import];
  
(*Put*)

cloudSymbolContext = "CloudSymbols`";

definitionsToString[defs_] := StringJoin @ Riffle[Flatten[List @@ Replace[Unevaluated @ defs,
	(HoldForm[symbol_] -> def_) :> (Replace[Unevaluated@def, {
        (Attributes -> attributes_) :> 
            If[Length[attributes] > 0, 
                ToString[Unevaluated[Attributes[symbol] = attributes], InputForm],
                {}
            ],
        (DefaultValues -> options_) :>
            ReplaceAll[options,
        	    (Verbatim[HoldPattern][lhs_] -> rhs_) :> 
                    ToString[Unevaluated[lhs = rhs], InputForm]
            ],
        (Messages -> messages_) :>
            ReplaceAll[messages,
            	(Verbatim[HoldPattern][messagename_] -> message_) :> 
                    ToString[Unevaluated[messagename = message], InputForm]
            ],
        (name_ -> values_) :>
            ReplaceAll[Unevaluated@values, {
                (lhs_ -> rhs_) :> ToString[Unevaluated[lhs = rhs], InputForm],
                (lhs_ :> rhs_) :> ToString[Unevaluated[lhs := rhs], InputForm]
            }]
    }, {1}]), {1}
]], "\n\n"]

(*Prefix all symbols in a definition list (both on the LHS and RHS of rules) with a context:*)
contextifyDefinitions[defs_] := Module[{symbols, newDefs = defs},
    symbols = Cases[defs, (Verbatim[HoldForm][symbol_] -> _) :> Hold[symbol]];
    Quiet[Remove[#] &[cloudSymbolContext <> "*"], {Remove::rmnsm}];
    log["Contextifying symbols `1`", symbols];
    Apply[Function[{symbol}, newDefs = newDefs /. 
        HoldPattern[symbol] :> Evaluate[Symbol[cloudSymbolContext <> ToString[Unevaluated[symbol]]]];, {HoldAll}
    ], symbols, {1}];
    newDefs
]

cleanup[tempfilename_, expr_: Null] := (DeleteFile[tempfilename]; expr)

getRawContents[obj_CloudObject] :=
    responseToFile @ execute[obj]
    
getAPIResult[obj_CloudObject, arguments_] :=
    ToExpression[responseToString @ execute[obj, "GET", "objects", Parameters -> Join[{"view" -> "API", "resultformat" -> "WL"}, arguments]]] 

normalizePermissionsSpec["Read"] = "r";
normalizePermissionsSpec["Write"] = "w";
normalizePermissionsSpec["Execute"] = "x";
normalizePermissionsSpec[list_List] := StringJoin[normalizePermissionsSpec /@ list];
normalizePermissionsSpec[spec_String] :=
    Replace[Characters[spec], {
	    (a : ("r" | "w" | "x")) :> a,
	    invalid_ :> (Message[CloudObject::invperm, invalid]; "")
    }, {1}];
normalizePermissionsSpec[spec_] := (Message[CloudObject::invperm, spec]; {})

normalizePermissions["Public"] := {"All" -> "r", "Owner" -> "rwx"}
normalizePermissions["Private"] := {"Owner" -> "rwx"}
normalizePermissions[list_List] := list /. (user_ -> spec_) :> (user -> normalizePermissionsSpec[spec])
normalizePermissions[spec_String] := normalizePermissions[{"All" -> spec}]
normalizePermissions[Automatic] := normalizePermissions[$Permissions]
normalizePermissions[spec_] := (Message[CloudObject::invperm, spec]; {})

putRawContents[obj_CloudObject, content_, mimetype_, permissions_ : Automatic] := Module[{accessJSON, result},
    accessJSON = toJSON[normalizePermissions[permissions]];
    result = responseToString @ execute[obj, Automatic, UseUUID -> False, Body -> content, Type -> mimetype, Parameters -> {"permissions" -> EscapeURL[accessJSON]}];
    If[result === $Failed, $Failed, obj]
]

expressionMimeType["Expression"] = "application/vnd.wolfram.expression";
expressionMimeType["API"] = "application/vnd.wolfram.expression.api";
expressionMimeType["Form"] = "application/vnd.wolfram.expression.form";
expressionMimeType["NB"] = "application/vnd.wolfram.expression.notebook";
expressionMimeType[_] = "application/vnd.wolfram.expression";
expressionMimeType[] = "application/vnd.wolfram.expression";

Options[CloudPut] = {SaveDefinitions -> False, LocalizeDefinitions -> False, Permissions -> Automatic};

CloudPut[expr_, obj : CloudObject[uri_], type_String : "Expression", OptionsPattern[]] := 
    Module[{defs, content, exprLine, tempfilename},
        If[OptionValue[SaveDefinitions],
        (* save definitions *)
            defs = Language`ExtendedFullDefinition[expr];
            If[OptionValue[LocalizeDefinitions],
            (* localize definitions *)
                AppendTo[defs, 
                    HoldForm[$CloudSymbol] -> {OwnValues -> {HoldPattern[$CloudSymbol] :> 
                        Unevaluated[expr]}}
                ];
                content = definitionsToString[contextifyDefinitions[defs]];
                exprLine = cloudSymbolContext <> "$CloudSymbol";,
            (* do not localize definitions *)
                content = definitionsToString[defs];
                exprLine = ToString[Unevaluated[expr], InputForm];
            ];
            content = content <> "\n\n" <> exprLine <> "\n";
            content = ToCharacterCode[content, "UTF-8"],
        (* do not save definitions *)
            tempfilename = CreateTemporary[];
            Put[Unevaluated[expr], tempfilename];
            content = BinaryReadList[tempfilename];
        ];
        putRawContents[obj, content, expressionMimeType[type], OptionValue[Permissions]]
    ]

CloudPut[expr_, options : OptionsPattern[]] := 
    CloudPut[Unevaluated[expr], CloudObject[], options]

CloudPut[expr_, uri_String, type_String : "Expression", options : OptionsPattern[]] := 
    CloudPut[Unevaluated[expr], CloudObject[uri], type, options]

CloudPut[args___] := (ArgumentCountQ[CloudPut,Length[DeleteCases[{args},_Rule,Infinity]],1,3];Null/;False)

Put[expr_, obj_CloudObject] := CloudPut[Unevaluated[expr], obj]

SetAttributes[CloudPut,{ReadProtected}];
Protect[CloudPut, LocalizeDefinitions];

(*Save*)

Save[obj : CloudObject[uri_], expr_] := Module[{content, tempfilename},
    tempfilename = CreateTemporary[];
    Save[tempfilename, Unevaluated[expr]];
    content = BinaryReadList[tempfilename];
    putRawContents[obj, content, expressionMimeType[]]
]

CloudSave[uri_, expr_] := Save[CloudObject[uri], expr]

CloudSave[expr_] := Save[CloudObject[], expr]

CloudSave[args___] := (ArgumentCountQ[CloudSave,Length[DeleteCases[{args},_Rule,Infinity]],1,2];Null/;False)
(*TODO: deal with HoldAll in CloudSave; prevent evaluation leaks...*)
Attributes[CloudSave] = {HoldAll};

SetAttributes[CloudSave,{ReadProtected}];
Protect[CloudSave];

(*Get*)

Get[co_CloudObject] := Module[{tempfilename, mimetype},
    {tempfilename, mimetype} = getRawContents[co];
    If[tempfilename === $Failed,
        $Failed,
        cleanup[tempfilename, Get[tempfilename]]
    ]
]

CloudGet[uri:(_String|_CloudObject)] := Get[CloudObject[uri]]

CloudGet[args___] := (ArgumentCountQ[CloudSave,Length[DeleteCases[{args},_Rule,Infinity]],1,1];Null/;False)

SetAttributes[CloudGet,{ReadProtected}];
Protect[CloudGet];

(*Import*)

mimeToFormat =
	Quiet[DeleteCases[Flatten @ Map[
	    Function[{format}, Function[{mime}, mime -> format] /@ ImportExport`GetMIMEType[format]], $ExportFormats],
	$Failed], FileFormat::fmterr];

(* Give non-"application/..." types precedence (e.g. image/png should be used instead of application/png). *)
uniqueType[types_List] := First @ SortBy[ToLowerCase /@ types, If[StringMatchQ[#, "application" ~~ __], 2, 1] &]
uniqueType[type_] := uniqueType[{type}]

formatToMime =
	Quiet[Map[# -> (If[Length[#] > 0, uniqueType @ #, "application/octet-stream"] &) @
	    ImportExport`GetMIMEType[#] &, $ExportFormats
	], FileFormat::fmterr];

mimetypeToFormat[type_, filename_: Null] := type /. Join[mimeToFormat, {
	_ -> If[filename =!= Null, FileFormat[filename], "Text"]
}]

formatToMimetype[format_] := format /. Join[formatToMime, {_ -> "application/octet-stream"}]

CloudObject /: Import[co_CloudObject, format_ : Automatic] := 
    Module[{tempfilename, mimetype},
        {tempfilename, mimetype} = getRawContents[co];
        If[tempfilename === $Failed, Return[$Failed]];
        cleanup[tempfilename, 
            Import[tempfilename, 
                If[format === Automatic, mimetypeToFormat[mimetype, tempfilename], format]
            ]
        ]
    ]
    
CloudImport[uri_, format_ : Automatic] := Import[CloudObject[uri], format]

(*Export*)

Options[CloudExport] = {Permissions -> Automatic};

CloudExport[obj : CloudObject[uri_], expr_, format_, rest___Rule] := Module[{tempfilename, content, mimetype},
    tempfilename = CreateTemporary[];
    Export[tempfilename, Unevaluated[expr], format, rest];
    content = BinaryReadList[tempfilename];
    cleanup[tempfilename];
    mimetype = formatToMimetype[format];
    putRawContents[obj, content, mimetype, Quiet[OptionValue[CloudExport, {rest}, Permissions], OptionValue::nodef]]
]

CloudExport[uri_String, expr_, format_, rest___Rule] := 
    CloudExport[CloudObject[uri], Unevaluated[expr], format, rest]
    
CloudExport[expr_, format_, rest___Rule] := 
    CloudExport[CloudObject[], Unevaluated[expr], format, rest]

CloudExport[args___] := (ArgumentCountQ[CloudExport, Length[DeleteCases[{args},_Rule,Infinity]],2,3];Null/;False)

CloudObject /: Export[obj_CloudObject, rest___] := CloudExport[obj, rest]

Protect[Put, Save, Export, Get, Import];

(* CopyFile *)

CloudObject /: CopyFile[src_, obj_CloudObject] := Module[{format, mimetype, content},
    format = FileFormat[src];
    mimetype = formatToMimetype[format];
    content = BinaryReadList[src];
    putRawContents[obj, content, mimetype]
]

CloudObject /: CopyFile[obj_CloudObject, target_] := Module[{tempfilename, mimetype},
    {tempfilename, mimetype} = getRawContents[obj];
    If[tempfilename === $Failed, Return[$Failed]];
    cleanup[tempfilename, CopyFile[tempfilename, target]]
]

CloudObject /: CopyFile[src_CloudObject, target_CloudObject] :=
    Module[{tempfilename, mimetype, content},
        {tempfilename, mimetype} = getRawContents[src];
        If[tempfilename === $Failed, Return[$Failed]];
        content = BinaryReadList[tempfilename];
	    cleanup[tempfilename, putRawContents[target, content, mimetype, "Private"]]
    ]

(* DeleteFile *)

CloudObject /: DeleteFile[co_CloudObject] :=
    responseCheck @ execute[co, "DELETE"]

(*CloudDeploy*)

deployType[_APIFunction] = "API";
deployType[_FormFunction] = "Form";
deployType[_Notebook] = "NB";
deployType[_] := "Expression";

ExportForm[expr_NotebookObject] := ExportForm[expr, "NB"]
ExportForm[expr_Notebook] := ExportForm[expr, "NB"]
ExportForm[expr_Manipulate|expr_Graphics3D] := ExportForm[Notebook[{Cell[BoxData[ToBoxes[expr]], "Output"]}], "NB"]

Options[CloudDeploy] = {Permissions -> Automatic};

CloudDeploy[uri_String | uri_CloudObject, expr_, OptionsPattern[]] := 
    CloudPut[Unevaluated[expr], CloudObject[uri], deployType[Unevaluated[expr]], SaveDefinitions -> True, Permissions -> OptionValue[Permissions]]

CloudDeploy[uri_String | uri_CloudObject, ExportForm[expr_, format_, rest___], OptionsPattern[]] :=
    CloudExport[CloudObject[uri], Unevaluated[expr], format, rest, Permissions -> OptionValue[Permissions]]

CloudDeploy[uri_String | uri_CloudObject, expr_NotebookObject|expr_Notebook|expr_Manipulate|expr_Graphics3D, options : OptionsPattern[]] :=
    CloudDeploy[uri, ExportForm[Unevaluated[expr]], options]

CloudDeploy[expr_, options : OptionsPattern[]] := CloudDeploy[CloudObject[], Unevaluated[expr], options]

CloudDeploy[args___] := (ArgumentCountQ[CloudDeploy,Length[DeleteCases[{args},_Rule,Infinity]],1,2];Null/;False)

SetAttributes[CloudDeploy,{ReadProtected}];
Protect[CloudDeploy];

(* CloudSymbol *)

DownValues[CloudSymbol] = {
    HoldPattern[CloudSymbol[uri_]] :> CloudGet[uri]
};

UpValues[CloudSymbol] = {
    HoldPattern[Set[CloudSymbol[uri_], expr_]] :> (CloudPut[expr, uri]; expr),
    HoldPattern[SetDelayed[CloudSymbol[uri_], expr_]] :> (CloudPut[Unevaluated[expr], uri];)
};

SetAttributes[CloudSymbol,{ReadProtected}];
Protect[CloudSymbol];

(* TODO: override more Set-related operations *)

(*CloudFunction*)

(*CloudFunction stores an expression as an APIFunction in the cloud and executes it (in the cloud).*)
CloudFunction[expr_][args___] := 
    Module[{co},
        Block[{formalargs},
	        co = CloudPut[APIFunction[{{"args", "UnsafeExpression"} -> formalargs}, expr @@ formalargs], SaveDefinitions -> True];
	        If[co === $Failed, Return[$Failed]];
	        getAPIResult[co, {"args" -> EscapeURL[ToString[{args}, InputForm]]}]
        ]
    ]
    
CloudFunction[obj_CloudObject][args___] := CloudFunction[Get[obj]][args]

CloudFunction[args___] := (ArgumentCountQ[CloudFunction,Length[DeleteCases[{args},_Rule,Infinity]],1,1];Null/;False)
(*CloudEvaluate*)

SetAttributes[CloudFunction,{ReadProtected}];
Protect[CloudFunction];

CloudEvaluate[expr_] := CloudFunction[expr &][]

CloudEvaluate[args___] := (ArgumentCountQ[CloudEvaluate,Length[DeleteCases[{args},_Rule,Infinity]],1,1];Null/;False)
(*TODO: deal with HoldAll; prevent evaluation leaks*)
Attributes[CloudEvaluate] = {HoldAll};

SetAttributes[CloudEvaluate,{ReadProtected}];
Protect[CloudEvaluate];

(* Properties *)

Unprotect[SetProperties];

SetProperties[obj_CloudObject, key_String -> value_String] :=
    responseCheck @ execute[obj, "PUT", "files", {"properties", key}, Body -> ToCharacterCode[value, "UTF-8"]]

Protect[SetProperties];

Unprotect[Properties];

Properties[obj_CloudObject] := Module[{content},
    content = responseToString @ execute[obj, "GET", "files", {"properties"}];
    If[content === $Failed, Return[$Failed]];
    If[content === "", Return[{}]];
    ImportString[content, "JSON"]
]

Properties[obj_CloudObject, key_String] :=
    responseToString @ execute[obj, "GET", "files", {"properties", key}]

(* use general Properties[obj] for now because the server API does not return the individual value *)
Properties[obj_CloudObject, key_String] := Replace[key, Join[Properties[obj], {_ :> Missing["Undefined"]}]]

Protect[Properties];

SetAttributes[CloudObject,{ReadProtected}];
Protect[CloudObject]

End[]

EndPackage[]