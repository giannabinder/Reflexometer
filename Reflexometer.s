; ----------------------------------------------------------------------------
; Purpose:    Reflex0meter
; ----------------------------------------------------------------------------
                    THUMB                                           ; Thumb instruction set
                    AREA            My_code, CODE, READONLY         ; define this as a code area
                    EXPORT          __MAIN                          ; make __MAIN viewable externally
                    ENTRY                                           ; define the access point

__MAIN



SETUP               LDR             R10, =LED_BASE_ADR             ; R10 is a permenant pointer to the base address for the LEDs, offset of 0x20 and 0x40 for the ports

                    ; turn off port 1 LEDS
                    MOV             R2, #0xB0000000                ; store instruction to turn off port 1 LEDs in R3
                    STR             R2, [R10, #0x20]               ; implement the instruction

                    ; turn off port 2 LEDS
                    MOV             R2, #0x0000007C                ; store instruction to turn off port 1 LEDs in R3
                    STR             R2, [R10, #0x40]               ; implement the instruction

                    MOV             R11, #0xABCD                   ; init the random number generator with a non-zero number

                    ; initialize registers we will use to zero
                    MOV32           R0, #0                         ; R0 holds the delay time
                    MOV32           R1, #0                         ; R1 holds the instructions to turn the port 2 LEDs on or off in the DISPLAY_NUM subroutine and is the counter for the SHOW_TIME loop
                    MOV32           R2, #0                         ; R2 holds the instructions to turn the port 1 LEDs on or off and is the cycle counter in the DELAY subroutine
                    MOV32           R3, #0                         ; R3 is holds the number to be displayed through the LEDs
                    MOV32           R5, #0                         ; R5 is used for general computations


RESTART             BL              RANDOM_NUM                     ; get a random number and store it in R11
                    MOV32           R4, #0                         ; R4 will hold the reaction time



CALC_RANDOM_DELAY   MOV             R0, #0xFFFF                    ; isolate the last 16 bits of R11
                    AND             R0, R11, R0
                    AND             R5, R11, #0x0001               ; put LSB of R11 into R5
                    TEQ             R5, #0                         ; if the LSB of R11 is 0 scale the number by adding, otherwise, scale by subtracting
                    BEQ             SCALE_ADDING
                    BNE             SCALE_SUBTRACTING



SCALE_ADDING        BL              ADDING  
                    BL              DELAY                           ; begin the delay                          
                    B               TURN_LED_ON                     ; turn the LED on



SCALE_SUBTRACTING   BL              SUBSTRACTING
                    BL              DELAY                           ; begin the delay
                    B               TURN_LED_ON                     ; turn the LED on



; scale by the delay (R0) by adding 19,998 to the random number, this gives a number between 20,000 and 85,534
ADDING              STMFD           R13!,{R14}                      ; preserve the link register
                    ADD             R0, R0, #0x20                   ; add 30 to R0
                    ADD             R0, R0, #0X4E00                 ; add 19,968 to R0 (resulting in a total of 19,999 added to R0)
                    LDMFD           R13!,{R15}                      ; return and restore modified registers



; scale by the delay (R0) by substracting the random number from 100,001, this gives a number between 34,466 and 100,000
SUBSTRACTING        STMFD           R13!,{R5, R14}                  ; preserve LR and R5
                    MOV32           R5,#0x186A1                     ; have R5 hold 100,001
                    SUB             R0, R5, R0                      ; perform 100,001 - R0  
                    LDMFD           R13!,{R5, R15}                  ; return and restore modified registers



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; PROVING OUR SCALING MEETS 2 TO 10 SECOND DELAY WITH +/-5% ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1) We take the LSB of the number generated from RANDOM_NUM (R11)
;       - it is given that this number is from 1 to 65535
; 2) If this number is even we scale by adding. Otherwise, we scale by subtracting.
;       a) Scaling by adding:
;               - Since this scaling method is only called with even numbers, our lowest received random number is 2 and highest is 65,534
;               - Thus, if we add 19,998 to our random number, the lowest delay we receive is 2+19,998 = 20,000 and the highest is 65,534+19,998 = 85,532
;       b) Sacling by subtracting
;               - Since this scaling method is only called with odd numbers, out lowest receives random number is 1 and highest is 65,534
;               - Thus, if we subtract out random number from 100,001, the lowest delay we receive is 100,001-1=100,000 and the highest is 100,001-65,535=34,466
;       - Overall, our delay spans from 20,000*0.1ms to 100,000*0.1ms = 2s to 10s exactly. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



TURN_LED_ON         MOV             R2, #0x90000000                 ; store the instruction to turn LED 29 on in R2
                    STR             R2, [R10, #0x20]                ; turn LED 29 on



; measure the user's reaction time
POLL                LDR             R2, =FIO2PIN                    ; store address of FIO2PIN in R2
                    LDR             R2, [R2]                        ; read status of FIO2PIN into R2
                    TST             R2, #0x0400                     ; determine value of the tenth bit of FIO2PIN
                    BEQ             REACTED                         ; if the tenth bit is 0, the user has reacted by pushing INT0
                    ADD             R4, R4, #1                      ; increase the reaction counter
                   
                    ; implement a 0.1ms delay
                    MOV32           R0, #1                          ; store the number of 0.1ms delays into R0                    
                    BL              DELAY                           ; branch to the DELAY subroutine

                    B               POLL                            ; poll again



REACTED             MOV             R2, #0xB0000000                 ; store the instruction to turn LED 29 off in R3
                    STR             R2, [R10, #0x20]                ; turn LED 29 off
                    MOV32           R1, #4                          ; store the SHOW_TIME loop counter in R1
                    MOV             R5, R4                          ; put the reaction time into R5



SHOW_TIME           MOV             R3, #0xFF                        ; set the last eight bits of R3 to 1 to help extract the last eight bits of R4 into R3 in the next instruction
                    AND             R3, R3, R5                      
                    LSR             R5, R5, #8                      ; shift R4 eight to the right to prepare to display the next eight bits in the following loop
                    BL              DISPLAY_NUM                     ; display the reaction time on the LEDs
                    MOV32           R0, #0x4E20                     ; store 20,000 into R0 to result in a delay of two seconds
                    BL              DELAY                           ; go to the delay subroutine
                    SUBS            R1, R1, #1                      ; decrement the counter and set the PSR flag
                    BEQ             END_DELAY                       ; if the counter is 0, we have displayed the entire number. Branch to END_DELAY to display an additional 5 seconds
                    B               SHOW_TIME                       ; loop again to display the next eight bits on the LEDs if we have not finished displaying the reaction time
                   
                   
END_DELAY           MOV32           R0, #0xC350                     ; store 50,000 into R0 to result in an additional five second delay
                    BL              DELAY                           ; go to the delay subroutine
                    B               REACTED                         ; replay the reaction time program



; Display the number in R3 onto the 8 LEDs
DISPLAY_NUM         STMFD           R13!,{R1, R2, R3, R5, R14}      ; preserve registers we are modifying
                    EOR             R3, R3, #0xFF                   ; flip the bits as the LEDs are active low

                    ; get instruction for port 2 LEDs
                    MOV32           R1, 0x0000001F                  ; make the five LSBs OF R1 high to help isolate the bits of the reaction time number corresponding to port 2 in the next line
                    AND             R1, R1, R3                          
                    LSL             R1, R1, #27                          
                    RBIT            R1, R1                          ; reverse the bit's order (as the LEDs of port 2 are in increasing order from right to left)
                                                                    ; CLZ ensures that the five bits we wanted are in the least significant positions when the bit's positions are reversed
                    LSL             R1, #2                          ; shift the bits two to the left so the LSB now aligns with the bit instruction of P2.2

                    ; get instruction for port 1 LEDs
                    MOV32           R2, 0x000000C0                  ; make bits 6 and 7 of R2 high to help isolate the bits of the reaction time number corresponding to port 1 in the next line
                    AND             R2, R3        
                    LSR             R2, #6                          ; shift R2 to the right 6 bits so the bits for P1.28 and 29 align with their bit in the instruction              
                    MOV32           R5, #0x20                       ; make the fifth bit of R5 high to help isolate the bit corresponding to P1.31 in R3
                    AND             R5, R3
                    LSR             R5, #2                          ; shift R5 3 to the right to align the fifth bit with P1.31's bit in the instruction
                    ADD             R2, R5                          ; add R2 and R5 together to make the full instruction of port 1
                    LSL             R2, #28

                    ; implement LEDs instructions
                    STR             R2, [R10, #0x20]                ; port 1
                    STR             R1, [R10, #0x40]                ; port 2

                    LDMFD           R13!,{R1, R2, R3, R5, R15}      ; return and restore modified registers



; generate a random 16-bit number
RANDOM_NUM          STMFD           R13!,{R1, R2, R3, R14}
                    AND             R1, R11, #0x8000
                    AND             R2, R11, #0x2000
                    LSL             R2, #2
                    EOR             R3, R1, R2
                    AND             R1, R11, #0x1000
                    LSL             R1, #3
                    EOR             R3, R3, R1
                    AND             R1, R11, #0x0400
                    LSL             R1, #5
                    EOR             R3, R3, R1                      ; the new bit to go into the LSB is present
                    LSR             R3, #15
                    LSL             R11, #1
                    ORR             R11, R11, R3
                    LDMFD           R13!,{R1, R2, R3, R15}



; Subroutine which causes a delay
DELAY               STMFD           R13!, {R2, R14}                 ; preserve the registers we are modifying
                    MOV             R2, #0x0085                     ; set the counter to the number of DELAY_LOOP loops which results in 0.1ms time
                                                                    ; (4M/s)*(0.0001s) = 400 cyles per 0.1ms
                                                                    ; (400 cycles) / (3 cycles/delay loop) = 133 loops    
                    MUL             R2, R2, R0                      ; store the total delay value in R2 by multiplying it by R0 (R0 holds the time in 0.1ms the program needs to delay)               

DELAY_LOOP          ; begin the delay  
                    SUBS            R2, #0x1                        ; decrement the delay counter
                    BGT             DELAY_LOOP                      ; continue decreasing the delay counter until it reaches zero                          

EXIT_DELAY          LDMFD           R13!,{R2, R15}                  ; set the PC to the line after the line which called this subroutine
               

LED_BASE_ADR        EQU             0x2009C000                      ; Base address of the memory that controls the LEDs
PINSEL3             EQU             0x4002C00C                      ; Address of Pin Select Register 3 for P1[31:16]
PINSEL4             EQU             0x4002C010                      ; Address of Pin Select Register 4 for P2[15:0]
FIO2PIN             EQU             0x2009C054                      ; Address of FIOPIN  - register to read and write pins

                    ALIGN

                    END


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;LAB REPORT QUESTIONS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; 1- If a 32-bit register is counting user reaction time in 0.1 milliseconds increments, what is the maximum amount of time which can be stored in 8 bits, 16-bits, 24-bits 
;    and 32-bits?
;       a) 8-bits:
;           - The maximum value in decimal of an 8 bit number is 255. Thus, 255*0.1ms = 25.5ms = 0.0255s.
;       b) 16-bits:
;           - The maximum value in decimal of an 16 bit number is 65,535. Thus, 65,535*0.1ms = 6,553.5ms = 6.5535s.
;       c) 24-bits:
;           - The maximum value in decimal of an 24 bit number is 16,777,215. Thus, 167,77,215*0.1ms = 1,677,721.5ms = 1,677.7215s = 1,677.7215s * min/60s = 27.962025min
;       d) 32-bits:
;           - The maximum value in decimal of an 32 bit number is 4,294,967,295. Thus, 4,294,967,295*0.1ms = 429,496,729.5ms = 429,496.7295s = 429,496.7295s * min/60s = 
;             7158.278825min = 7158.278825min * hr/60min = 119.3046471hr.
;
; 2- Considering typical human reaction time, which size would be the best for this task (8, 16, 24, or 32 bits)?
;       - According to "Speedy Science: How Fast Can You React" from Scientific American, the typical human reaction time is between 150ms to 300ms = 0.150s to 0.3s. Thus,
;         16 bit is ideal as it is the least amount of bits which spans the range.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;