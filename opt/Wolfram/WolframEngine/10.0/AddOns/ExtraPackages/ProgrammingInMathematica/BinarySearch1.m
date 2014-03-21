(* :Title: BinarySearch1 *)


(* :Context: ProgrammingInMathematica`BinarySearch1` *)

(* :Author: Roman E. Maeder *)

(* :Summary:
   An example of the basic binary search method
 *)

(* :Copyright: � 1989-1996 by Roman E. Maeder *)

(* :Package Version: 2.0 *)

(* :Mathematica Version: 3.0 *)

(* :History:
   2.0 for Programming in Mathematica, 3rd ed.
   1.1 for Programming in Mathematica, 2nd ed.
   1.0 for Programming in Mathematica, 1st ed.
*)

(* :Keywords: binary search, Break *)

(* :Sources:
   Roman E. Maeder. Programming in Mathematica, 3rd ed. Addison-Wesley, 1996.
*)

(* :Discussion:
   See Section 5.4 of "Programming in Mathematica"
*)

BinarySearch::usage = "BinarySearch[list, elem] finds the position of elem
	in the sorted list. If elem does not accur in list, 0 is returned."

BinarySearch[list_, elem_] :=
	Module[{n0 = 1, n1 = Length[list], m},
		While[n0 <= n1,
			m = Floor[(n0 + n1)/2];
			If[ list[[m]] == elem, Break[] ]; (* found *)
			If[ list[[m]] < elem, n0 = m+1, n1 = m-1 ]
		];
		If[ n0 > n1, 0, m ]
	]