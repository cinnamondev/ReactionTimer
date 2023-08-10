# PICNEA / ReactionTimer
Y12 Electronics coursework for PIC16F88

## V2

Original macro version seems to have been lost, so a rewrite that does the keypad snazz in less lines! Currently untested fully... but its there :) and VERY much so improves on dead and bad code. 

## future ideas

interrupt based keypad reading. PIC16F has limited interruptable pins, and none of them are RB<0:2> or RA<0:3>, annoyingly. This is a flaw with the original design and could be corrected
with access to a similar or identical uc and programmer. a future version could also straight up use a different uc, as we are choked for pins here. it would also use a stable clock. ( the old original design had an unstable RC clock)
