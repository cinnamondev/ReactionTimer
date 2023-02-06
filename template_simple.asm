;---------------------------------------------------
;   CINNAMONDEV
;	Reaction Timer Project - V2
;---------------------------------------------------
;
;   CONFIG WORDS
;
;; TODO: goal for the next few weeks afterwards is to adapt to PIC18 chip.
;; In its current state, im hoping to make this project cleaner than i wrote it
;; originally. 
#include    <p16f88.inc>   ; Include processor defintions.
LIST	    P=16F88	    ; Define uc

;Program Configuration Register 1
; EXTRCIO, WTDEN disable t  d, PWRTE disabled,
; RA5 is MCLR, BOR enabled, LVP enable, CPD Code prot off,
__CONFIG    _CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_ON & _BODEN_ON & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _EXTRC_IO

;Program Configuration Register 2
; Clock Fail-Safe disabled, 
; int.ext switchover disabled.
__CONFIG    _CONFIG2, _IESO_OFF & _FCMEN_OFF
;---------------------------------------------------
; Vectors
    
RST_VEC CODE h'00' ; Reset vector at address 00.
	GOTO MAIN
	
ISR	CODE h'04' ; Interrupt vector at address 04.
	RETFIE
;---------------------------------------------------
; Macros
delay macro ms
    
    endm
	
;---------------------------------------------------
; Main program
MAIN	CLRF PORTB
	MOVLW B'00000001'
	MOVWF PORTB
	GOTO MAIN
	
;---------------------------------------------------
; Subroutines


    END
    
    