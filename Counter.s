; ----------------------------------------------------------------------------
; Group:      Group 9- Gianna Binder and Nain Abdi
; File:       Lab_3_Group_9.s
; Purpose:    Counter
; ----------------------------------------------------------------------------
                    THUMB                                           ; Thumb instruction set
                    AREA            My_code, CODE, READONLY         ; define this as a code area
                    EXPORT          __MAIN                          ; make __MAIN viewable externally
                    ENTRY                                           ; define the access point

__MAIN



SETUP               LDR             R10, =LED_BASE_ADR              ; R10 is a permenant pointer to the base address for the LEDs, offset of 0x20 and 0x40 for the ports

                    ; turn off port 1 LEDS
                    MOV             R2, #0xB0000000                 ; store instruction to turn off port 1 LEDs in R3
                    STR             R2, [R10, #0x20]                ; implement the instruction

                    ; turn off port 2 LEDS
                    MOV             R2, #0x0000007C                 ; store instruction to turn off port 1 LEDs in R3
                    STR             R2, [R10, #0x40]                ; implement the instruction

RESTART             MOV32           R3, #0

SHOW_TIME           TEQ             R3, #0xFF                      
                    BEQ             END_DELAY                       ; branch to END_DELAY if we have counted to 255
                    BL              DISPLAY_NUM                     ; display the reaction time on the LEDs
                    ADD             R3, #0x00000001                 ; increment the counter
                    MOV32           R0, #0x1                        ; store 1 into R0 to result in an additional one ms delay
                    BL              DELAY                           ; go to the delay subroutine
                    B               SHOW_TIME                       ; loop again to display the next eight bits on the LEDs if we have not finished displaying the reaction time
                   
                   
                   
END_DELAY           MOV32           R0, #0x1                        ; store 1 into R0 to result in an additional one ms delay
                    BL              DELAY                           ; go to the delay subroutine
                    B               RESTART                         ; replay the reaction time program

; Display the number in R3 onto the 8 LEDs
DISPLAY_NUM         STMFD           R13!, {R1, R2, R3, R5, R7, R14} ; preserve registers we are modifying
                    EOR             R7, R3, #0xFF                   ; flip the bits as the LEDs are active low

                    ; get instruction for port 2 LEDs
                    MOV32           R1, #0x0000001F                  ; make the five LSBs OF R1 high to help isolate the bits of the reaction time number corresponding to port 2 in the next line
                    AND             R1, R1, R7                          
                    LSL             R1, R1, #27                          
                    RBIT            R1, R1                          ; reverse the bit's order (as the LEDs of port 2 are in increasing order from right to left)
                                                                    ; CLZ ensures that the five bits we wanted are in the least significant positions when the bit's positions are reversed
                    LSL             R1, #2                          ; shift the bits two to the left so the LSB now aligns with the bit instruction of P2.2


                    ; get instruction for port 1 LEDs, R2 holds the instruction we will write to the port

                    ; get bit 7 and put it in the 28th bit of R2
                    MOV32           R2, 0x00000080                  ; make only the 7th bit of R2 high to isolate the 7th bit of R7 in the next instruction
                    AND             R2, R2, R7
                    LSL             R2, #21                         ; shift the 7th bit to the 28th bit of 22

                    ; get the 6th bit of the number and put it in the 29th bit of R2
                    MOV32           R5, 0x00000040                  ; make only the 6th bit of R5 high to isolate the 6th bit of R7 in the next instruction
                    AND             R5, R5, R7
                    LSL             R5, #23                         ; shift the 6th bit to the 29th bit of R5
                    ADD             R2, R2, R5                      ; add R5 to R2, now LEDs P2.28 and P2.29 have their corresponding instructions

                    ; get the 5th bit of the number and put it in the 31st bit of R2
                    MOV32           R5, #0x00000020                 ; make only the 5th bit of R5 high to isolate the 5th bit of R7 in the next instruction
                    AND             R5, R5, R7
                    LSL             R5, #26                         ; shift the 5th bit to the 31th bit of R5
                    ADD             R2, R2, R5                      ; add R5 to R2, now, all LEDs of P.2 have their instructions

                    ; implement LEDs instructions
                    STR             R2, [R10, #0x20]                ; port 1
                    STR             R1, [R10, #0x40]                ; port 2

                    LDMFD           R13!, {R1, R2, R3, R5, R7, R15} ; return and restore modified registers

; Subroutine which causes a delay
DELAY               STMFD           R13!, {R2, R14}                 ; preserve the registers we are modifying
                    MOV32           R2, #0x000208D5                 ; set the counter to number of DELAY_LOOP cycles which results in 0.1ms time
                                                                    ; (4M/s)*(0.0001s) = 400000 cyles per 0.1ms
                                                                    ; (400000 cycles) / (3 cycles/delay loop) = 133333 loops    
                    MUL             R2, R2, R0                      ; store the total delay value in R2 by multiplying it by R0                

DELAY_LOOP          ; begin the delay  
                    SUBS            R2, #0x1                        ; decrement the delay counter
                    BGT             DELAY_LOOP                      ; continue decreasing the delay counter until it reaches zero                    

EXIT_DELAY          LDMFD           R13!,{R2, R15}                  ; set the PC to the line after the line which called this subroutine
               

LED_BASE_ADR        EQU             0x2009C000                      ; Base address of the memory that controls the LEDs

                    ALIGN

                    END