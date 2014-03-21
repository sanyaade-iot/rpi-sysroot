(* :Title: Paclet.m *)

(* :Author:
        Todd Gayley
        tgayley@wolfram.com
*)

(* :Package Version: 2.2 *)

(* :Mathematica Version: 8.1 *)

(* :Copyright: Mathematica source code (c) 1999-2013, Wolfram Research, Inc. All rights reserved. *)

(* :Discussion: This file is a component of the PacletManager Mathematica source code. *)


Begin["`Package`"]

PCinitialize
PCwrite
PCrebuild

PCfindMatching
PCfindForDocResource


$extraPacletDirs


End[]  (* `Package` *)


(* Current context will be PacletManager`. *)

Begin["`Collection`Private`"]

$pacletsPersistentFile

$userPacletCollection
$layoutPacletCollection
$legacyPacletCollection
$extraPacletCollection


(* Change this when you modify the serialization format of pacletData.pmd2. 
   Change from 1 to 2 corresponded to adding the hash of the Repository dir to the end of the file.
*)
$serializationVersion = 2;

(*****************************  Initialization  ******************************)

(* This is intended to only be called once in a "normal" session. It's not an error to call it more than once, but this is
   not a function that gets called to implement something like RebuildPacletData[]. (It _is_ called to implement
   RestartPacletManager[].)
*)

PCinitialize[freshStart:(True | False)] :=
    executionProtect @
    Module[{foundFile, strm, serVersion, pc, oldHash, newHash, lockFile},
        (***** Try to read from serialized file. *****)
        (* Because the persistent file depends on paclets in the layout, it must distinguish
           between different installation directories.
        *)
        $pacletsPersistentFile = ToFileName[$userConfigurationDir, "pacletData" <> "_" <>
                                             If[TrueQ[Developer`ProtectedMode[]], "p_", ""] <>
                                               getKernelVersionString[] <> "_" <>
                                                ToString[Hash[$InstallationDirectory]] <> ".pmd2"];
        foundFile = FileExistsQ[$pacletsPersistentFile] && !freshStart;
        If[foundFile,
            lockFile = ToFileName[$userTemporaryDir, FileNameTake[$pacletsPersistentFile] <> ".lock"];
            (* Writes might take a while, so long wait time before going ahead and forcefully acquiring the lock. *)
            If[acquireLock[lockFile, 3, True],
                using[{strm = OpenRead[$pacletsPersistentFile, DOSTextFormat -> False]},
                    serVersion = Read[strm, Expression];
                    If[serVersion <= $serializationVersion,
                        (* $legacyPacletCollection and $extraPacletCollection are never serialized. *)
                        pc = Read[strm, Expression];
                        If[ListQ[pc], $userPacletCollection = pc];
                        pc = Read[strm, Expression];
                        If[ListQ[pc], $layoutPacletCollection = pc];
                    ];
                    (* Newer versions of the file have an extra expression at the end: a hash of the paclet names in the
                       repository. If this is different from the last time it was written, force a rebuild. This
                       allows us to pick up new paclets that were installed by other instances of Mathematica that
                       share this repository.
                    *)
                    If[serVersion === $serializationVersion,
                        oldHash = Read[strm, Expression];
                        If[IntegerQ[oldHash],
                            newHash = Hash[FileNames["*", $userRepositoryDir]];
                            If[newHash =!= oldHash,
                                (* Setting this to a non-list value forces a rebuild below. *)
                                $userPacletCollection=.
                            ]
                        ]
                    ]                    
                ];
                releaseLock[lockFile]
            ]
        ];

        (* $extraPacletDirs does not survive a RestartPacletManager[]. *)
        $extraPacletDirs = {};

        If[!foundFile || !ListQ[$userPacletCollection] || !ListQ[$layoutPacletCollection],
            (* Will get here if no file found, or couldn't be opened, or had bad ser version, or had bad data. *)
             PCrebuild["Collections" -> {"User", "Layout"}];
             PCwrite[]
        ];

        (* legacy and extra collections are always built from PI files. *)
        PCrebuild["Collections" -> {"Legacy", "Extra"}];

        initializeLayoutDocsCollection[ToFileName[{$InstallationDirectory, "Documentation"}]];
        (* Unused:
        initializeDownloadedDocsCollection[ToFileName[$userRepositoryDir, "SystemDocumentation"]];
        *)

        (* Never get past here without these being meaningful exprs. *)
        Assert[ListQ[$userPacletCollection] && ListQ[$layoutPacletCollection]
                   && ListQ[$legacyPacletCollection] && ListQ[$extraPacletCollection]];
    ]



(*********************************  PCwrite  *********************************)

PCwrite[] /; $pmMode =!= "ReadOnly" := 
    executionProtect @
    Module[{strm, lockFile, hash},
        lockFile = ToFileName[$userTemporaryDir, FileNameTake[$pacletsPersistentFile] <> ".lock"];
        hash = Hash[FileNames["*", $userRepositoryDir]];
        (* This might be a long write, so long wait time before going ahead and forcefully acquiring the lock. *)
        If[acquireLock[lockFile, 3, True],
            using[{strm = OpenWrite[$pacletsPersistentFile, DOSTextFormat->False]},
                Write[strm, $serializationVersion];
                Write[strm, $userPacletCollection];
                Write[strm, $layoutPacletCollection];
                Write[strm, hash]
            ];
            releaseLock[lockFile]
        ]
    ]


(********************************  PCrebuild  ******************************)

Options[PCrebuild] = {"UserRepositoryDir" -> Automatic, "SharedRepositoryDir" -> Automatic, "SystemPacletDirs" -> Automatic,
                            "ApplicationDirs" -> Automatic, "Collections" -> All}

PCrebuild[OptionsPattern[]] :=
    executionProtect @
    Module[{userRepositoryDir, sharedRepositoryDir, sysPacletDirs, appDirs, collections, lockFile},
        log[1, "Rebuilding"];
        {userRepositoryDir, sharedRepositoryDir, sysPacletDirs, appDirs, collections} =
              OptionValue[{"UserRepositoryDir", "SharedRepositoryDir", "SystemPacletDirs", "ApplicationDirs", "Collections"}];
        collections = Flatten[{collections}];
        (* Eliminate any attempts to use disallowed locations if in sandbox. *)
        If[Developer`ProtectedMode[],
            If[collections === All,
                collections = {"User", "Layout", "LayoutDocs", "DownloadedDocs"},
            (* else *)
                collections = DeleteCases[collections, "Extra" | "Legacy"]
            ]
        ];
        If[collections === {All} || MemberQ[collections, "User"],
            lockFile = ToFileName[$userTemporaryDir, "repository.lock"];
            (* Wait a second to get the lock, but walk away if it can't be acquired. Not that big a deal if we can't write
               the data. If the lock is being held, then some other process is probably writing it anyway.
            *)
            If[!acquireLock[lockFile, 2, False],
                Message[RebuildPacletData::lock];
                Return[False]
            ];
            (* Use depth 3 to allow paclets like:
                   FooPaclet-1.0.0/
                       FooPaclet/
                           PacletInfo.m
               in addition to:
                   FooPaclet-1.0.0/
                       PacletInfo.m
                           FooPaclet/
            *)
            $userPacletCollection = createPacletsFromParentDirs[{
                                             If[userRepositoryDir === Automatic, $userRepositoryDir, userRepositoryDir],
                                             If[sharedRepositoryDir === Automatic, $sharedRepositoryDir, sharedRepositoryDir]},
                                             3
                                      ];
            releaseLock[lockFile]
        ];
        If[collections === {All} || MemberQ[collections, "Layout"],
            $layoutPacletCollection = createPacletsFromParentDirs[
                                             If[sysPacletDirs === Automatic, systemPacletDirs[], sysPacletDirs],
                                             2
                                      ]
        ];
        If[collections === {All} || MemberQ[collections, "Legacy"],
            $legacyPacletCollection = createPacletsFromParentDirs[
                                             If[appDirs === Automatic, applicationDirs[], appDirs],
                                             2
                                      ]
        ];
        If[collections === {All} || MemberQ[collections, "Extra"],
            $extraPacletCollection = createPacletsFromParentDirs[$extraPacletDirs, 2]
        ];
        (* TODO: Sanity check, issue messages, etc. ? *)
    ]


(**********************************  PCfindMatching  *************************************)

(*
     Find paclets in this collection that match specified criteria.
     Result is an unsorted list of Paclet[...].
*)

Options[PCfindMatching] =
    {"Name" -> All, "Version" -> All, "Qualifier" -> All, "SystemID" -> Automatic, "MathematicaVersion" -> Automatic,
     "Context" -> All, "Extension" -> All, "Location" -> All, "Internal" -> All, "Creator" -> All, "Publisher" -> All,
     "Collections" -> {"User", "Layout", "Legacy", "Extra" (* The other values are "LayoutDocs", "DownloadedDocs" *)},
     "Language" -> All, (* Language is weird here, as it is not a top-level field in paclets. But for searches into
                          the layoutdocs collection, it might be useful. Not used by any internal PM features, though. *)
     "Paclets" -> Null}

PCfindMatching[OptionsPattern[]] :=
    Module[{pc, selectFunc, name, qualifier, version, systemID, mVersion, context, extension,
              location, internal, creator, publisher, collections, paclets, result},
        {name, version, qualifier, systemID, mVersion, context, extension,
           location, internal, creator, publisher, collections, paclets} =
               OptionValue[{"Name", "Version", "Qualifier", "SystemID", "MathematicaVersion", "Context", "Extension",
                              "Location", "Internal", "Creator", "Publisher", "Collections", "Paclets"}];
        selectFunc = Hold[];
        (* Put tests that cull heavily in speed-critical lookups at the start. This is so that short-circuit evaluation
           can prevent later tests from being called at all. A good example is context lookups--most paclets will fail
           this first test, and we therefore avoid testing their MVersion.
        *)
        If[context =!= All,
            (* PhasContext will search for a parent context, so if the requested context is Foo`Bar`, we will
               find paclets that announce Foo`.
            *)
            With[{context = context}, selectFunc = Join[selectFunc, Hold[PhasContext[#, context]]]]
        ];
        If[extension =!= All,
            With[{extension = Alternatives @@ Flatten[{extension}]}, selectFunc = Join[selectFunc, Hold[Length[PgetExtensions[#, extension]] > 0]]]
        ];
        If[name =!= All,
            With[{name = name}, selectFunc = Join[selectFunc, Hold[StringMatchQ[getPIValue[#, "Name"], name]]]]
        ];
        If[qualifier =!= All,
            With[{qualifier = qualifier}, selectFunc = Join[selectFunc, Hold[getPIValue[#, "Qualifier"] === qualifier]]]
        ];
        If[version =!= All && version =!= "",
            With[{version = version}, selectFunc = Join[selectFunc, Hold[StringMatchQ[getPIValue[#, "Version"], version]]]]
        ];
        If[systemID === Automatic, systemID = $SystemID];
        If[systemID =!= All,
            With[{systemID = systemID}, selectFunc = Join[selectFunc, Hold[systemIDMatches[systemID, getPIValue[#, "SystemID"]]]]]
        ];
        If[mVersion === Automatic, mVersion = getKernelVersionStringComplete[]];
        If[mVersion =!= All,
            With[{mVersion = mVersion}, selectFunc = Join[selectFunc, Hold[kernelVersionMatches[mVersion, getPIValue[#, "MathematicaVersion"]]]]]
        ];
        If[internal =!= All,
            With[{internal = internal}, selectFunc = Join[selectFunc, Hold[getPIValue[#, "Internal"] === internal]]]
        ];
        If[location =!= All,
            With[{location = location}, selectFunc = Join[selectFunc, Hold[PgetLocation[#] === location]]]
        ];
        (* TODO: Other criteria for selection. *)
        Which[
            ListQ[paclets],
                pc = paclets,
            collections === All,
                pc = Join[$userPacletCollection, $layoutPacletCollection, $legacyPacletCollection, $extraPacletCollection],
            True,
                pc = Join[
                        If[MemberQ[collections, "User"], $userPacletCollection, {}],
                        If[MemberQ[collections, "Layout"], $layoutPacletCollection, {}],
                        If[MemberQ[collections, "Legacy"], $legacyPacletCollection, {}],
                        If[MemberQ[collections, "Extra"], $extraPacletCollection, {}]
                     ]
        ];
        (* TODO: Don't I want to make older versions of a paclet completely shadowed by newer ones? *)
        result = Select[pc, Function[{heldSelectFunc}, Function[Null, And @@ heldSelectFunc] ] @ selectFunc];

        (* LayoutDocsCollection is quite different from others and must be handled separately. *)
        If[MemberQ[collections, "LayoutDocs"] && paclets === Null && context === All && qualifier === All &&
              kernelVersionMatches[mVersion] && (extension === All || MemberQ[Flatten[{extension}], "Documentation"]) &&
                 internal =!= True && creator === All && publisher === All && location === All,
            result = result ~Join~ LDCfindMatching[name, version, OptionValue["Language"]]
        ];

        result
    ]


(*******************************  PCfindForDocResource  ********************************)

(* Returns a list of {paclet, docPath} of paclets that are known to contain an existing file
   corresponding to this resource. Disabled paclets have been dropped, and only the highest version number
   of each like-named paclet is represented. Empty list if no matches.

   Does not fall through to English if requested language is not found.

   TODO: Is there any good reason this returns a list instead of just the best one? (First member of the list).
   Perhaps when there are server paclets involved, a list will be useful for callers to have more info, but
   I think there will still be no reason not to pick just one here.
*)

Options[PCfindForDocResource] =
    {"LinkBase" -> All, "Context" -> All, "ResourceName" -> All, "Language" -> "English"}

PCfindForDocResource[opts:OptionsPattern[]] :=
    Module[{linkBase, context, expandedResourceName, language},

        {linkBase, context, expandedResourceName, language} =
             OptionValue[{"LinkBase", "Context", "ResourceName", "Language"}];

        Assert[MatchQ[linkBase, _String | All]];  (* Typically, "WolframMathematica" *)
        Assert[MatchQ[context, _String | All]];   (* All, unless we are looking up a message URI. *)
        Assert[MatchQ[expandedResourceName, _String | All]];  (* e.g. "Guides/foo", or All if looking for a root guide page. *)
        Assert[MatchQ[language, _String]];  (* Desired language must be a string, never All *)
        (* Lookups are either linkbase-based or context-based. *)
        Assert[linkBase === All || context === All];

        (* Search among all collections.

           Note that we do no checking here to first decide if a paclet has a chance of being found in any
           given collection--we just blindly propagate the find request to all collections. Leave
           all optimization logic to the collections themselves.
        *)
        Join[
            LDCfindForDocResource[linkBase, context, expandedResourceName, language],
            (* Unused:
            DDCfindForDocResource[linkBase, context, expandedResourceName, language],
            *)
            MCfindForDocResource[$layoutPacletCollection, linkBase, context, expandedResourceName, language],
            MCfindForDocResource[$userPacletCollection, linkBase, context, expandedResourceName, language],
            MCfindForDocResource[$legacyPacletCollection, linkBase, context, expandedResourceName, language],
            MCfindForDocResource[$extraPacletCollection, linkBase, context, expandedResourceName, language]
        ]
        (* Drop disabled and sort by version number. *)
        // Select[#, isEnabled[First[#]]&]&
        // Sort[#, versionGreater[getPIValue[First[#1], "Version"], getPIValue[First[#2], "Version"]]&]&
    ]


End[]
