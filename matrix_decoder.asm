#include <p16f88.inc>
;; R0C0 is the entry subroutine for the keypad input subroutine.
;; Loops through turning on each row and checking each column and returning the relevant value for it.
;; When an input is found, it will trap it in a loop until it is released then return to the caller.
	udata
OUTCODE	res .1
	GLOBAL	OUTCODE
	
	CODE
SCAN	
	GLOBAL	SCAN
	BSF	PORTB,6			; ready for input
i=0	
	while i<3
j=0	
	BSF	PORTB,i	    ; turn on row matrix i
	while j<3
	    BTFSS   PORTA,j ; check column j
	    GOTO    $+6
	    MOVLW   j<<4 + i
	    MOVWF   OUTCODE   ; if no skip, write and return.
	    RETURN
j++	    
	endw
	BCF	PORTB,i	    ; turn off row matrix i
i++	
	endw
	BCF	PORTB,6			; nope
	RETURN
	
	END