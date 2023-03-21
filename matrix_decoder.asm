#include <p16f88.inc>
;; R0C0 is the entry subroutine for the keypad input subroutine.
;; Loops through turning on each row and checking each column and returning the relevant value for it.
;; When an input is found, it will trap it in a loop until it is released then return to the caller.
R0C0	CLRF	PORTB			;; Clear portB as a precaution
	BSF	PORTB,6			;; Tell user ready for input!
	
	BSF	PORTB,0			;; Turns on output for row 0 scanning
	BTFSS	PORTA,0			;; check if Row 0 Column 0 is high (keypad 1) 
	GOTO	R0C1			;; if button is not pressed go to the next one.
	MOVLW	d'1'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R0C1	BTFSS	PORTA,1			;; check if Row 0 Column 1 is high (keypad 2) 
	GOTO	R0C2			;; if button is not pressed go to the next one.
	MOVLW	d'2'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.
	
R0C2	BTFSS	PORTA,2			;; check if Row 0 Column 2 is high (keypad 3)
	GOTO	R1C0			;; if button is not pressed go to the next one.
	MOVLW	d'3'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R1C0	BCF	PORTB,0			;; Turns off output for row 0 scanning
	BSF	PORTB,1			;; Turns on output for row 1 scanning

	BTFSS	PORTA,0			;; check if Row 1 Column 0 is high (keypad 4)
	GOTO	R1C1			;; if button is not pressed go to the next one.
	MOVLW	d'4'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R1C1	BTFSS	PORTA,1			;; check if Row 1 Column 1 is high (keypad 6)
	GOTO	R1C2			;; if button is not pressed go to the next one.
	MOVLW	d'5'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R1C2	BTFSS	PORTA,2			;; check if Row 1 Column 2 is high (keypad 6) 
	GOTO	R1C3			;; if button is not pressed go to the next one.
	MOVLW	d'6'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R1C3	BTFSS	PORTA,3			;; check if Row 1 Column 3 is high (keypad CLR)
	GOTO	R2C0			;; if button is not pressed go to the next one.	;; ERROR HERE! MOVED TO R2C1
	GOTO	CODE0			;; reset to the start of the code checking sequence
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R2C0	BCF	PORTB,1			;; Turns off output for row 1 scanning
	BSF	PORTB,2			;; Turns on output for row 2 scanning

	BTFSS	PORTA,0			;; check if Row 2 Column 0 is high (keypad 7) 
	GOTO	R2C1			;; if button is not pressed go to the next one.
	MOVLW	d'7'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R2C1	BTFSS	PORTA,1			;; check if Row 2 Column 1 is high (keypad 8)
	GOTO	R2C2 			;; if button is not pressed go to the next one.
	MOVLW	d'8'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the file.
	GOTO	SCANE			;; since the button was pressed, we do not need to do any more scanning.

R2C2	BTFSS	PORTA,2			;; check if Row 2 Column 2 is high (keypad 9)
	GOTO	R0C0			;; if button not pressed go to the start of the code checker (This causes a loop starting at R0C0 to R2C2!)
	MOVLW	d'9'			;; Moves the value of keypad into the working register
	MOVWF	CCODE			;; Moves the content of the working register into the current code register
	BCF	PORTB,2			;; Turns off output for row 2 scanning
	
SCANE	MOVLW	b'00000111'		;; Set working register to 111 so we can turn on all rows for final scan
	MOVWF	PORTB			;; Set all scan rows to high so we can make sure all inputs are not pressed. (should also remove READY)
	
	;; since this is the end of the function we need to check that no button is pressed at this moment.
	MOVLW	0			;; move 1 in decimal into working register
	SUBWF	PORTA,W			;; take 1 from porta in W (for comparison method)    ;; code error, placed SUBLW	instead of SUBWF
	BTFSS	STATUS,Z		;; check if carry bit is up (this will happen if PORTA=0 then Z will = 1)
	GOTO	SCANE			;; loop until PORTA is empty.
	CLRF	PORTB			;; now we are out the loop, re-clear PORTB
	MOVF	CCODE,W		;; test
	MOVWF	PORTB
	RETURN	    ; end of function - this is where R0C0 entry goes back to caller!