;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; ReactionTimer V2
;;	Couldn't find the original macro version, so it has been remade with
;;    many improvements! Licensed under Apache 2.0.
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    ; Program basis:
    ; User has keypad as input mechanism
    ; User has to guess what the code is in various game modes
    ; GAMEMODE_TEST (not normal): Known code input
    ; GAMEMODE_REACTION: User has to produce an unknown code indirectly 

    
					
    LIST P=16F88
#include <p16f88.inc>
    __CONFIG _CONFIG1, _EXTRC_IO & _WDT_OFF & _PWRTE_OFF & _MCLR_ON & _LVP_ON & _BOREN_ON & _CPD_OFF
    __CONFIG _CONFIG2, _FCMEN_OFF & _IESO_OFF

;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 

; Pre-processor directives
    
#define GAMEMODE_TEST			; Game modes are currently hard coded :(
					; 1. GAMEMODE_TEST (Known Code)
					; 2. GAMEMODE_REACTION (Unknown code,
					;	input is pseudo-random)
					; 3. GAMEMODE_VERSUS (2-player, 1 player
					;	enters code, other guesses.)
    
#define N_DIGITS 6			; Macros can accept an arbitrary amount
					; of digits, but all other code scan
					; functions have run in increments of 15
					; at most (unless the initial addr is
					; somewhere between XXXX 0000 
					; and XXXX 1111 exclusive.
					; It is suggested to keep this at 6 to
					; maintain compatibility with code that
					; uses the DC flag to determine when to
					; stop scanning.

#define RC_ENC_1    b'00001001'	; '0 CCCC RRR' encoding
#define RC_ENC_2    b'00001010'
#define RC_ENC_3    b'00001100'
#define RC_ENC_4    b'00010001'
#define RC_ENC_5    b'00010010'
#define RC_ENC_6    b'00010100'
#define RC_ENC_7    b'00100001'
#define RC_ENC_8    b'00100010'
#define RC_ENC_9    b'00100100'
#define RC_ENC_CLR  b'01000010'
				
; Indirect Addressing Bank Select (INDF,FSR)
#define	IRP1	    BSF	STATUS,7	; Bank 2,3
#define	IRP0	    BCF	STATUS,6	; Bank 0,1

; Direct Addressing Bank Select (general operations)					
#define BANK1	    BSF	STATUS,5
#define BANK0	    BCF	STATUS,5	; CLRF would also modify IRP... 
					; we will spend most of our time
						; in bank 0.

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::					
; Memory locations

	idata	0x02A
C1	db	RC_ENC_1		;; occupies 0x2A to 2F.
C2	db	RC_ENC_2		;; if the location is changed, the lsb
C3	db	RC_ENC_3		;; of the hex number must be 0xA. This
C4	db	RC_ENC_4		;; is because the code relies on Digit
C5	db	RC_ENC_5		;; Carry to determine when all 6 codes
C6	db	RC_ENC_6		;; are read.
	
	udata	0x020
GST	res	.1
CPTR	res	.1
TMP1	res	.1
TMP	res	.1

		
	; Startup Vectors
RES_VECT    CODE    0x0000
	    GOTO    _INIT
INT_VECT    CODE    0x0004
	    GOTO    _GAME
	    
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::	
;; Macros								      ;;
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; Inserts N RLF f,d instructions.
RLFN	macro file,dest,n
i=0
	while i < n
	RLF	file,dest
i++
	endw
	endm
; Obtain N inputs, and store them in addresses over range addr : addr + n
N_PLAYER_INPUT	macro initial_addr,n		    ;; TODO: REDO AS FUNCTION
i=0						    ;; SO THAT CAN PROCESS CLR
	while i < n				    ;; EFFICIENTLY!! :)
	    CALL	GET_INPUT_BLOCKING
		
	    MOVWF	initial_addr + i
i++
	endw
	endm
; Obtain N random numbers, and store them in addresses over range addr : addr+n	
N_PRNG	macro initial_addr,n
i=0
	while i < n
	    CALL	PSEUDO_PRNG_W
	    MOVWF	initial_addr + i
i++
	endw
	endm
	
; rotate left no carry increment if zero
RLNCIFZ	macro file,max_width	
	RLF	file,f
	MOVF	file,w
	BTFSS	STATUS,Z    ; Increment if empty
	INCF	file,f
	BTFSS	file,max_width + 1 ; prevent carry behaviour
	CLRF	file
	endm
	
MOVLF	macro file,literal
	MOVLW	literal
	MOVWF	file
	endm
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; Code									      ;;
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
	
	;; Startup / On-Reset subroutine
_INIT	BANK1
	BCF	ADCON0,0	;;  Disable A/D conversion.
	MOVLW	B'00011111'	;;  RA<0:4> are inputs, rest out
	MOVWF	TRISA		;;  RB is all output.
	MOVLW	B'00000000'
	MOVWF	TRISB
	BANK0
	IRP0				;; all indirect addr happens in b0.					
	; Main loop / program
	
_GAME	NOP
	ifdef GAMEMODE_TEST	    ; GAMEMODE_TEST requires no action,
	CALL	TEST_CODE
	endif
	ifdef GAMEMODE_VERSUS	    ; as C<1:6> are already initialized.
	N_PLAYER_INPUT N_DIGITS
	endif
	ifdef GAMEMODE_REACTION
	N_PRNG N_DIGITS
	endif
	
	CALL	CODECHECK_N
	MOVF	GST,W
	BTFSS	STATUS,Z	    ; State of GST
	GOTO	_CCHK_LOSE
	CALL	CCWIN	    ; GST is zero, play winner anim.
	CALL	CODE_RST
	GOTO	_GAME
_CCHK_LOSE
	CALL	CCLOSE	    ; GST is non-zero, so we lost.
	CALL	CODE_RST
	GOTO	_GAME

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; Subroutines
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::	
; CODE_RST will clear all numbers from C<1:6>. Modifies FSR and addr 2A to 2F.
CODE_RST
	CLRF	GST
	MOVLW	0x2A	    ;; Addressing INDF accesses the register whose addr
	MOVWF	FSR	    ;; is located at FSR. INDF -> &FSR
_NRST	CLRF	INDF
	INCF	FSR,F
	BTFSS	STATUS,5    ;; Digit carry (0010 1111 -> 0011 0000 will trigger)
	GOTO	_NRST
	RETURN

TEST_CODE
	MOVLF	0x2A,RC_ENC_1
	MOVLF	0x2B,RC_ENC_2
	MOVLF	0x2C,RC_ENC_3
	MOVLF	0x2D,RC_ENC_4
	MOVLF	0x2E,RC_ENC_5
	MOVLF	0x2F,RC_ENC_6
	RETURN
	
; Get a user input from keypad. As slow imprecise RC, fast presses may not be
; detected. Modifes WREG,FSR,PORTB. Returns the code in WREG.
; To get many codes, use N_PLAYER_INPUT, which will also account for CLR.
GET_INPUT_BLOCKING
	MOVLF	TMP1,.1	    ; tmp1 is current row.
_GET_INPUT
	MOVF	TMP1,W	    ; Enable row
	IORWF	PORTB,F
	MOVF	PORTA,W	    ; Get column result -> TMP
	ANDLW	b'1111'
	MOVWF	TMP
	MOVLW	b'11111000' ; Disable row without intefering with PORTB other.
	ANDWF	PORTB,F
	MOVF	TMP,W	    ; Check column result by masking potential junk
	BTFSS	STATUS,Z    ; 00000XXX is non zero?
	GOTO	_INPUT_SUCCESS ; Non zero means there was a button pressed.
	RLF	TMP1,F
	BTFSS	TMP1,3
	GOTO	_GET_INPUT	; loop not exceeded (00000XXX)
	MOVLF	TMP1,.1		; reset TMP1 to row .1
	GOTO	_GET_INPUT
_INPUT_SUCCESS
	RLFN	TMP,F,2		; deal w temp
	RLF	TMP,W
	IORWF	TMP1,F	      ;; '0CCCCRRR' Code format. Result stored in FSR
_INPUT_LOCK			;; Prevent blocking until low again.
	MOVF	PORTA,W		;; this is to hopefully prevent repeat
	ANDLW	b'111'		;; inputs. not accountign for bounce.
	BTFSS	STATUS,Z
	GOTO	_INPUT_LOCK
	RETURN

; Returns 1 in wreg if clr is presseed at that instant. Blocks until CLR
; is released again.
IS_CLR
	CLRF	PORTB
	BSF	PORTB,1
	BTFSS	PORTA,3
	RETLW	.0  
	BTFSC	PORTA,3		; INPUT TRAP
	GOTO	$-2
	RETLW	.1

; Generate pseudorandom number via waiting for the user to press CLR. Blocks for
; user input. Use N_PRNG to get many random numbers. Blocks until CLR release.
PSEUDO_PRNG_W
	CLRF	PORTB
	BSF	PORTB,1		; clr is on row 1 instead of a dedicated pin... oops!
	CLRF	TMP
	CLRF	TMP1
_RIN	RLNCIFZ	TMP,4		; The hope is that this can go fast enough
	BTFSS	STATUS,Z	; to make a fake input...
	GOTO __RINB		; TMP (C) was not reset (zero'd)
	RLNCIFZ	TMP1,3		; TMP (C) was reset, so we rotate/update R/TMP1
__RINB	BTFSS	PORTA,3
	GOTO	_RIN
	BTFSC	PORTA,3		; release trap
	GOTO	$-2
	BCF	PORTB,1
	RETURN	

; Checks a user input code against the code stored at *CPTR. The custom format
; is positively dependent on its mapped value, so "<,>,="-esque operations can
; be used without additional overhead.
CODECHECKER
	CALL	GET_INPUT_BLOCKING
	BTFSC	TMP1,6	    ; Bit exclusively used for CLR.
	RETLW	.1	    ; this state is not a normal CCCCRRR state (rst st.)
	MOVF	CPTR,W	    ; FSR state has to be loaded.
	MOVWF	FSR
	MOVF	TMP1,W
	SUBWF	INDF,W	    ; Twos complement representation
	BTFSC	STATUS,Z    ; Equals case
	RETURN
	BTFSS	TMP,7	    ; Test the MSB (negative bit). (aka wreg>F)
	GOTO	_CBYPLO
	BTFSS	GST,1	    ; MUTUALLY EXCLUSIVE BITS.
	BSF	GST,0	    ; Too high! (Set game state flags)
_CBYPLO	BTFSS	GST,0
	BSF	GST,1	    ; Too low!	
	RETURN
			    
; Checks user input (blocking) against a range of addresses (0x2A - 2F)
CODECHECK_N
	MOVLW	0x2A		    ; initial state
	MOVWF	CPTR
_CCHK_N	CALL	CODECHECKER	    ; get result
	SUBLW	.1		    ; if it is clr, -1 should yeild 0.
	BTFSC	STATUS,Z
	GOTO	CODECHECK_N	    ; start from the very stop
	INCF	CPTR,F
	BTFSC	STATUS,DC	    ; Still need to scan more codes
	GOTO	_CCHK_N		    ; 0010 1111 -> 0011 0000 = DC.
	RETURN

;; CCWIN: "Open Puzzle box" (portb7 high), and play scrolling right animation.
CCWIN	MOVLW	b'10000000'		;; Delay register init. (not precise timing)
	MOVWF	TMP1			
	MOVLW	b'00001000'		;; S1 initial positon
	MOVWF	TMP
WINL	RLF	TMP,F
	BTFSS	TMP,7			;; Bypass reset if it hasn't reached
	GOTO	_BYPWL			;; the end.
	MOVLW	b'1000'			;; Recentre/reset S1.
	MOVF	TMP,W  
_BYPWL	IORLW	B'10000000'		; '1XXXXXXX' (bit 7 will always be act.)
	MOVWF	PORTB			;; Applies current 'frame' of animation to PORTB
	DECFSZ	TMP1			;; repeat animation loop until delay is
	GOTO	WINL			;; finished.
	CLRF	PORTB
	RETURN

; Informs the user if their guess was too high (RA<4>) or too low (RA<4>).
; This subroutine assumes GST is non-zero, and has mutually exclusive flags.
CCLOSE	CLRF	PORTB			;; clear output pre-emptive
	MOVLW	b'10000000'		;; Init delay register (not precise.)
	MOVWF	TMP1
	RLFN	GST,F,3			;; 0000 00LH -> 00LH 0000
	RLF	GST,W
	MOVWF	PORTB
_CCLOSE	DECFSZ	TMP1
	GOTO	_CCLOSE			;; delay trap
	CLRF	PORTB
	RETURN
	
	END
	
    
; Changes in V2
;  + Indirect addressing is used much more instead of macros, optimizing the
;    program size. The indirect addressing method should also be faster in
;    execution, I believe, though this has not been analysed or benchmarked.
    ;  + Gamemodes - Using pre-processor directives, the program can be hard-set
    ;  to a certain play style. These are described later in the source.
    ;  - a lot of code!
    ;  ! I don't plan to test this outside of MPLAB. This was a fun exercise for
    ;  an evening, but I don't have access to the same 16F chip nor a programmer
    ;  as of rn.
    ;  ! Numbers are used differently on results, in CCCCRRR format (c=column
    ;  bits, r= row bits). 
    ;  ! relocateable code directives
    ;  ! buggy or dangerous code! lots of dead or unexpected RETURN statements
    ;  that could cause a stack crash (ie subsequent runs start within func.
    ;  CCLOSE!!)
    
    ; TODO LATER:
    ;  too high/low comparison (should be easy to implement... check row and
    ;  column bits independently (> , < , =)
    
    ; Ideas for a V3
    ; GET_INPUT_BLOCKING could be made non-blocking.
    ; Additional features, like a menu system, could be added. This could
    ; facilitate gamemodes.
    ; Sleep mode - the whole system could be battery powered and woken by a btn
    ; press. As with the current deisgn, the interruptable pins are occupied by
    ; LEDs.
    ; A crystal oscilator can be used. this would be drop in, as RA7,RA6 are
    ; available.
    ; A version using a crystal instead would be much more stable timing-wise,
    ; and we could provide timing/delay routines that will be very stable.
    ; code can be refactored to use the full 15 increment space for larger codes