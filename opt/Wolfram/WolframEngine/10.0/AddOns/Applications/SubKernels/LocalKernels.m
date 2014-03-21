(* :Title: LocalKernels.m -- launch kernels through MathLink on multi-core/multi-processor machines *)

(* :Context: SubKernels`LocalKernels` *)

(* :Author: Roman E. Maeder *)

(* :Copyright: � 2006 by Wolfram Research, Inc. *)

(* :Package Version: 1.0 ($Id: LocalKernels.m,v 1.45 2013/10/26 17:29:22 maeder Exp $) *)

(* :Mathematica Version: 7 *)

(* :History:
   1.0 first released version.
*)

BeginPackage["SubKernels`LocalKernels`", { "SubKernels`" }]
 
Needs["SubKernels`Protected`"]


(* the configuration language. A kernel is described as a LocalMachine[...] data element *)
 
LocalMachine::usage = "LocalMachine[(template), (n), opts...] is a description of n kernels on the local machine.
	The template and options are arguments to LaunchLocal.
		The default template is $mathkernel.
		The default number of kernels is 1.
		LowerPriority->True lowers the kernel's process priority."

$mathkernel::usage = "$mathkernel gives a suitable operating-system command for invoking a local kernel."

(* short forms of kernel descriptions recognized by this implementation:
 	- "localhost"|"local"
 	- n_Integer
 *)
 
 (* options *)
 
 LowerPriority::usage = "LowerPriority->True is an option of LaunchLocal that indicates that the process priority should be below normal."
 
(* class methods and variables *)

localKernelObject::usage = "localKernelObject[method] is the local kernels class object."

(* additional constructors, methods *)

LaunchLocal::usage = "LaunchLocal[template, n, opts] launches n kernels on the local host using LinkLaunch; opts is passed as options to LinkLaunch."

(* options, define LinkProtocol as an option of LaunchLocal so you can set an independent default *)

Options[LaunchLocal] = {
	LinkProtocol -> Automatic,
	KernelSpeed -> 1,
	LowerPriority -> True,
	CallBackLink :> $CallBackLink
}


(* destructor *)

(* the data type is public, for easier subclassing and argument type check *)

localKernel::usage = "localKernel[..] is a local subkernel."

(* remember context now *)

localKernelObject[subContext] = Context[]


Begin["`Private`"]
 
`$PackageVersion = 0.9;
`$CVSRevision = StringReplace["$Revision: 1.45 $", {"$"->"", " "->"", "Revision:"->""}]
 

Needs["ResourceLocator`"]

$packageRoot = DirectoryName[System`Private`$InputFileName]
textFunction = TextResourceLoad[ "SubKernels", $packageRoot]

(* data type:
 	localKernel[ lk[link, arglist, speed] ]
 		link	associated LinkObject
 		arglist	list of arguments used in constructor, so that it may be relaunched if possible
 		speed	speed setting, mutable
 		preemptive the preemptive sharing link connected to this kernel, mutable
 *)
 
SetAttributes[localKernel, HoldAll] (* data type *)
SetAttributes[`lk, HoldAllComplete] (* the head for the base class data *)
 
(* private selectors; pattern is localKernel[ lk[link_, arglist_, speed_, preemptive_, ___], ___ ]  *)
 
localKernel/: linkObject[localKernel[lk[link_, ___], ___]] := link
localKernel/: descr[localKernel[lk[link_, ___], ___]] := "local"
localKernel/: arglist[localKernel[lk[link_, arglist_, ___], ___]] := arglist
localKernel/: kernelSpeed[localKernel[lk[link_, arglist_, speed_, ___], ___]] := speed
localKernel/: setSpeed[localKernel[lk[link_, arglist_, speed_, ___], ___], r_] := (speed = r)
localKernel/: kernelPreemptive[localKernel[lk[link_, arglist_, speed_, preemptive_, ___], ___]] := preemptive
localKernel/: setPreemptive[localKernel[lk[link_, arglist_, speed_, preemptive_, ___], ___], r_] := (preemptive = r)


(* description language methods *)

LocalMachine/: KernelCount[LocalMachine[cmd_String:"", n_Integer:1, opts:OptionsPattern[]]] := n

(* format of description items *)

Format[LocalMachine[cmd_String:"", n_Integer:1, OptionsPattern[]]/;n==1] :=
	StringForm["\[LeftSkeleton]local kernel\[RightSkeleton]"]
Format[LocalMachine[cmd_String:"", n_Integer:1, OptionsPattern[]]/;n>1] :=
	StringForm["\[LeftSkeleton]`1` local kernels\[RightSkeleton]", n]

(* factory method *)

LocalMachine/: NewKernels[LocalMachine[args___], opts:OptionsPattern[]] := LaunchLocal[args, opts]


(* interface methods *)

localKernel/:  subQ[ localKernel[ lk[link_, arglist_, ___] ] ] := Head[link]===LinkObject

localKernel/:  LinkObject[ kernel_localKernel ]  := linkObject[kernel]
localKernel/:  MachineName[ kernel_localKernel ] := descr[kernel]
localKernel/:  Description[ kernel_localKernel ] := LocalMachine@@arglist[kernel]
localKernel/:  Abort[ kernel_localKernel ] := kernelAbort[kernel]
localKernel/:  SubKernelType[ kernel_localKernel ] := localKernelObject
(* KernelSpeed: use generic implementation *)
localKernel/:  PreemptiveLink[ kernel_localKernel ] := kernelPreemptive[kernel]
PreemptiveLink/: (PreemptiveLink[ kernel_localKernel ] = new_) := setPreemptive[kernel, new]

(* kernels should be cloneable; speed setting may have changed after initial launch *)

localKernel/:  Clone[kernel_localKernel] := NewKernels[Description[kernel], KernelSpeed->kernelSpeed[kernel]]


(* list of open kernels *)

`$openkernels = {}

localKernelObject[subKernels] := $openkernels


(* constructors *)

(* default command: look it up at run time, not earlier *)
LaunchLocal[n_Integer, opts:OptionsPattern[]] := LaunchLocal[$mathkernel, n, opts]
LaunchLocal[opts:OptionsPattern[]] := LaunchLocal[$mathkernel, opts]
(* default n is 1 *)
LaunchLocal[cmd_String, opts:OptionsPattern[]] := firstOrFailed[ LaunchLocal[cmd, 1, opts] ]

(* parallel launching *)

LaunchLocal[cmd_String, n_Integer?NonNegative, opts:OptionsPattern[]] :=
	Module[{lnk, lp = OptionValue[LowerPriority]},
        With[{args=Sequence@@Flatten[{cmd, System`Utilities`FilterOptions[LinkLaunch, opts, Options[LaunchLocal]]}]},
          Parallel`Debug`Private`trace[Parallel`Debug`MathLink, "Launching `2` local kernels with `1`", HoldForm[LinkLaunch[args]], n];
          feedbackObject["name", LocalMachine[n], n]; (* more info is not needed *)
          lnk = Table[feedbackObject["tick"]; LinkLaunch[args], {n}];
          Parallel`Debug`Private`trace[Parallel`Debug`MathLink, "Links launched as `1`", lnk];
          lnk = deleteFailed[lnk, LaunchLocal];
        ];
   		lnk = initLink[ lnk, {cmd,opts}, OptionValue[KernelSpeed] ];
   		If[ lp, (* lower process priority *)
   			kernelWrite[#, EvaluatePacket[SetSystemOptions["ProcessPriority" -> -1];]]& /@ lnk;
   			(* no need to wait for reply; the PT constructor will flush the queue *)
   		];
   		If[OptionValue[CallBackLink], (* set up callback link using LinkCreate on master *)
   			createCallBackLink[lnk];
   			(* TODO: remove kernels with failed links *)
   		];
   		lnk
	]

(* destructor; use generic implementation and let it close the link *)

localKernel/: Close[kernel_localKernel?subQ] := (
	$openkernels = DeleteCases[$openkernels, kernel];
	kernelClose[kernel, True]
)


(* handling short forms of kernel descriptions *)

localKernelObject[try]["localhost"|"local", args___] :=
	NewKernels[LocalMachine[], args]

localKernelObject[try][n_Integer?Positive, args___] :=
	NewKernels[LocalMachine[n], args]


(* class name *)

localKernelObject[subName] = textFunction["LocalKernelsName"]


(* raw constructor; several at once *)

initLink[links_List, args_, sp_] :=
 Module[{kernels},
 	(* each kernel gets its own set of variables for the mutable fields *)
 	kernels = Module[{speed=sp, preemptive=$Failed}, localKernel[ lk[#, args, speed, preemptive] ]]& /@ links;
 	(* local init *)
 	$openkernels = Join[$openkernels, kernels];
 	(* base class init *)
 	kernelInit[kernels]
 ]

(* single one *)

initLink[link_, args__] := firstOrFailed[ initLink[{link}, args] ]


(* config *)

(* persistent config is of the form of a list of rules *)

`config

config[configQ] = True
config[nameConfig] = localKernelObject[subName]


(* new style *)

{auto=True, uselic=True, nconf=$ProcessorCount, lowerprio=True, mk}

confDefaults = {"Automatic"->True, "UseLicense"->True, "Manual"->0, "LowerPriority"->True}

config[setConfig] := config[setConfig, {}]
config[setConfig, r:{___Rule}] := (
	{auto, uselic, nconf, lowerprio} = {"Automatic", "UseLicense", "Manual", "LowerPriority"} /. r /. confDefaults;
)

(* safety net *)
config[setConfig, __] := config[setConfig, {}]


(* serialize, generate only non-default rules *)

config[getConfig] := Module[{rules={}},
	If[auto=!=("Automatic" /. confDefaults), AppendTo[rules, "Automatic"->auto]];
	If[uselic=!=("UseLicense" /. confDefaults), AppendTo[rules, "UseLicense"->uselic]];
	If[nconf=!=("Manual" /. confDefaults), AppendTo[rules, "Manual"->nconf]];
	If[lowerprio=!=("LowerPriority" /. confDefaults), AppendTo[rules, "LowerPriority"->lowerprio]];
    rules
]

calcAuto[] := If[uselic, Min[$ProcessorCount, $MaxLicenseSubprocesses], $ProcessorCount] /. 1->0

config[useConfig] := Which[
	auto,		If[calcAuto[]>0, LocalMachine[calcAuto[], LowerPriority->lowerprio], {}],
	nconf>0,	{LocalMachine[nconf, LowerPriority->lowerprio]},
	True,		{}
]

config[tabConfig] := Module[{},
	Grid[{
		{Row[{textFunction["LocalKernelsNumber"], Invisible[Checkbox[]], Invisible[RadioButton[]]}], SpanFromLeft},
		{RadioButton[Dynamic[auto], True], Dynamic[StringForm[textFunction["LocalKernelsAutomatic"], calcAuto[]]]},
		{Null, Dynamic[StringForm[textFunction["LocalKernelsProcessorCores"], $ProcessorCount]]},
		{Null, Row[{Checkbox[Dynamic[uselic]], Dynamic[StringForm[textFunction["LocalKernelsLicenseAvailability"], $MaxLicenseSubprocesses]]}]},
		{Null, Dynamic[If[$ProcessorCount==1,Pane[textFunction["LocalKernelsLicenseSingle"]],""]]},
		{RadioButton[Dynamic[auto], False], Row[{textFunction["LocalKernelsManual"], " ", Spinner[Dynamic[nconf], Enabled->Dynamic[!auto]]}], SpanFromLeft},
		{Checkbox[Dynamic[lowerprio]], textFunction["LowerPriority"]}
	}, ItemSize->{Full,1}, Alignment->{Left,Baseline}]
]

localKernelObject[subConfigure] = config; (* configure class method *)


(* class variable defaults *)
 
sf[s_String] := StringReplace[s, " " -> "\\ "] (* escape spaces *)
dqs[s_String] := "\"" <> s <> "\"" (* double quote string *)
sqs[s_String] := "'" <> s <> "'" (* single quote string *)

If[ !ValueQ[$mathkernel], $mathkernel = Which[
	$OperatingSystem==="Windows", dqs[ToFileName[{$InstallationDirectory}, "MathKernel"]] <> stdargs <> " -mathlink -noicon",
	$OperatingSystem==="MacOSX", sqs[ToFileName[{$InstallationDirectory, "Contents", "MacOS"}, "MathKernel"]] <> stdargs <> " -mathlink",
	True, sf[ToFileName[{$InstallationDirectory, "Executables"}, "math"]] <> stdargs <> " -mathlink"
]]

(* format of kernels *)

setFormat[localKernel, "local"]

End[]

Protect[ LaunchLocal, LocalMachine, localKernelObject, localKernel ]

(* registry *)
addImplementation[localKernelObject]

EndPackage[]