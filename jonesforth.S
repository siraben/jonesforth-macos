/*	A sometimes minimal FORTH compiler and tutorial for macOS / AArch64 (Apple Silicon) systems. -*- asm -*-
	Originally by Richard W.M. Jones <rich@annexia.org> http://annexia.org/forth
	Adapted for macOS AArch64 by Ben Siraphob using LLMs.
	This is PUBLIC DOMAIN (see public domain release statement below).

	clang -o jonesforth jonesforth.S
*/
	.set JONES_VERSION,47
/*
	INTRODUCTION ----------------------------------------------------------------------

	FORTH is one of those alien languages which most working programmers regard in the same
	way as Haskell, LISP, and so on.  Something so strange that they'd rather any thoughts
	of it just go away so they can get on with writing this paying code.  But that's wrong
	and if you care at all about programming then you should at least understand all these
	languages, even if you will never use them.

	LISP is the ultimate high-level language, and features from LISP are being added every
	decade to the more common languages.  But FORTH is in some ways the ultimate in low level
	programming.  Out of the box it lacks features like dynamic memory management and even
	strings.  In fact, at its primitive level it lacks even basic concepts like IF-statements
	and loops.

	Why then would you want to learn FORTH?  There are several very good reasons.  First
	and foremost, FORTH is minimal.  You really can write a complete FORTH in, say, 2000
	lines of code.  I don't just mean a FORTH program, I mean a complete FORTH operating
	system, environment and language.  You could boot such a FORTH on a bare PC and it would
	come up with a prompt where you could start doing useful work.  The FORTH you have here
	isn't minimal and uses a macOS process as its 'base PC' (both for the purposes of making
	it a good tutorial). It's possible to completely understand the system.  Who can say they
	completely understand how macOS works, or clang?

	Secondly FORTH has a peculiar bootstrapping property.  By that I mean that after writing
	a little bit of assembly to talk to the hardware and implement a few primitives, all the
	rest of the language and compiler is written in FORTH itself.  Remember I said before
	that FORTH lacked IF-statements and loops?  Well of course it doesn't really because
	such a lanuage would be useless, but my point was rather that IF-statements and loops are
	written in FORTH itself.

	Now of course this is common in other languages as well, and in those languages we call
	them 'libraries'.  For example in C, 'printf' is a library function written in C.  But
	in FORTH this goes way beyond mere libraries.  Can you imagine writing C's 'if' in C?
	And that brings me to my third reason: If you can write 'if' in FORTH, then why restrict
	yourself to the usual if/while/for/switch constructs?  You want a construct that iterates
	over every other element in a list of numbers?  You can add it to the language.  What
	about an operator which pulls in variables directly from a configuration file and makes
	them available as FORTH variables?  Or how about adding Makefile-like dependencies to
	the language?  No problem in FORTH.  How about modifying the FORTH compiler to allow
	complex inlining strategies -- simple.  This concept isn't common in programming languages,
	but it has a name (in fact two names): "macros" (by which I mean LISP-style macros, not
	the lame C preprocessor) and "domain specific languages" (DSLs).

	This tutorial isn't about learning FORTH as the language.  I'll point you to some references
	you should read if you're not familiar with using FORTH.  This tutorial is about how to
	write FORTH.  In fact, until you understand how FORTH is written, you'll have only a very
	superficial understanding of how to use it.

	So if you're not familiar with FORTH or want to refresh your memory here are some online
	references to read:

	http://en.wikipedia.org/wiki/Forth_%28programming_language%29
	http://galileo.phys.virginia.edu/classes/551.jvn.fall01/primer.htm
	http://wiki.laptop.org/go/Forth_Lessons
	http://www.albany.net/~hello/simple.htm

	Here is another "Why FORTH?" essay: http://www.jwdt.com/~paysan/why-forth.html
	Discussion and criticism of this FORTH here: http://lambda-the-ultimate.org/node/2452

	ACKNOWLEDGEMENTS ----------------------------------------------------------------------

	This code draws heavily on the design of LINA FORTH (http://home.hccnet.nl/a.w.m.van.der.horst/lina.html)
	by Albert van der Horst.  Any similarities in the code are probably not accidental.

	Some parts of this FORTH are also based on this IOCCC entry from 1992:
	http://ftp.funet.fi/pub/doc/IOCCC/1992/buzzard.2.design.
	I was very proud when Sean Barrett, the original author of the IOCCC entry, commented in the LtU thread
	http://lambda-the-ultimate.org/node/2452#comment-36818 about this FORTH.

	And finally I'd like to acknowledge the (possibly forgotten?) authors of ARTIC FORTH because their
	original program which I still have on original cassette tape kept nagging away at me all these years.
	http://en.wikipedia.org/wiki/Artic_Software

	PUBLIC DOMAIN ----------------------------------------------------------------------

	I, the copyright holder of this work, hereby release it into the public domain. This applies worldwide.

	In case this is not legally possible, I grant any entity the right to use this work for any purpose,
	without any conditions, unless such conditions are required by law.

	SETTING UP ----------------------------------------------------------------------

	Let's get a few housekeeping things out of the way.  Firstly because I need to draw lots of
	ASCII-art diagrams to explain concepts, the best way to look at this is using a window which
	uses a fixed width font and is at least this wide:

 <------------------------------------------------------------------------------------------------------------------------>

	Secondly make sure TABS are set to 8 characters.  The following should be a vertical
	line.  If not, sort out your tabs.

		|
	        |
	    	|

	Thirdly I assume that your screen is at least 50 characters high.

	ASSEMBLING ----------------------------------------------------------------------

	If you want to actually run this FORTH, rather than just read it, you will need macOS on
	Apple Silicon (AArch64). Instead of programming directly to the hardware on a bare PC,
	I went for a simpler tutorial by assuming that the 'hardware' is a macOS process with
	a few basic system calls (read, write and exit and that's about all). This port has
	been modernized from the original 32-bit x86 Linux version to 64-bit ARM. 
	Because memory is 64-bit, pointers and cells are 8 bytes long (instead of 4). 
	Keep this in mind when using memory-access words in standard jonesforth.f!

	To assemble this you will need clang (the standard compiler on macOS).  The commands to
	assemble and run the code (save this file as 'jonesforth.S') are:

	clang -o jonesforth jonesforth.S
	cat jonesforth.f - | ./jonesforth

	If you want to run your own FORTH programs you can do:

	cat jonesforth.f myprog.f | ./jonesforth

	If you want to load your own FORTH code and then continue reading user commands, you can do:

	cat jonesforth.f myfunctions.f - | ./jonesforth

	ASSEMBLER ----------------------------------------------------------------------

	(You can just skip to the next section -- you don't need to be able to read assembler to
	follow this tutorial).

	However if you do want to read the assembly code here are a few notes about AArch64:

	(1) Register names are prefixed with 'x' for 64-bit and 'w' for 32-bit, so x0 is the
	    64-bit accumulator.  The general purpose registers are x0-x30.
	    In this implementation:
	      x26 = Instruction Pointer (IP)
	      x27 = Return Stack Pointer (RSP)
	      x28 = Data Stack Pointer (DSP)

	(2) Instructions take arguments in the form DEST, SRC1, SRC2. So add x0, x1, x2 adds
	    x1 and x2 and stores the result in x0.

	(3) Memory access is done with ldr (load register) and str (store register).
	    str x0, [x28, #-8]! means "subtract 8 from x28, then store x0 at that address" (a push).
	    ldr x0, [x28], #8 means "load x0 from x28, then add 8 to x28" (a pop).

	Now the tutorial starts in earnest.

	THE DICTIONARY ----------------------------------------------------------------------

	In FORTH as you will know, functions are called "words", and just as in other languages they
	have a name and a definition.  Here are two FORTH words:

	: DOUBLE DUP + ;		\ name is "DOUBLE", definition is "DUP +"
	: QUADRUPLE DOUBLE DOUBLE ;	\ name is "QUADRUPLE", definition is "DOUBLE DOUBLE"

	Words, both built-in ones and ones which the programmer defines later, are stored in a dictionary
	which is just a linked list of dictionary entries.

	<--- DICTIONARY ENTRY (HEADER) ----------------------->
	+------------------------+--------+---------- - - - - +----------- - - - -
	| LINK POINTER           | LENGTH/| NAME	      | DEFINITION
	|			 | FLAGS  |     	      |
	+--- (8 bytes) ----------+- byte -+- n bytes  - - - - +----------- - - - -

	I'll come to the definition of the word later.  For now just look at the header.  The first
	8 bytes are the link pointer.  This points back to the previous word in the dictionary, or, for
	the first word in the dictionary it is just a NULL pointer.  Then comes a length/flags byte.
	The length of the word can be up to 31 characters (5 bits used) and the top three bits are used
	for various flags which I'll come to later.  This is followed by the name itself, and in this
	implementation the name is rounded up to a multiple of 8 bytes by padding it with zero bytes.
	That's just to ensure that the definition starts on a 64-bit boundary.

	A FORTH variable called LATEST contains a pointer to the most recently defined word, in
	other words, the head of this linked list.

	DOUBLE and QUADRUPLE might look like this:

	  pointer to previous word
	   ^
	   |
	+--|----------+---+---+---+---+---+---+---+---+------------- - - - -
	| LINK (8)    | 6 | D | O | U | B | L | E | 0 | (definition ...)
	+-------------+---+---+---+---+---+---+---+---+------------- - - - -
           ^           len                     padding
	   |
	+--|----------+---+---+---+---+---+---+---+---+---+---+---+---+------------- - - - -
	| LINK (8)    | 9 | Q | U | A | D | R | U | P | L | E | 0 | 0 | (definition ...)
	+-------------+---+---+---+---+---+---+---+---+---+---+---+---+------------- - - - -
           ^           len                                 padding
           |
           |
	  LATEST

	DIRECT THREADED CODE ----------------------------------------------------------------------

	Now we'll get to the really crucial bit in understanding FORTH. Let's talk about threaded code.
	In FORTH, a function is compiled down to a list of pointers to other functions. We use one
	register (x26) to act as a kind of instruction pointer, pointing to the next function in the list.

	To execute the next function, we just need to read the pointer at x26, increment x26 by 8,
	and jump to the function.
*/

/* NEXT macro. */
	.macro NEXT
	ldr x8, [x26], #8	// x8 gets codeword pointer, IP (x26) advances by 8
	ldr x9, [x8]		// x9 gets the address of the machine code
	br x9			// jump to machine code
	.endm

/*	The macro is called NEXT.  That's a FORTH-ism.  It expands to those three AArch64 instructions.
	Every FORTH primitive that we write has to be ended by NEXT.  Think of it kind of like a return.

	INDIRECT THREADED CODE ----------------------------------------------------------------------

	We add an extra indirection to allow us to run both words written in assembly language
	(primitives written for speed) and words written in FORTH themselves as lists of addresses.

	This extra indirection is the reason for the second 'ldr x9, [x8]'.

	        : QUADRUPLE DOUBLE DOUBLE ;

		+------------------+
		| codeword         |		   : DOUBLE DUP + ;
		+------------------+
		| addr of DOUBLE  ---------------> +------------------+
		+------------------+               | codeword         |
		| addr of DOUBLE   |		   +------------------+
		+------------------+	   	   | addr of DUP   --------------> +------------------+
		| addr of EXIT	   |		   +------------------+            | codeword      -------+
		+------------------+	   x26 ->  | addr of +     --------+	   +------------------+   |
						   +------------------+	   |	   | assembly to    <-----+
						   | addr of EXIT     |    |       | implement DUP    |
						   +------------------+	   |	   |	..	      |
									   |	   |    ..            |
									   |	   | NEXT             |
									   |	   +------------------+
									   |
									   +-----> +------------------+
										   | codeword      -------+
										   +------------------+   |
										   | assembly to   <------+
										   | implement +      |
										   | 	..            |
										   | 	..            |
										   | NEXT      	      |
										   +------------------+

	Words defined in FORTH need a codeword which points to an "interpreter" function called DOCOL.
	Primitives written in assembly have a codeword pointing to their own assembly.

	THE INTERPRETER AND RETURN STACK ------------------------------------------------------------

	One of the things that needs to happen when QUADRUPLE calls DOUBLE is that we save the old
	x26 ("instruction pointer") and create a new one pointing to the first word in DOUBLE.
	We use the register x27 for our return stack.
*/

/* Macros to deal with the return stack. */
	.macro PUSHRSP reg
	str \reg, [x27, #-8]!	// push reg on to return stack
	.endm

	.macro POPRSP reg
	ldr \reg,[x27], #8	// pop top of return stack to reg
	.endm

/*
	DOCOL - the interpreter!
	DOCOL pushes the old x26 on the stack, sets x26 to the first word in the definition, and calls NEXT.
*/
	.text
	.align 3
DOCOL:
	PUSHRSP x26		// push x26 on to the return stack
	add x26, x8, #8		// x8 points to codeword, so add 8 to get first data word
	NEXT

/*
	Helper macro for loading variable addresses on AArch64 / macOS
*/
	.macro GET_VAR_ADDR reg, var
	adrp \reg, \var@PAGE
	add \reg, \reg, \var@PAGEOFF
	.endm

/*
	STARTING UP ----------------------------------------------------------------------
	Entry point for macOS AArch64.
*/
	.text
	.globl _main
	.align 3
_main:
	// On macOS AArch64, _main receives: x0 = argc, x1 = argv.
	// Build a contiguous [argc, argv[0], argv[1], ..., NULL] in a static buffer
	// for compatibility with the ARGC/ARGV FORTH words (which expect Linux stack layout).
	GET_VAR_ADDR x2, forth_args
	str x0, [x2], #8		// store argc
	mov x3, x0			// counter = argc
1:	cbz x3, 2f
	ldr x4, [x1], #8		// load argv[i]
	str x4, [x2], #8		// store it
	sub x3, x3, #1
	b 1b
2:	str xzr, [x2]			// NULL terminator

	// Save pointer to argc/argv area in ARGS variable.
	GET_VAR_ADDR x0, forth_args
	GET_VAR_ADDR x1, var_ARGS
	str x0, [x1]

	// Initialize our dedicated FORTH Data Stack Pointer (x28) and Return Stack Pointer (x27).
	GET_VAR_ADDR x28, data_stack_top
	GET_VAR_ADDR x27, return_stack_top

	// S0 = initial data stack pointer (base of data stack, for .S and DEPTH)
	GET_VAR_ADDR x0, var_S0
	str x28, [x0]

	// Initialize the data segment (HERE).
	bl set_up_data_segment

	// Initialise interpreter and start FORTH execution.
	GET_VAR_ADDR x26, cold_start
	NEXT

	.data
	.align 3
cold_start:			// High-level code without a codeword.
	.quad QUIT

/*
	BUILT-IN WORDS ----------------------------------------------------------------------
*/

/* Flags */
	.set F_IMMED,0x80
	.set F_HIDDEN,0x20
	.set F_LENMASK,0x1f

	.macro defword name, namelen, flags=0, label, prev=0
	.data
	.align 3
name_\label :
	.quad \prev		// link
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align 3		// padding to next 8 byte boundary
\label :
	.quad DOCOL		// codeword - the interpreter
	.endm

	.macro defcode name, namelen, flags=0, label, prev=0
	.data
	.align 3
name_\label :
	.quad \prev		// link
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align 3		// padding to next 8 byte boundary
\label :
	.quad code_\label	// codeword points to assembly
	.text
	.align 3
code_\label :			// assembler code follows
	.endm

/*
	EASY PRIMITIVES ----------------------------------------------------------------------
*/

	defcode "DROP",4,,DROP,0
	ldr x0, [x28], #8	// drop top of stack
	NEXT

	defcode "SWAP",4,,SWAP,name_DROP
	ldr x0, [x28]		// swap top two elements on stack
	ldr x1,[x28, #8]
	str x1, [x28]
	str x0,[x28, #8]
	NEXT

	defcode "DUP",3,,DUP,name_SWAP
	ldr x0,[x28]		// duplicate top of stack
	str x0,[x28, #-8]!
	NEXT

	defcode "OVER",4,,OVER,name_DUP
	ldr x0,[x28, #8]	// get the second element of stack
	str x0,[x28, #-8]!	// and push it on top
	NEXT

	defcode "ROT",3,,ROT,name_OVER
	ldr x0, [x28], #8
	ldr x1,[x28], #8
	ldr x2, [x28], #8
	str x1, [x28, #-8]!
	str x0, [x28, #-8]!
	str x2,[x28, #-8]!
	NEXT

	defcode "-ROT",4,,NROT,name_ROT
	ldr x0, [x28], #8
	ldr x1, [x28], #8
	ldr x2, [x28], #8
	str x0,[x28, #-8]!
	str x2,[x28, #-8]!
	str x1,[x28, #-8]!
	NEXT

	defcode "2DROP",5,,TWODROP,name_NROT // drop top two elements of stack
	add x28, x28, #16
	NEXT

	defcode "2DUP",4,,TWODUP,name_TWODROP // duplicate top two elements of stack
	ldr x0, [x28]
	ldr x1,[x28, #8]
	str x1, [x28, #-8]!
	str x0,[x28, #-8]!
	NEXT

	defcode "2SWAP",5,,TWOSWAP,name_TWODUP // swap top two pairs of elements of stack
	ldr x0, [x28], #8
	ldr x1, [x28], #8
	ldr x2,[x28], #8
	ldr x3, [x28], #8
	str x1,[x28, #-8]!
	str x0, [x28, #-8]!
	str x3,[x28, #-8]!
	str x2,[x28, #-8]!
	NEXT

	defcode "?DUP",4,,QDUP,name_TWOSWAP	// duplicate top of stack if non-zero
	ldr x0, [x28]
	cbz x0, 1f
	str x0,[x28, #-8]!
1:	NEXT

	defcode "1+",2,,INCR,name_QDUP
	ldr x0, [x28]
	add x0, x0, #1
	str x0, [x28]
	NEXT

	defcode "1-",2,,DECR,name_INCR
	ldr x0, [x28]
	sub x0, x0, #1
	str x0, [x28]
	NEXT

	defcode "4+",2,,INCR4,name_DECR
	ldr x0, [x28]
	add x0, x0, #4
	str x0, [x28]
	NEXT

	defcode "4-",2,,DECR4,name_INCR4
	ldr x0, [x28]
	sub x0, x0, #4
	str x0, [x28]
	NEXT

	defcode "8+",2,,INCR8,name_DECR4
	ldr x0, [x28]
	add x0, x0, #8
	str x0, [x28]
	NEXT

	defcode "8-",2,,DECR8,name_INCR8
	ldr x0, [x28]
	sub x0, x0, #8
	str x0, [x28]
	NEXT

	defcode "+",1,,ADD,name_DECR8
	ldr x0, [x28], #8	// get top of stack
	ldr x1,[x28]
	add x1, x1, x0		// add it
	str x1, [x28]
	NEXT

	defcode "-",1,,SUB,name_ADD
	ldr x0,[x28], #8	// get top of stack
	ldr x1,[x28]
	sub x1, x1, x0		// subtract it
	str x1,[x28]
	NEXT

	defcode "*",1,,MUL,name_SUB
	ldr x0,[x28], #8
	ldr x1, [x28]
	mul x1, x1, x0
	str x1, [x28]
	NEXT

	defcode "/MOD",4,,DIVMOD,name_MUL
	ldr x1, [x28], #8	// divisor
	ldr x0, [x28]		// dividend
	sdiv x2, x0, x1		// x2 = quotient
	msub x3, x2, x1, x0	// x3 = remainder
	str x3,[x28]		// push remainder
	str x2,[x28, #-8]!	// push quotient
	NEXT

/* COMPARISONS */

	defcode "=",1,,EQU,name_DIVMOD	// top two words are equal?
	ldr x0, [x28], #8
	ldr x1,[x28], #8
	cmp x1, x0
	cset x0, eq
	str x0, [x28, #-8]!
	NEXT

	defcode "<>",2,,NEQU,name_EQU	// top two words are not equal?
	ldr x0, [x28], #8
	ldr x1, [x28], #8
	cmp x1, x0
	cset x0, ne
	str x0, [x28, #-8]!
	NEXT

	defcode "<",1,,LT,name_NEQU
	ldr x0, [x28], #8
	ldr x1, [x28], #8
	cmp x1, x0
	cset x0, lt
	str x0, [x28, #-8]!
	NEXT

	defcode ">",1,,GT,name_LT
	ldr x0, [x28], #8
	ldr x1,[x28], #8
	cmp x1, x0
	cset x0, gt
	str x0, [x28, #-8]!
	NEXT

	defcode "<=",2,,LE,name_GT
	ldr x0, [x28], #8
	ldr x1,[x28], #8
	cmp x1, x0
	cset x0, le
	str x0, [x28, #-8]!
	NEXT

	defcode ">=",2,,GE,name_LE
	ldr x0, [x28], #8
	ldr x1, [x28], #8
	cmp x1, x0
	cset x0, ge
	str x0,[x28, #-8]!
	NEXT

	defcode "0=",2,,ZEQU,name_GE	// top of stack equals 0?
	ldr x0, [x28], #8
	cmp x0, #0
	cset x0, eq
	str x0,[x28, #-8]!
	NEXT

	defcode "0<>",3,,ZNEQU,name_ZEQU	// top of stack not 0?
	ldr x0, [x28], #8
	cmp x0, #0
	cset x0, ne
	str x0, [x28, #-8]!
	NEXT

	defcode "0<",2,,ZLT,name_ZNEQU	// comparisons with 0
	ldr x0, [x28], #8
	cmp x0, #0
	cset x0, lt
	str x0, [x28, #-8]!
	NEXT

	defcode "0>",2,,ZGT,name_ZLT
	ldr x0, [x28], #8
	cmp x0, #0
	cset x0, gt
	str x0,[x28, #-8]!
	NEXT

	defcode "0<=",3,,ZLE,name_ZGT
	ldr x0,[x28], #8
	cmp x0, #0
	cset x0, le
	str x0, [x28, #-8]!
	NEXT

	defcode "0>=",3,,ZGE,name_ZLE
	ldr x0, [x28], #8
	cmp x0, #0
	cset x0, ge
	str x0,[x28, #-8]!
	NEXT

	defcode "AND",3,,AND,name_ZGE	// bitwise AND
	ldr x0,[x28], #8
	ldr x1, [x28]
	and x1, x1, x0
	str x1, [x28]
	NEXT

	defcode "OR",2,,OR,name_AND	// bitwise OR
	ldr x0, [x28], #8
	ldr x1, [x28]
	orr x1, x1, x0
	str x1,[x28]
	NEXT

	defcode "XOR",3,,XOR,name_OR	// bitwise XOR
	ldr x0, [x28], #8
	ldr x1,[x28]
	eor x1, x1, x0
	str x1,[x28]
	NEXT

	defcode "INVERT",6,,INVERT,name_XOR // this is the FORTH bitwise "NOT" function
	ldr x0, [x28]
	mvn x0, x0
	str x0, [x28]
	NEXT

/*
	RETURNING FROM FORTH WORDS ----------------------------------------------------------------------
*/

	defcode "EXIT",4,,EXIT,name_INVERT
	POPRSP x26		// pop return stack into instruction pointer
	NEXT

/*
	LITERALS ----------------------------------------------------------------------
*/

	defcode "LIT",3,,LIT,name_EXIT
	ldr x0, [x26], #8	// read literal from IP, advance IP
	str x0, [x28, #-8]!	// push the literal number on to stack
	NEXT

/*
	MEMORY ----------------------------------------------------------------------
*/

	defcode "!",1,,STORE,name_LIT
	ldr x1, [x28], #8	// address to store at
	ldr x0, [x28], #8	// data to store there
	str x0, [x1]		// store it
	NEXT

	defcode "@",1,,FETCH,name_STORE
	ldr x1, [x28], #8	// address to fetch
	ldr x0, [x1]		// fetch it
	str x0,[x28, #-8]!	// push value onto stack
	NEXT

	defcode "+!",2,,ADDSTORE,name_FETCH
	ldr x1, [x28], #8	// address
	ldr x0, [x28], #8	// the amount to add
	ldr x2, [x1]
	add x2, x2, x0
	str x2, [x1]		// add it
	NEXT

	defcode "-!",2,,SUBSTORE,name_ADDSTORE
	ldr x1, [x28], #8	// address
	ldr x0, [x28], #8	// the amount to subtract
	ldr x2, [x1]
	sub x2, x2, x0
	str x2,[x1]		// subtract it
	NEXT

	defcode "C!",2,,STOREBYTE,name_SUBSTORE
	ldr x1, [x28], #8	// address to store at
	ldr x0,[x28], #8	// data to store there
	strb w0, [x1]		// store it
	NEXT

	defcode "C@",2,,FETCHBYTE,name_STOREBYTE
	ldr x1,[x28], #8	// address to fetch
	mov x0, #0
	ldrb w0, [x1]		// fetch it
	str x0, [x28, #-8]!	// push value onto stack
	NEXT

	defcode "C@C!",4,,CCOPY,name_FETCHBYTE
	ldr x1,[x28, #8]	// source address
	ldrb w0, [x1]		// get source character
	ldr x2, [x28]		// destination address
	strb w0, [x2], #1	// copy to destination and increment
	str x2,[x28]		// update destination address
	add x1, x1, #1
	str x1,[x28, #8]	// update source address
	NEXT

	defcode "CMOVE",5,,CMOVE,name_CCOPY
	ldr x2, [x28], #8	// length
	ldr x0,[x28], #8	// destination address
	ldr x1, [x28], #8	// source address
1:	cbz x2, 2f
	ldrb w3,[x1], #1
	strb w3, [x0], #1
	sub x2, x2, #1
	b 1b
2:	NEXT

/*
	BUILT-IN VARIABLES ----------------------------------------------------------------------
*/

	.macro defvar name, namelen, flags=0, label, prev=0, initial=0
	defcode \name,\namelen,\flags,\label,\prev
	GET_VAR_ADDR x0, var_\name
	str x0, [x28, #-8]!
	NEXT
	.data
	.align 3
var_\name :
	.quad \initial
	.endm

	defvar "STATE",5,,STATE,name_CMOVE
	defvar "HERE",4,,HERE,name_STATE
	defvar "LATEST",6,,LATEST,name_HERE,name_SYSCALL0
	defvar "S0",2,,SZ,name_LATEST
	defvar "ARGS",4,,ARGS,name_SZ
	defvar "BASE",4,,BASE,name_ARGS,10

/*
	BUILT-IN CONSTANTS ----------------------------------------------------------------------
*/
	.macro defconst name, namelen, flags=0, label, prev=0, value
	defcode \name,\namelen,\flags,\label,\prev
	GET_VAR_ADDR x0, _const_\label
	ldr x0, [x0]
	str x0, [x28, #-8]!
	NEXT
	.data
	.align 3
_const_\label :
	.quad \value
	.endm

	defconst "VERSION",7,,VERSION,name_BASE,JONES_VERSION
	defconst "R0",2,,RZ,name_VERSION,return_stack_top
	defconst "DOCOL",5,,__DOCOL,name_RZ,DOCOL
	defconst "F_IMMED",7,,__F_IMMED,name___DOCOL,F_IMMED
	defconst "F_HIDDEN",8,,__F_HIDDEN,name___F_IMMED,F_HIDDEN
	defconst "F_LENMASK",9,,__F_LENMASK,name___F_HIDDEN,F_LENMASK

	// Syscall numbers for macOS (0x2000000 class offset)
	defconst "SYS_EXIT",8,,SYS_EXIT,name___F_LENMASK, 0x2000001
	defconst "SYS_OPEN",8,,SYS_OPEN,name_SYS_EXIT, 0x2000005
	defconst "SYS_CLOSE",9,,SYS_CLOSE,name_SYS_OPEN, 0x2000006
	defconst "SYS_READ",8,,SYS_READ,name_SYS_CLOSE, 0x2000003
	defconst "SYS_WRITE",9,,SYS_WRITE,name_SYS_READ, 0x2000004
	defconst "SYS_CREAT",9,,SYS_CREAT,name_SYS_WRITE, 0x2000008
	defconst "SYS_BRK",7,,SYS_BRK,name_SYS_CREAT, 0 // Not relevant on macOS

	defconst "O_RDONLY",8,,__O_RDONLY,name_SYS_BRK,0
	defconst "O_WRONLY",8,,__O_WRONLY,name___O_RDONLY,1
	defconst "O_RDWR",6,,__O_RDWR,name___O_WRONLY,2
	defconst "O_CREAT",7,,__O_CREAT,name___O_RDWR,0100
	defconst "O_EXCL",6,,__O_EXCL,name___O_CREAT,0200
	defconst "O_TRUNC",7,,__O_TRUNC,name___O_EXCL,01000
	defconst "O_APPEND",8,,__O_APPEND,name___O_TRUNC,02000
	defconst "O_NONBLOCK",10,,__O_NONBLOCK,name___O_APPEND,04000

/*
	RETURN STACK ----------------------------------------------------------------------
*/

	defcode ">R",2,,TOR,name___O_NONBLOCK
	ldr x0, [x28], #8	// pop parameter stack into x0
	PUSHRSP x0		// push it on to the return stack
	NEXT

	defcode "R>",2,,FROMR,name_TOR
	POPRSP x0		// pop return stack on to x0
	str x0, [x28, #-8]!	// and push on to parameter stack
	NEXT

	defcode "RSP@",4,,RSPFETCH,name_FROMR
	str x27,[x28, #-8]!
	NEXT

	defcode "RSP!",4,,RSPSTORE,name_RSPFETCH
	ldr x27, [x28], #8
	NEXT

	defcode "RDROP",5,,RDROP,name_RSPSTORE
	add x27, x27, #8	// pop return stack and throw away
	NEXT

/*
	PARAMETER (DATA) STACK ----------------------------------------------------------------------
*/

	defcode "DSP@",4,,DSPFETCH,name_RDROP
	mov x0, x28
	str x0,[x28, #-8]!
	NEXT

	defcode "DSP!",4,,DSPSTORE,name_DSPFETCH
	ldr x28, [x28]
	NEXT

/*
	INPUT AND OUTPUT ----------------------------------------------------------------------
*/

	defcode "KEY",3,,KEY,name_DSPSTORE
	str x30,[sp, #-16]!
	bl _KEY
	ldr x30, [sp], #16
	str x0, [x28, #-8]!	// push return value on stack
	NEXT
_KEY:
	GET_VAR_ADDR x1, currkey
	ldr x2, [x1]
	GET_VAR_ADDR x3, bufftop
	ldr x4, [x3]
	cmp x2, x4
	b.ge 1f			// exhausted the input buffer?
	mov x0, #0
	ldrb w0,[x2], #1	// get next key from input buffer
	str x2, [x1]		// increment currkey
	ret

1:	// Out of input; use read to fetch more input from stdin.
	mov x0, #0		// 1st param: stdin
	GET_VAR_ADDR x1, buffer	// 2nd param: buffer
	GET_VAR_ADDR x2, currkey
	str x1, [x2]		// reset currkey to start of buffer
	mov x2, #4096		// 3rd param: max length
	movz x16, #3		// syscall: read
	movk x16, #0x200, lsl #16
	svc #0
	b.cc 3f			// carry clear -> success
	mov x0, #0		// if error, treat as EOF
3:
	cbz x0, 2f		// If 0 bytes read, exit
	GET_VAR_ADDR x1, buffer
	add x1, x1, x0		// buffer+bytes = bufftop
	GET_VAR_ADDR x2, bufftop
	str x1, [x2]
	b _KEY

2:	// Error or end of input: exit the program.
	mov x0, #0
	movz x16, #1		// syscall: exit
	movk x16, #0x200, lsl #16
	svc #0

	.data
	.align 3
currkey:
	.quad buffer		// Current place in input buffer
bufftop:
	.quad buffer		// Last valid data in input buffer

	defcode "EMIT",4,,EMIT,name_KEY
	ldr x0, [x28], #8
	str x30,[sp, #-16]!
	bl _EMIT
	ldr x30,[sp], #16
	NEXT
_EMIT:
	GET_VAR_ADDR x1, emit_scratch
	strb w0, [x1]
	mov x0, #1		// 1st param: stdout
	mov x2, #1		// 3rd param: nbytes = 1
	movz x16, #4		// write syscall
	movk x16, #0x200, lsl #16
	svc #0
	ret

	.data
	.align 0
emit_scratch:
	.space 1		// scratch used by EMIT

	defcode "WORD",4,,WORD,name_EMIT
	str x30,[sp, #-16]!
	bl _WORD
	ldr x30,[sp], #16
	str x0, [x28, #-8]!	// push base address
	str x2, [x28, #-8]!	// push length
	NEXT

_WORD:
	str x30, [sp, #-16]!	// Save LR
1:
	bl _KEY			// get next key, returned in x0
	cmp w0, #'\\'		// start of a comment?
	b.eq 3f			// if so, skip the comment
	cmp w0, #' '
	b.ls 1b			// if so, keep looking

	GET_VAR_ADDR x4, word_buffer // pointer to return buffer
2:
	strb w0,[x4], #1	// add character to return buffer
	str x4, [sp, #8]	// save write pointer (_KEY clobbers x4)
	bl _KEY			// get next key
	ldr x4, [sp, #8]	// restore write pointer
	cmp w0, #' '		// is blank?
	b.hi 2b			// if not, keep looping

	GET_VAR_ADDR x3, word_buffer
	sub x2, x4, x3		// return length of the word in x2
	mov x0, x3		// return address of the word in x0
	ldr x30, [sp], #16	// Restore LR
	ret

3:
	bl _KEY
	cmp w0, #'\n'		// end of line yet?
	b.ne 3b
	b 1b

	.data
word_buffer:
	.space 32

	defcode "NUMBER",6,,NUMBER,name_WORD
	ldr x2,[x28], #8	// length of string
	ldr x4, [x28], #8	// start address of string
	str x30, [sp, #-16]!
	bl _NUMBER
	ldr x30, [sp], #16
	str x0,[x28, #-8]!	// parsed number
	str x2, [x28, #-8]!	// number of unparsed characters (0 = no error)
	NEXT

_NUMBER:
	mov x0, #0
	mov x1, #0		// negative flag

	cbz x2, 5f		// error on length 0

	GET_VAR_ADDR x3, var_BASE
	ldr x3, [x3]		// BASE

	ldrb w5, [x4], #1	// read first character
	cmp w5, #'-'
	b.ne 2f
	mov x1, #1		// flag as negative
	sub x2, x2, #1
	cbz x2, 6f		// error if string is just '-'
	ldrb w5,[x4], #1	// next char
	b 2f

1:	mul x0, x0, x3		// x0 *= BASE
	ldrb w5, [x4], #1
2:	sub w5, w5, #'0'	// < '0'?
	cmp w5, #0
	b.lt 4f
	cmp w5, #10		// <= '9'?
	b.lt 3f
	sub w5, w5, #17		// < 'A'? (17 is 'A'-'0')
	cmp w5, #0
	b.lt 4f
	add w5, w5, #10

3:	cmp x5, x3		// >= BASE?
	b.ge 4f

	add x0, x0, x5		// add it
	sub x2, x2, #1
	cbnz x2, 1b

4:	cbz x1, 5f
	neg x0, x0		// negate result

5:	ret

6:	mov x2, #1		// error
	ret

/*
	DICTIONARY LOOK UPS ----------------------------------------------------------------------
*/

	defcode "FIND",4,,FIND,name_NUMBER
	ldr x2, [x28], #8	// x2 = length
	ldr x4, [x28], #8	// x4 = address
	str x30, [sp, #-16]!
	bl _FIND
	ldr x30, [sp], #16
	str x0, [x28, #-8]!	// x0 = address of dictionary entry
	NEXT

_FIND:
	GET_VAR_ADDR x3, var_LATEST
	ldr x3, [x3]		// LATEST
1:	cbz x3, 4f		// NULL pointer?

	ldrb w5, [x3, #8]	// load flags+length (after 8-byte link)
	and w5, w5, #(F_HIDDEN|F_LENMASK)
	cmp w2, w5		// Length is the same?
	b.ne 2f

	// Compare strings
	add x6, x3, #9		// Dictionary string
	mov x7, x4		// Expected string
	mov x8, x2		// Length
3:	cbz x8, 5f
	ldrb w9, [x6], #1
	ldrb w10,[x7], #1
	cmp w9, w10
	b.ne 2f
	sub x8, x8, #1
	b 3b

5:	mov x0, x3		// Found it
	ret

2:	ldr x3, [x3]		// Follow link
	b 1b

4:	mov x0, #0		// Not found
	ret

	defcode ">CFA",4,,TCFA,name_FIND
	ldr x4, [x28], #8
	str x30, [sp, #-16]!
	bl _TCFA
	ldr x30, [sp], #16
	str x4, [x28, #-8]!
	NEXT
_TCFA:
	add x4, x4, #8		// Skip link pointer.
	ldrb w1, [x4]		// Load flags+len.
	add x4, x4, #1		// Skip flags+len byte.
	and w1, w1, #F_LENMASK	// Just the length.
	add x4, x4, x1		// Skip the name.
	add x4, x4, #7		// Align to 8-byte boundary.
	and x4, x4, #~7
	ret

	defword ">DFA",4,,TDFA,name_TCFA
	.quad TCFA		// >CFA		(get code field address)
	.quad INCR8		// 8+		(add 8 to it to get to next word)
	.quad EXIT		// EXIT

/*
	COMPILING ----------------------------------------------------------------------
*/

	defcode "CREATE",6,,CREATE,name_TDFA
	ldr x2,[x28], #8	// length
	ldr x1, [x28], #8	// name addr

	GET_VAR_ADDR x3, var_HERE
	ldr x4, [x3]		// x4 = start of new header

	GET_VAR_ADDR x5, var_LATEST
	ldr x6, [x5]		// x6 = LATEST

	str x6,[x4]		// store link
	str x4, [x5]		// LATEST = new header

	add x4, x4, #8		// advance
	strb w2, [x4], #1	// store length+flags
1:	cbz x2, 2f		// copy name
	ldrb w7,[x1], #1
	strb w7, [x4], #1
	sub x2, x2, #1
	b 1b

2:	add x4, x4, #7		// align to 8
	and x4, x4, #~7

	str x4, [x3]		// update HERE
	NEXT

	defcode ",",1,,COMMA,name_CREATE
	ldr x0,[x28], #8	// Code pointer to store.
	str x30, [sp, #-16]!
	bl _COMMA
	ldr x30, [sp], #16
	NEXT
_COMMA:
	GET_VAR_ADDR x3, var_HERE
	ldr x4,[x3]		// HERE
	str x0,[x4], #8	// Store it.
	str x4, [x3]		// Update HERE
	ret

	defcode "[",1,F_IMMED,LBRAC,name_COMMA
	mov x0, #0
	GET_VAR_ADDR x1, var_STATE
	str x0,[x1]		// Set STATE to 0.
	NEXT

	defcode "]",1,,RBRAC,name_LBRAC
	mov x0, #1
	GET_VAR_ADDR x1, var_STATE
	str x0, [x1]		// Set STATE to 1.
	NEXT

	defword ":",1,,COLON,name_RBRAC
	.quad WORD		// Get the name
	.quad CREATE		// CREATE the dictionary entry
	.quad LIT, DOCOL, COMMA	// Append DOCOL
	.quad LATEST, FETCH, HIDDEN // Make the word hidden
	.quad RBRAC		// Go into compile mode.
	.quad EXIT		// Return.

	defword ";",1,F_IMMED,SEMICOLON,name_COLON
	.quad LIT, EXIT, COMMA	// Append EXIT
	.quad LATEST, FETCH, HIDDEN // Unhide the word
	.quad LBRAC		// Go back to IMMEDIATE mode.
	.quad EXIT		// Return.

/*
	EXTENDING THE COMPILER ----------------------------------------------------------------------
*/

	defcode "IMMEDIATE",9,F_IMMED,IMMEDIATE,name_SEMICOLON
	GET_VAR_ADDR x0, var_LATEST
	ldr x1, [x0]		// LATEST word.
	add x1, x1, #8		// Point to name/flags byte.
	ldrb w2, [x1]
	eor w2, w2, #F_IMMED	// Toggle the IMMED bit.
	strb w2, [x1]
	NEXT

	defcode "HIDDEN",6,,HIDDEN,name_IMMEDIATE
	ldr x1, [x28], #8	// Dictionary entry.
	add x1, x1, #8		// Point to name/flags byte.
	ldrb w2, [x1]
	eor w2, w2, #F_HIDDEN	// Toggle the HIDDEN bit.
	strb w2, [x1]
	NEXT

	defword "HIDE",4,,HIDE,name_HIDDEN
	.quad WORD		// Get the word.
	.quad FIND		// Look up in the dictionary.
	.quad HIDDEN		// Set F_HIDDEN flag.
	.quad EXIT		// Return.

	defcode "'",1,,TICK,name_HIDE
	ldr x0, [x26], #8	// Get the address of the next word and skip it.
	str x0, [x28, #-8]!	// Push it on the stack.
	NEXT

/*
	BRANCHING ----------------------------------------------------------------------
*/

	defcode "BRANCH",6,,BRANCH,name_TICK
	ldr x0, [x26]		// read the offset
	add x26, x26, x0	// apply the offset
	NEXT

	defcode "0BRANCH",7,,ZBRANCH,name_BRANCH
	ldr x0, [x28], #8
	cbz x0, code_BRANCH	// if zero, jump to BRANCH implementation
	add x26, x26, #8	// otherwise we need to skip the offset
	NEXT

/*
	LITERAL STRINGS ----------------------------------------------------------------------
*/

	defcode "LITSTRING",9,,LITSTRING,name_ZBRANCH
	ldr x0,[x26], #8	// get the length of the string
	str x26,[x28, #-8]!	// push the address of the start of the string
	str x0,[x28, #-8]!	// push length
	add x26, x26, x0	// skip past the string
	add x26, x26, #7	// round up to next 8-byte boundary
	and x26, x26, #~7
	NEXT

	defcode "TELL",4,,TELL,name_LITSTRING
	mov x0, #1		// 1st param: stdout
	ldr x2, [x28], #8	// 3rd param: length of string
	ldr x1, [x28], #8	// 2nd param: address of string
	movz x16, #4		// write syscall
	movk x16, #0x200, lsl #16
	svc #0
	NEXT

/*
	QUIT AND INTERPRET ----------------------------------------------------------------------
*/

	defword "QUIT",4,,QUIT,name_TELL
	.quad RZ,RSPSTORE	// R0 RSP!, clear the return stack
	.quad INTERPRET		// interpret the next word
	.quad BRANCH,-16	// and loop (indefinitely)

	defcode "INTERPRET",9,,INTERPRET,name_QUIT
	str x30, [sp, #-16]!
	bl _WORD
	ldr x30, [sp], #16
	mov x4, x0		// x4 = word address
	mov x5, x2		// x5 = length

	GET_VAR_ADDR x1, interpret_is_lit
	str wzr, [x1]
	stp x5, x30,[sp, #-16]!
	bl _FIND
	ldp x5, x30, [sp], #16
	cbz x0, 1f		// Not found -> Literal

	mov x4, x0		// x4 = header
	ldrb w6, [x4, #8]	// w6 = flags
	str x30,[sp, #-16]!
	bl _TCFA
	ldr x30, [sp], #16	// x4 = codeword
	tst w6, #F_IMMED
	b.ne 4f			// IMMEDIATE -> execute

	b 2f

1:	// Not in dictionary
	GET_VAR_ADDR x1, interpret_is_lit
	mov w3, #1
	str w3,[x1]
	mov x2, x5		// restore length
	str x30,[sp, #-16]!
	bl _NUMBER
	ldr x30, [sp], #16
	cbnz x2, 6f		// error -> Parse error
	mov x9, x0		// x9 = literal number
	GET_VAR_ADDR x4, LIT	// x4 = codeword for LIT

2:	// Are we compiling or executing?
	GET_VAR_ADDR x3, var_STATE
	ldr w3, [x3]
	cbz w3, 4f		// Executing

	// Compiling
	mov x0, x4
	str x30, [sp, #-16]!
	bl _COMMA
	ldr x30, [sp], #16
	GET_VAR_ADDR x1, interpret_is_lit
	ldr w3, [x1]
	cbz w3, 3f
	mov x0, x9		// Append the literal number
	str x30,[sp, #-16]!
	bl _COMMA
	ldr x30, [sp], #16
3:	NEXT

4:	// Executing
	GET_VAR_ADDR x1, interpret_is_lit
	ldr w3, [x1]
	cbnz w3, 5f

	// Execute word
	mov x8, x4
	ldr x10,[x8]
	br x10

5:	// Executing a literal
	str x9,[x28, #-8]!
	NEXT

6:	// Parse error
	mov x0, #2		// stderr
	GET_VAR_ADDR x1, errmsg
	mov x2, #13		// length of "PARSE ERROR: "
	movz x16, #4		// write
	movk x16, #0x200, lsl #16
	svc #0

	GET_VAR_ADDR x1, currkey
	ldr x1,[x1]
	GET_VAR_ADDR x2, buffer
	sub x2, x1, x2		// len
	cmp x2, #40
	b.le 7f
	mov x2, #40
7:	sub x1, x1, x2
	mov x0, #2
	movz x16, #4		
	movk x16, #0x200, lsl #16
	svc #0

	mov x0, #2
	GET_VAR_ADDR x1, errmsgnl
	mov x2, #1
	movz x16, #4		
	movk x16, #0x200, lsl #16
	svc #0

	NEXT

	.data
errmsg: .ascii "PARSE ERROR: "
errmsgend:
errmsgnl: .ascii "\n"

	.data
	.align 3
interpret_is_lit:
	.quad 0			// Flag used to record if reading a literal

/*
	ODDS AND ENDS ----------------------------------------------------------------------
*/

	defcode "CHAR",4,,CHAR,name_INTERPRET
	str x30, [sp, #-16]!
	bl _WORD
	ldr x30, [sp], #16
	mov x1, #0
	ldrb w1, [x0]		// Get the first character of the word.
	str x1,[x28, #-8]!	// Push it onto the stack.
	NEXT

	defcode "EXECUTE",7,,EXECUTE,name_CHAR
	ldr x8, [x28], #8	// Get xt into x8
	ldr x9, [x8]		// Code address
	br x9			// jump to it.

	defcode "SYSCALL3",8,,SYSCALL3,name_EXECUTE
	ldr x16,[x28], #8	// System call number
	ldr x0,[x28], #8	// First parameter.
	ldr x1, [x28], #8	// Second parameter
	ldr x2, [x28], #8	// Third parameter
	svc #0
	b.cc 1f
	neg x0, x0		// negative for -errno on Apple platforms
1:	str x0, [x28, #-8]!	// Result
	NEXT

	defcode "SYSCALL2",8,,SYSCALL2,name_SYSCALL3
	ldr x16,[x28], #8
	ldr x0, [x28], #8
	ldr x1, [x28], #8
	svc #0
	b.cc 1f
	neg x0, x0
1:	str x0, [x28, #-8]!
	NEXT

	defcode "SYSCALL1",8,,SYSCALL1,name_SYSCALL2
	ldr x16, [x28], #8
	ldr x0, [x28], #8
	svc #0
	b.cc 1f
	neg x0, x0
1:	str x0,[x28, #-8]!
	NEXT

	defcode "SYSCALL0",8,,SYSCALL0,name_SYSCALL1
	ldr x16, [x28], #8
	svc #0
	b.cc 1f
	neg x0, x0
1:	str x0,[x28, #-8]!
	NEXT

/*
	DATA SEGMENT ----------------------------------------------------------------------
	On macOS AArch64 we statically allocate a large .bss buffer instead of relying
	on deprecated 'brk' syscalls.
*/
	.text
set_up_data_segment:
	GET_VAR_ADDR x0, data_segment
	GET_VAR_ADDR x1, var_HERE
	str x0, [x1]
	ret

	.bss
	.align 12
data_segment:
	.space 1048576		// 1 MB Dictionary Space

/* Stacks and buffers */
	.align 4
return_stack:
	.space 8192
return_stack_top:

	.align 4
data_stack:
	.space 8192
data_stack_top:

	.align 12
buffer:
	.space 4096

	.align 3
forth_args:
	.space 264		// room for argc + up to 32 argv pointers + NULL

/* END OF jonesforth.S */
