(*
 *
 * Copyright (c) 2000 by
 *  George C. Necula	necula@cs.berkeley.edu
 *   
 * All rights reserved.  Permission to use, copy, modify and distribute
 * this software for research purposes only is hereby granted, 
 * provided that the following conditions are met: 
 * 1.  Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimer in the documentation 
 * and/or other materials provided with the distribution. 
 * 3. The name of the authors may not be used to endorse or promote products 
 * derived from  this software without specific prior written permission. 
 *
 * DISCLAIMER:
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR 
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
 * IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *)

(** Utility functions for pretty-printing. The major features provided by 
    this module are 
- An [fprintf]-style interface with support for user-defined printers
- The printout is fit to a width by selecting some of the optional newlines
- Constructs for alignment and indentation
- Print ellipsis starting at a certain nesting depth
- Constructs for printing lists and arrays

 Pretty-printing occurs in two stages:
- Construct a [doc] object that encodes all of the elements to be printed 
  along with alignment specifiers and optional and mandatory newlines
- Format the [doc] to a certain width and emit it as a string, to an output 
  stream or pass it to a user-defined function

 The formating algorithm is not optimal but it does a pretty good job while 
 still operating in linear time. The original version was based on a pretty 
 printer by Philip Wadler which turned out to not scale to large jobs. 
*)

(** API *)


(* I have no idea why ocamldoc misreads my comments on cygwin. I seem to be 
 * able to solve the problem by putting some [a] in some places *)

(** [a] The type of unformated documents. Elements of this type can be 
    constructed in two ways. Either with a number of constructor shown below, 
    or using the [dprintf] function with a [printf]-like interface. The 
    [dprintf] method is slightly slower so we do not use it for large jobs 
    such as the output routines for a compiler. But we use it for small jobs 
    such as logging and error messages. *)
type doc



(** Constructors for the doc type. *)




(** [a]Constructs an empty document *)
val nil          : doc


(** Concatenates two documents. This is an infix operator that associates to 
    the left. *)
val (++)         : doc -> doc -> doc 


(** A document that prints the given string *)
val text         : string -> doc


(** A document that prints an integer in decimal form *)
val num          : int    -> doc


(** A document that prints a character. This is just like [text] 
  * with a one-character string. *)
val chr          : char   -> doc


(** A document that consists of a mandatory newline. This is just like [text 
  * "\n"]. The new line will be indented to the current indentation level, 
  * unless you use [leftflush] right after this. *)
val line         : doc

(** Use after a [line] to prevent the indentation. Whatever follows next will 
  * be flushed left. Indentation resumes on the next line. *)
val leftflush    : doc


(** A document that consists of either a space or a line break. Also called 
  * an optional line break. Such a break will be 
   taken only if necessary to fit the document in a given width. If the break 
   is not taken a space is printed instead. *)
val break: doc

(** Mark the current column as the current indentation level. Does not print 
  * anything. All taken line breaks will align to this column. The previous 
  * alignment level is saved on a stack. *)
val align: doc

(** Reverts to the last saved indentation level. *)
val unalign: doc



(************** Now some syntactic sugar *****************)

(** Indents the document. Same as [text "  " ++ align ++ doc ++ unalign], 
  * with the specified number of spaces. *)
val indent: int -> doc -> doc

(** Formats a sequence

   @param sep A separator
   @param doit A function that converts an element to a document 
   @param elements The list to be converted to a document
 *)
val seq: sep:doc -> doit:('a ->doc) -> elements:'a list -> doc


(** An alternative function for printing a list. The [unit] argument is there 
    to make this function more easily usable with the [dprintf] interface.

   @param sep A separator
   @param doit A function that converts an element to a document 
   @param elements The list to be converted to a document
*)
val docList: sep:doc -> doit:('a -> doc) -> unit -> elements:'a list -> doc

(** Formats an array. 

   @param sep A separator
   @param doit A function that converts an element to a document 
   @param elements The array to be converted to a document
*)
val docArray: sep:doc -> doit:(int -> 'a -> doc) -> unit -> 
              elements:'a array -> doc
 
(** Prints an ['a option] with [None] or [Some] *)
val docOpt: (unit -> 'a -> doc) -> unit -> 'a option -> doc


(** A function that is useful with the [printf]-like interface *)
val insert       : unit -> doc -> doc

(** The next few functions provinde an alternative method for constructing 
    [doc] objects. In each of these functions there is a format string 
    argument (of type [('a, unit, doc) format]; if you insist on 
    understanding what that means see the module [Printf]). The format string 
    is like that for the [printf] function in C, except that it understands a 
    few more formating controls, all starting with the \@ character. 

 The following special formatting characters are understood (these do not 
 correspond to arguments of the function):
-  \@\[ Inserts an [align]. Every format string must have matching 
        [align] and [unalign]. 
-  \@\] Inserts an [unalign].
-  \@!  Inserts a [line]. Just like "\n"
-  \@?  Inserts a [break].
-  \@<  Inserts a [leftflush]. Should be used immediately after \@! or "\n"
-  \@\@ : inserts a \@ character

 In addition to the usual [printf] % formating characters the following two 
 new characters are supported:
- %t Corresponds to an argument of type [unit -> doc]. This argument is 
     invoked to produce a document
- %a Corresponds to {b two} arguments. The first of type [unit -> 'a -> doc] 
     and the second of type {'a}. (The extra [unit] is do to the 
     peculiarities of the built-in support for format strings in Ocaml. It 
     turns out that it is not a major problem.) Here is an example of how 
     you use this:
{v
 
 dprintf "if %a then %a else %a" d_exp e1 d_stmt s2 d_stmt s3
}

 with the following types: {v
e1: expression
d_exp: unit -> expression -> doc
s2: statement
s3: statement
d_stmt: unit -> statement -> doc
}

 Note how the [unit] argument must be accounted for in the user-defined 
 printing functions. 
*)



(** The basic function for constructing a [doc] using format strings

 Example: {v
 dprintf "Name=%s, SSN=%7d, Children=\@\[%a\@\]\n"
             pers.name pers.ssn (docList (chr ',' ++ break) text)
             pers.children
}
*)
val dprintf: ('a, unit, doc) format -> 'a  


(** Next come functions that perform the formating and emit the result *)

(** Format the document to the given width and emit it to the given channel *)
val fprint: out_channel -> width:int -> doc -> unit

(** Format the document to the given width and emit it as a string *)
val sprint: width:int -> doc -> string

(** Formats the [doc] and prints it to the given channel *)
val fprintf: out_channel -> ('a, unit, doc) format -> 'a  

(** Like [fprintf stdout] *)
val printf: ('a, unit, doc) format -> 'a 

(** Like [fprintf stderr] *)
val eprintf: ('a, unit, doc) format -> 'a 

(** Like [dprintf] but more general. It also has a function that is invoked 
  * on the constructed document but before any formating is done. *) 
val gprintf: (doc -> doc) -> ('a, unit, doc) format -> 'a


(** Next few values can be used to control the operation of the printer *)

(** Specifies the nesting depth of the [align]/[unalign] pairs at which 
    everything is replaced with ellipsis *)
val printDepth   : int ref


(** If set to [true] then optional breaks are taken only when the document 
    has exceeded the given width. This means that the printout will looked 
    more ragged but it will be faster *)
val fastMode  : bool ref 

val flushOften   : bool ref  (* If true the it flushes after every print *)

val withPrintDepth : int -> (unit -> unit) -> unit

(** A descrptive string with version, flags etc. *)
val getAboutString : unit -> string
