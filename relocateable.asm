;; The following is a custom template by Cinnamondev for writing
;; relocateable code for MPASM.

;; Project name - Author
;; Source link
;; License notice
;; Assembler
;; Chip
    
;; Revision history
;;
;; Revision history (TEMPLATE) (Remove in use)
;; - Adapting for support for the PIC18F8722.
;--------------------------------------------------------------------------;
; Definitions and links
; Define processor & include special definitions (saves us time!)
    #include <p16f88.inc>
    LIST P=16F88
    
;------------------------------------------------------------------------------;
; Vectors
.RESET	code 0x00 ; Execution begins here.
	
    
;------------------------------------------------------------------------------;	