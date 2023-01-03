	LIST P=16F88
	__CONFIG H'2007', H'3FFA'       ; EXTRCIO, WTDEN disabled, PWRTE disabled,
	; RA5 is MCLR, BOR enabled, LVP enable, CPD Code prot off,
	; Write prot off, ICDB disabled, CCP1 on RB0, CP flash prot off.
	__CONFIG H'2008', H'3FFC'       ; Clock Fail-Safe disabled, 
	; int.ext switchover disabled.

;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 

				
#DEFINE	PAGE0	BCF 	STATUS,5	
#DEFINE	PAGE1	BSF 	STATUS,5	

	; define SFRs
	
OPSHUN	EQU	H'81'		;
STATUS	EQU	H'03'		;defines status register
TRISA	EQU	H'5'		;defines trisA register
PORTA	EQU	H'05'		;defines portA register
TRISB	EQU	H'6'		;defines TrisB register
PORTB	EQU	H'06'		;defines portB register
PCL	EQU	H'02'		;Names the register called program counter
W	EQU	0		;Sets up the name used for the working register
F	EQU	1		;Sets up the name used for file
Z	EQU	2		;Sets up the name used for the zero flag
C      	EQU 	0          	;Sets up the name used for the carry flag

;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;       VECTORS

	ORG	00		; Reset vector
	GOTO	XYZ		; Goto start of program 
	ORG	04		; Interrupt vector address
	GOTO	05		; Goto start of program
	ORG	05		; Start of program memory
		
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;       NAME YOUR REGISTERS HERE 

;; All our code registers.
CCODE	EQU	H'2F'			;; CCODE (Current Code) register - holds current code on inputs
A	EQU	H'20'			;; A register - is used like a boolean and determines win or loss
					;; If A=1 lose -  A=0 win

C1	EQU	H'2A'			;; C1-6 are all code digit registers.
C2	EQU	H'2B'			;; We will handle each digit as a value to guess 
C3	EQU	H'2C'			;; independently but then compare when you lose as a whole.
C4	EQU	H'2D'
C5	EQU	H'2E'
C6	EQU	H'3A'


D	EQU	H'2E'			;; Delay register for win / lose
S1	EQU	H'3D'			;; Sequence side 1 for win
	
LOWc	EQU	H'3E'			;; register that defines when the code was too low (will update on each incorrect code, if 0 we will consider it high.)
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ::::::::::: 

;       THIS SECTION IS USED TO SET THE DIRECTION OF THE OUTPUT PORTS. 

XYZ	BSF	STATUS,5		;;Bank 1 operation 
    CLRF	H'1B'			;;Makes the ANSEL (analogue) inputs digital 
    MOVLW	B'00011111'		;;
    MOVWF	TRISA			;;   Set PORTA to all inputs. 
    MOVLW	B'00000000'		;; 
    MOVWF	TRISB			;;   Set PORTB to all outputs. 
    BCF	STATUS,5			;;Back to bank 0 

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 
;	MAIN PROGRAM 
 
start	CLRF	PORTB			;; clear PORTB - precaution
	MOVLW	0			;; empty working register
	MOVWF	A			;; move empty working register into files
	MOVWF	CCODE			;; /\
	MOVWF	LOWc			;; /\
	
	CALL	RCODE0			;; Reaction code input method.
	;;CALL	TCODE			;; test function - uncomment if needed (but comment out RCODE0!)
	CALL	CODE0			;; Code checking method (based on code inputted in RCODE0)
	GOTO	start			;; Loop at end! (if code is created and correctly guessed we will reset all crucial values)

;	write your program here. 	 

;;	Pin usage 
;; 
;;	PORTB7		unlock/lock 'puzzle' (delay thing for win/lose) 
;;	PORTB0:2	keypad matrix outputs (for rows) 
;;	PORTB3:6	scroll left (keypad will not be affected due to it not being actively scanned)
;;	PORTB4		indicate too low
;;	PORTB5		indicate too high
;;	PORTB6		indicate 'ready'
;;	PORTA0:3	keypad matrix inputs (for columns)  

;;	Primary/entry functions
;;	    RCODE0  - Reaction/random code input subroutine. Programs in C1:6
;;	    RCODE   - The subroutine for each RCODE* that allows values from 1-9 to come out, with it looping when called until PORTA,3 is pressed & released.
;;			^ (Value is returned in CCODE)
;;	    CODE0   - Code guesser entry subroutine. Gets input from keypad
;;	    R0C0    - Entry subroutine for the keypad scanner. Results are stored in CCODE
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 
	
;	SUBROUTINES 
; Any subroutines to go in this section.  

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 
;;	REACTION INPUT						;;
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 
	
;; RCODE subroutine - loops CCODE from 11 to 2 (if it hits 1 it resets).
;; If CLR button on keypad matrix is pressed, the loop ends and whatever value is there (minus one)
;; is kept in CCODE (to be moved into the relevant C* slot by the caller.)
	;; Set CCODE to limit
RCODE	MOVLW	d'11'			;; Set working register to 11
	MOVWF	CCODE			;; Set CCODE to working register (we are setting CCODE to 11 here so its 2 above the limit so at all times its 1-9 by the end)
	
	BSF	PORTB,1			;; Turn on second row of the keypad. Will allow for pressing of CLR in the keyboard matrix.
B3OFF	BTFSC	PORTA,3			;; Loop if portA3 is on (clr button) (forces release after each input)		;;error 2 mixed up (SC SS)
	GOTO	B3OFF			;; Loop until portA3 is off

RLOOP	DECF	CCODE			;; CCODE-1 (Prevents values out of range for input being sent to registers & decreases until hits lower limit)
	MOVLW	1			;; 1 --> WREG (Change this value to change the floor of the code checker)
	SUBWF	CCODE,W			;; CCODE-W --> W, If result = 0 the values must be equal (1=1), therefore CCODE needs reset. 
	BTFSC	STATUS,Z		;; Z should be 1 when the result of the line above is 0 (Z is zero bit)
	GOTO	CCRST			;; Reset the CCODE register to the limit+2 for possible codes
	BTFSS	PORTA,3			;; Check if portA3 is released, enter a loop until it  is pressed.		;; error 2 mixed up (SC SS)
	GOTO	RLOOP			;; Loop until portA3 is pressed.
	BCF	PORTB,1			;; We can turn off the row for the CLR button in the keypad as we are done with it
	DECF	CCODE			;; Take 1 from the final value (this prevents the program from ever being in a value such as 11 or something)
	MOVF	CCODE,W			;; Move copy of CCODE into WREG
	RETURN		
	
CCRST	MOVLW	d'11'			;; move limit for ccode into working register
	MOVWF	CCODE			;; move working register (d'11') into CCODE/set to limit
	GOTO	RLOOP			;; go to the start of the loop (causing it to lose 1 value so its always "11>CCODE>1"
 
;; Reaction code inputs - add codes to all respective code digit slots.
RCODE0	CALL	RCODE			;; Call RCODE function - use value in CCODE register after
	MOVF	CCODE,W			;; move ccode into working register
	MOVWF	C1			;; Move CCODE (W) value into C1, program in new code digit.
	
RCODE1	CALL	RCODE			;; Call RCODE function - use value in CCODE register after
	MOVF	CCODE,W			;; move ccode into working register
	MOVWF	C2			;; Move CCODE (W) value into C2, program in new code digit.
	
RCODE2	CALL	RCODE			;; Call RCODE function - use value in CCODE register after
	MOVF	CCODE,W			;; move ccode into working register
	MOVWF	C3			;; Move CCODE (W) value into C3, program in new code digit.
	
RCODE3	CALL	RCODE			;; Call RCODE function - use value in CCODE register after
	MOVF	CCODE,W			;; move ccode into working register
	MOVWF	C4			;; Move CCODE (W) value into C4, program in new code digit. 
	
RCODE4	CALL	RCODE			;; Call RCODE function - use value in CCODE register after
	MOVF	CCODE,W			;; move ccode into working register
	MOVWF	C5			;; Move CCODE (W) value into C5, program in new code digit.
	
RCODE5	CALL	RCODE			;; Call RCODE function - use value in CCODE register after
	MOVF	CCODE,W			;; move ccode into working register
	MOVWF	C6			;; Move CCODE (W) value into C6, program in new code digit.	
	RETURN				;; end of all reaction code inputs - return so we can continue.

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 
;;	TESTS							;; 
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 
	
; Test code function.. works well for testing the functionality of the code guesser
TCODE	MOVLW	d'8' ;; Test subroutine for code guesser. Sets all codes to 1.
	MOVWF	C1   ;; To use comment out CALL RCODE0 and call this one below
	MOVWF	C2
	MOVWF	C3
	MOVWF	C4
	MOVWF	C5
	MOVWF	C6
	RETURN
	
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 
;;	WIN/LOSE SCENARIOS	;; 
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 

 
;; CCWIN FUNCTION - when you win the code guesser the program will jump here.
;; CCWIN will turn on PORTB7 for a period of time (where in a puzzle box it would trigger a solenoid or similar),
;; and play a 'scrolling right' animation.
	
	;; Fill delay register to max.
CCWIN	MOVLW	b'10000000'		;; Set W to 128
	MOVWF	D			;; Set delay register to max
	;; Sets S1 register to it's initial value.
	MOVLW	b'00001000'		;; Set to center position
	MOVWF	S1			;; Set S1 to starting point
	
	;; Animates S1 with bit shift lefts until it reaches B7 
WINL	MOVF	S1,W			;; S1 -> Working reg
	ADDWF	S1			;; S1+W(S1)->S1 (Shifts bits 1 left) (NOTE: bits are flipped flipped in reality so it actually goes right)
	BTFSC	S1,7			;; Check if S1 has reached PORTB7
	CALL	S1R			;; Reset S1 to it's initial position
	
	MOVF	S1,W			;; Move S1 into working register
	IORLW	B'10000000'		;; '10000000' + W (S1), Ensures PORTB7 is on.
	MOVWF	PORTB			;; Applies current 'frame' of animation to PORTB
	
	DECFSZ	D			;; Decreases value in delay register until it = 0
	GOTO	WINL			;; Loop until delay register has been emptied
	CLRF	PORTB			;; clear portb once loop finished
	GOTO	start			;; Once loop has ended, go to the start of the program.
	RETURN

	;; Resets S1 register to initial position
S1R	MOVLW	b'00001000'		;; Move center starting point for S1 
	MOVWF	S1			;; Set S1 to starting point
	RETURN
	
 
;; CCLOSE FUNCTION - when you lose the code guesser game you go here.
;; Performs the calculation for if you were too low or too high and indicates
;; on PORTB4 and 5 respectively. Loops a delay afterwards then after delay
;; returns to the start of the code guesser (to allow you to try again)
	
;; Potential easy implementation would be 'lives' but time. (ie you have 3 lives
;; and if it reaches 0 after the delay the program enters a trap/inf loop)
	
;; If you lose it will calculate whether you were too high or too low in your guess. PORTB4 = too low! PORTB5 = high!
CCLOSE	CLRF	PORTB			;; cleanup
	MOVLW	b'10000000'		;; Set W to 128
	MOVWF	D			;; Set delay register to max
	BTFSS	LOWc,0			;; check if LOW is on or off
	GOTO	HIGHL
	BSF	PORTB,4			;; Indicate code guess was too low
	GOTO	LOSEL			;; loop at this point so we dont get high
HIGHL	BSF	PORTB,5			;; Indicate code guess was too high
LOSEL	DECFSZ	D			;; Delay loop - decrement D (Delay) register until equals 0
	GOTO	LOSEL			;; Go to start of loop
	CLRF	PORTB
	GOTO	CODE0			;; When loop ends - go to the start of the codechecker function so you can try again.
	RETURN
	
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 
;;	CODE CHECKER						;;  
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;; 

;; Code0 is our entry point for the code checker.
;; Goes through C0-5 (where the relevant registers are C1-6) and gets input
CODE0	CLRF	PORTB			;; Clear PORTB as a precaution
	CLRF	A			;; clear losing register
	CLRF	LOWc			;; clear low indicator register
	
	CALL	R0C0			;; Get a keypad input --> CCODE
	MOVF	CCODE,W			;; Move CCODE (Keypad input) -> W 
	SUBWF	C1,W			;; Check if CCODE is equal to the programmed in code. (C1-W(CCODE) --> W)
	BTFSC	STATUS,Z		;; If CCODE=C1 STATUS,Z should be 1! (Z is zero status bit) (Thus if code is correct do not skip)
	GOTO	CODE1			;; Go to the next code check
	
	MOVF	C1,W			;; C1-->WORKING REGISTER
	SUBWF	CCODE,W			;; CCODE-C1 --> WORKING REGISTER
	;; IF C1 >= CCODE CCODE IS TOO LOW
	BTFSC	STATUS,C		;; skip low indicator if not >=
	GOTO	LSK0
	MOVLW	B'1'			;; Indicate too low!
	MOVWF	LOWc
	
LSK0	MOVLW	B'1'			;; Indicate incorrect code.
	MOVWF	A			;; Move 1 from W into A register, indicating code was guessed wrong. (used in CGEND)

CODE1	CALL	R0C0			;; Get a keypad input --> CCODE
	MOVF	CCODE,W			;; Move CCODE (Keypad input) -> W 
	SUBWF	C2,W			;; Check if CCODE is equal to the programmed in code. (C2-W(CCODE) --> W)
	BTFSC	STATUS,Z		;; If CCODE=C2 STATUS,Z should be 1! (Z is zero status bit) (Thus if code is correct do not skip)
	GOTO	CODE2			;; Go to the next code check
	
	MOVF	C5,W			;; C2-->WORKING REGISTER
	SUBWF	CCODE,W			;; CCODE-C2 --> WORKING REGISTER
	;; IF C2 >= CCODE CCODE IS TOO LOW
	BTFSC	STATUS,C		;; skip low indicator if not >=
	GOTO	LSK1
	MOVLW	B'1'			;; Indicate too low!
	MOVWF	LOWc			;; move indicator into LOW register
	
LSK1	MOVLW	B'1'			;; Indicate incorrect code.
	MOVWF	A			;; Move 1 from W into A register, indicating code was guessed wrong. (used in CGEND)

CODE2	CALL	R0C0			;; Get a keypad input --> CCODE
	MOVF	CCODE,W			;; Move CCODE (Keypad input) -> W 
	SUBWF	C3,W			;; Check if CCODE is equal to the programmed in code. (C3-W(CCODE) --> W)
	BTFSC	STATUS,Z		;; If CCODE=C3 STATUS,Z should be 1! (Z is zero status bit) (Thus if code is correct do not skip)
	GOTO	CODE3			;; Go to the next code check
	
	
	MOVF	C3,W			;; C3-->WORKING REGISTER
	SUBWF	CCODE,W			;; CCODE-C3 --> WORKING REGISTER
	;; IF C3 >= CCODE CCODE IS TOO LOW
	BTFSC	STATUS,C		;; skip low indicator if not >=
	GOTO	LSK2
	MOVLW	B'1'			;; Indicate too low!
	MOVWF	LOWc			;; move indicator into LOW register
	
LSK2	MOVLW	B'1'			;; Indicate incorrect code.
	MOVWF	A			;; Move 1 from W into A register, indicating code was guessed wrong. (used in CGEND)

CODE3	CALL	R0C0			;; Get a keypad input --> CCODE
	MOVF	CCODE,W			;; Move CCODE (Keypad input) -> W 
	SUBWF	C4,W			;; Check if CCODE is equal to the programmed in code. (C4-W(CCODE) --> W)
	BTFSC	STATUS,Z		;; If CCODE=C4 STATUS,Z should be 1! (Z is zero status bit) (Thus if code is correct do not skip)
	GOTO	CODE4			;; Go to the next code check
	
	MOVF	C4,W			;; C4-->WORKING REGISTER
	SUBWF	CCODE,W			;; CCODE-C4 --> WORKING REGISTER
	;; IF C4 >= CCODE CCODE IS TOO LOW
	BTFSC	STATUS,C		;; skip low indicator if not >=
	GOTO	LSK3
	MOVLW	B'1'			;; Indicate too low!
	MOVWF	LOWc			;; move indicator into LOW register
	
LSK3	MOVLW	B'1'			;; Indicate incorrect code.
	MOVWF	A			;; Move 1 from W into A register, indicating code was guessed wrong. (used in CGEND)

CODE4	CALL	R0C0			;; Get a keypad input --> CCODE
	MOVF	CCODE,W			;; Move CCODE (Keypad input) -> W 
	SUBWF	C5,W			;; Check if CCODE is equal to the programmed in code. (C5-W(CCODE) --> W)
	BTFSC	STATUS,Z		;; If CCODE=C5 STATUS,Z should be 1! (Z is zero status bit) (Thus if code is correct do not skip)
	GOTO	CODE5			;; Go to the next code check
	
	MOVF	C5,W			;; C5-->WORKING REGISTER
	SUBWF	CCODE,W			;; CCODE-C5 --> WORKING REGISTER
	;; IF C5 >= CCODE CCODE IS TOO LOW
	BTFSC	STATUS,C		;; skip low indicator if not >=
	GOTO	LSK4
	MOVLW	B'1'			;; Indicate too low!
	MOVWF	LOWc			;; move indicator into LOW register
	
LSK4	MOVLW	B'1'			;; Indicate incorrect code.
	MOVWF	A			;; Move 1 from W into A register, indicating code was guessed wrong. (used in CGEND)

CODE5	CALL	R0C0			;; Get a keypad input --> CCODE
	MOVF	CCODE,W ;; Move CCODE (Keypad input) -> W 
	SUBWF	C6,W			;; Check if CCODE is equal to the programmed in code. (C6-W(CCODE) --> W)
	BTFSC	STATUS,Z		;; If CCODE=C1 STATUS,Z should be 1! (Z is zero status bit) (Thus if code is correct do not skip)
	GOTO	CGEND			;; Go to the end of the program.
	
	MOVF	C6,W			;; C6-->WORKING REGISTER
	SUBWF	CCODE,W			;; CCODE-C5 --> WORKING REGISTER
	;; IF C6  >= CCODE CCODE IS TOO LOW
	BTFSC	STATUS,C		;; skip low indicator if not >=
	GOTO	LSK5
	MOVLW	B'1'			;; Indicate too low!
	MOVWF	LOWc			;; move indicator into LOW register
LSK5	MOVLW	B'1'			;; Move 1 into working register
	MOVWF	A			;; Move 1 from W into A register, indicating code was guessed wrong. (used in CGEND)
CGEND	;; You end up here once all the codes are inputted.
	BTFSC	A,0			;; Check the value of the A register - determines if we win (if A0 is 1 we lose)
	GOTO	CCLOSE			;; Lose scenario - skipped if A0 is clear.
	GOTO	CCWIN			;; Win scenario

	RETURN 

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
 
    
	END