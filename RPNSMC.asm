; SMC RPN Calculator in LC3 Assembly
        .ORIG x3000
        BR START            ; Jump over the data pool to start the program

; DATA POOL 1: Main Loop & Setup Variables
; Because LC-3 has a 9-bit offset limit for loading memory, we keep 
; these variables close to the top so our main loop can "see" them.
; Note: We use negative ASCII values to easily check what the user typed.
STACK_TOP    .FILL x4000
NEG_LF       .FILL xFFF6    ; -10 (Negative Line Feed / Enter)
NEG_CR       .FILL xFFF3    ; -13 (Negative Carriage Return / Enter)
NEG_SPACE    .FILL xFFE0    ; -32 (Negative Space)
NEG_STAR     .FILL xFFD6    ; -42 (Negative '*')
NEG_PLUS     .FILL xFFD5    ; -43 (Negative '+')
NEG_MINUS    .FILL xFFD3    ; -45 (Negative '-')
NEG_DOT      .FILL xFFD2    ; -46 (Negative '.')
NEG_SLASH    .FILL xFFD1    ; -47 (Negative '/')
NEG_ZERO     .FILL xFFD0    ; -48 (Negative '0')
NEG_NINE     .FILL xFFC7    ; -57 (Negative '9')
CUR_OP       .BLKW 1        ; Temporary storage for the current operator

TITLE_MSG    .STRINGZ "\nSMC RPN Calculator\nEnter 0-9 or +, -, *, /\n'.' to display result on TOS\n"
PROMPT_MSG   .STRINGZ "\n> "

; MAIN ENTRY
START   
        ; 1. Initialize RPN stack pointer
        LD R4, STACK_TOP    ; R4 now points to x4000 (empty stack)
        
        ; 2. Print title and instructions
        LEA R0, TITLE_MSG
        PUTS

PROMPT_LOOP
        LEA R0, PROMPT_MSG  ; Print "> "
        PUTS

CLEAR_ACCUM
        ; We use R5 to build multi-digit numbers, and R6 to count digits.
        ; We must clear them to 0 before reading a new number.
        AND R5, R5, #0      ; R5 = Accumulator
        AND R6, R6, #0      ; R6 = Digit counter

READ_LOOP
        GETC                ; Read 1 character from keyboard into R0
        OUT                 ; Echo it back to the screen so the user sees it

        ; --- DELIMITER CHECKS ---
        ; Check if the user pressed Enter (LF or CR)
        LD R1, NEG_LF
        ADD R2, R0, R1
        BRz HANDLE_ENTER
        LD R1, NEG_CR
        ADD R2, R0, R1
        BRz HANDLE_ENTER

        ; Check if the user pressed Space
        LD R1, NEG_SPACE
        ADD R2, R0, R1
        BRz HANDLE_SPACE

        ; --- DIGIT CHECKS ---
        ; If input is < '0' or > '9', it might be an operator.
        LD R1, NEG_ZERO
        ADD R2, R0, R1
        BRn CHK_OPS         ; If negative, it's less than ASCII '0'
        LD R1, NEG_NINE
        ADD R2, R0, R1
        BRp CHK_OPS         ; If positive, it's greater than ASCII '9'

        ; --- HANDLE MULTI-DIGIT INPUT (BUILDING THE NUMBER) ---
        ; 1. Check if we already have 4 digits. If so, throw an error.
        ADD R1, R6, #-4
        BRz ERR_INPUT       ; (R6 - 4 == 0) means 5th digit was typed!

        ; 2. Multiply current accumulator (R5) by 10.
        ; Since LC-3 has no direct MULTIPLY instruction, we use addition:
        ; R5 * 10 = (R5 * 2) + (R5 * 8)
        ADD R1, R5, R5      ; R1 = R5 * 2
        ADD R2, R1, R1      ; R2 = R5 * 4
        ADD R2, R2, R2      ; R2 = R5 * 8
        ADD R5, R2, R1      ; R5 = (R5 * 8) + (R5 * 2) = R5 * 10

        ; 3. Convert ASCII character to real integer and add to accumulator
        LD R1, NEG_ZERO
        ADD R1, R0, R1      ; e.g., '5' (x35) - '0' (x30) = Integer 5
        ADD R5, R5, R1      ; Add integer to R5

        ; 4. Increment our digit counter
        ADD R6, R6, #1      
        BRnzp READ_LOOP     ; Go wait for the next keypress

CHK_OPS
        ; --- OPERATOR CHECKS ---
        ; Compare R0 to all valid operators. If it matches, go handle it.
        LD R1, NEG_PLUS
        ADD R2, R0, R1
        BRz MATCHED_OP
        LD R1, NEG_MINUS
        ADD R2, R0, R1
        BRz MATCHED_OP
        LD R1, NEG_STAR
        ADD R2, R0, R1
        BRz MATCHED_OP
        LD R1, NEG_SLASH
        ADD R2, R0, R1
        BRz MATCHED_OP
        LD R1, NEG_DOT
        ADD R2, R0, R1
        BRz MATCHED_OP
        BRnzp READ_LOOP     ; If it's not a valid char, ignore and keep reading

MATCHED_OP
        ; If the user typed "15+", we need to push the "15" before doing the "+"
        ST R0, CUR_OP       ; Save the operator ('+') for a moment
        ADD R6, R6, #0      ; Check if our digit counter > 0
        BRz DO_OP           ; If 0, no number was being built, just do the op
        ADD R0, R5, #0      ; Move accumulator to R0
        JSR PUSH_RPN        ; Push the number we built to the stack
        AND R6, R6, #0      ; Reset digit counter
DO_OP
        ; Retrieve the operator and jump to the correct math section
        LD R0, CUR_OP
        LD R1, NEG_PLUS
        ADD R2, R0, R1
        BRz EXEC_ADD
        LD R1, NEG_MINUS
        ADD R2, R0, R1
        BRz EXEC_SUB
        LD R1, NEG_STAR
        ADD R2, R0, R1
        BRz EXEC_MUL
        LD R1, NEG_SLASH
        ADD R2, R0, R1
        BRz EXEC_DIV
        LD R1, NEG_DOT
        ADD R2, R0, R1
        BRz EXEC_DOT

; DELIMITER HANDLERS (Space or Enter pressed)
HANDLE_ENTER
        ADD R6, R6, #0      ; Did we type any numbers before hitting enter?
        BRz SKIP_PUSH_E     ; If no, skip pushing
        ADD R0, R5, #0
        JSR PUSH_RPN        ; Push the finished number to the stack
SKIP_PUSH_E
        BRnzp PROMPT_LOOP   ; Enter triggers a new ">" prompt

HANDLE_SPACE
        ADD R6, R6, #0      
        BRz SKIP_PUSH_S
        ADD R0, R5, #0
        JSR PUSH_RPN        ; Push the finished number to the stack
SKIP_PUSH_S
        BRnzp CLEAR_ACCUM   ; Space doesn't trigger a prompt, just clears accumulator

; EXECUTION VECTORS (The Math Operations)
EXEC_ADD
        ; Pop top two numbers
        JSR POP_RPN
        ADD R2, R0, #0      ; R2 = Right operand
        JSR POP_RPN
        ADD R1, R0, #0      ; R1 = Left operand
        
        ADD R0, R1, R2      ; Perform Addition!
        ; --- OVERFLOW CHECK ---
        ; If we add two positives and get a negative, it overflowed.
        ; If we add two negatives and get a positive, it underflowed.
        ADD R1, R1, #0
        BRn AD_NEG          ; Branch if Left is negative
        ADD R2, R2, #0
        BRn AD_DONE         ; Pos + Neg can never overflow
        ADD R0, R0, #0
        BRn ERR_OVERFLOW    ; Pos + Pos = Neg -> OVERFLOW!
        BRnzp AD_DONE
AD_NEG  ADD R2, R2, #0
        BRzp AD_DONE        ; Neg + Pos can never overflow
        ADD R0, R0, #0
        BRzp ERR_OVERFLOW   ; Neg + Neg = Pos -> UNDERFLOW!
AD_DONE 
        JSR PUSH_RPN        ; Push the result back to the stack
        BRnzp READ_LOOP

EXEC_SUB
        JSR POP_RPN
        ADD R2, R0, #0      
        JSR POP_RPN
        ADD R1, R0, #0      
        ; To make a number negative in Two's Complement: NOT it, then ADD 1.
        NOT R2, R2
        ADD R2, R2, #1      ; R2 is now negative
        ADD R0, R1, R2      ; R1 + (-R2) = Subtraction
        
        ; --- OVERFLOW CHECK (Same logic as addition, since we used ADD) ---
        ADD R1, R1, #0
        BRn SU_NEG
        ADD R2, R2, #0
        BRn SU_DONE
        ADD R0, R0, #0
        BRn ERR_OVERFLOW
        BRnzp SU_DONE
SU_NEG  ADD R2, R2, #0
        BRzp SU_DONE
        ADD R0, R0, #0
        BRzp ERR_OVERFLOW
SU_DONE 
        JSR PUSH_RPN
        BRnzp READ_LOOP

EXEC_MUL
        JSR POP_RPN
        ADD R2, R0, #0
        JSR POP_RPN
        ADD R1, R0, #0
        
        ; --- SIGN TRACKING ---
        ; Multiplication is easiest with positive numbers.
        ; We track the signs in R3. If only ONE number is negative, R3 ends up as 1.
        AND R3, R3, #0      
        ADD R1, R1, #0
        BRzp MU_R1P         ; If R1 positive, skip negation
        NOT R1, R1
        ADD R1, R1, #1      ; Make R1 positive
        ADD R3, R3, #1      ; Increment negative flag
MU_R1P  ADD R2, R2, #0
        BRzp MU_R2P
        NOT R2, R2
        ADD R2, R2, #1      ; Make R2 positive
        ADD R3, R3, #1
MU_R2P  AND R3, R3, #1      ; If flag is 1, result must be made negative later. If 0 or 2, result is positive.
        
        ; --- ACTUAL MULTIPLICATION (Repeated Addition) ---
        AND R0, R0, #0      ; R0 holds the sum
MU_LOOP ADD R2, R2, #0
        BRz MU_SIGN         ; If multiplier is 0, we are done
        ADD R0, R0, R1      ; Add R1 to R0
        BRn ERR_OVERFLOW    ; If sum goes negative while adding positives, we hit the 16-bit ceiling
        ADD R2, R2, #-1     ; Decrement multiplier
        BRnzp MU_LOOP
MU_SIGN 
        ; Apply negative sign if R3 flag requires it
        ADD R3, R3, #0
        BRz MU_DONE
        NOT R0, R0
        ADD R0, R0, #1      ; Make result negative
MU_DONE 
        JSR PUSH_RPN
        BRnzp READ_LOOP

EXEC_DIV
        JSR POP_RPN
        ADD R2, R0, #0
        BRz ERR_INPUT       ; Division by ZERO is an error!
        JSR POP_RPN
        ADD R1, R0, #0
        
        ; --- SIGN TRACKING (Same as Multiplication) ---
        AND R3, R3, #0
        ADD R1, R1, #0
        BRzp DI_R1P
        NOT R1, R1
        ADD R1, R1, #1
        ADD R3, R3, #1
DI_R1P  ADD R2, R2, #0
        BRzp DI_R2P
        NOT R2, R2
        ADD R2, R2, #1
        ADD R3, R3, #1
DI_R2P  AND R3, R3, #1      
        
        ; --- ACTUAL DIVISION (Repeated Subtraction) ---
        AND R0, R0, #0      ; R0 holds quotient (how many times it fit)
        NOT R2, R2
        ADD R2, R2, #1      ; Make divisor negative so we can subtract it
DI_LOOP 
        ADD R1, R1, R2      ; Dividend - Divisor
        BRn DI_SIGN         ; If < 0, we've subtracted too many times. Done.
        ADD R0, R0, #1      ; Increment Quotient
        BRnzp DI_LOOP
DI_SIGN 
        ADD R3, R3, #0
        BRz DI_DONE
        NOT R0, R0
        ADD R0, R0, #1      ; Apply negative sign if needed
DI_DONE 
        JSR PUSH_RPN
        BRnzp READ_LOOP

EXEC_DOT
        ; The '.' operator prints the top of the stack.
        ; First, check if the stack actually has anything in it.
        LD R1, STACK_BOT    
        NOT R1, R1
        ADD R1, R1, #1
        ADD R2, R4, R1      ; Compare Stack Pointer (R4) to Base (x4000)
        BRz ERR_STACK       ; If they are equal, stack is empty. Error!
        
        LD R0, ASCII_LF     
        OUT                 ; Print a newline for formatting
        
        LDR R0, R4, #0      ; Peek at the top of the stack (don't pop it!)
        JSR PRINT_NUM       ; Jump to our printing subroutine
        
        BRnzp PROMPT_LOOP   
; ERROR HANDLERS
ERR_INPUT
        LD R0, ASCII_LF     
        OUT
        LEA R0, MSG_ERR_INP ; Print "?- error"
        PUTS
        LD R0, PTR_START    
        JMP R0              ; Hard reset back to START

ERR_STACK
        LD R0, ASCII_LF
        OUT
        LEA R0, MSG_ERR_STK ; Print "$stack error"
        PUTS
        LD R0, PTR_START
        JMP R0              ; Hard reset

ERR_OVERFLOW
        LD R0, ASCII_LF
        OUT
        LEA R0, MSG_ERR_OVR ; Print "!- overflow"
        PUTS
        LD R0, PTR_START
        JMP R0              ; Hard reset
; SUBROUTINES
PUSH_RPN
        ADD R4, R4, #-1     ; Move stack pointer UP one memory address
        STR R0, R4, #0      ; Store R0 into the new memory address
        RET
        
POP_RPN
        ; We save R1 and R2 so we don't accidentally overwrite 
        ; half-finished math equations during sequential pops.
        ST R1, POP_SAV1     
        ST R2, POP_SAV2     
        
        LD R1, STACK_BOT    
        NOT R1, R1
        ADD R1, R1, #1
        ADD R2, R4, R1
        BRz ERR_STACK       ; If trying to pop an empty stack -> Error
        
        LDR R0, R4, #0      ; Load top value into R0
        ADD R4, R4, #1      ; Move stack pointer DOWN one memory address
        
        LD R1, POP_SAV1     ; Restore R1
        LD R2, POP_SAV2     ; Restore R2
        RET

PRINT_NUM
        ST R7, PN_R7        ; Save Return Address so JSR doesn't break
        ADD R0, R0, #0
        BRnp PN_NOT_ZERO
        LD R0, POS_ZERO     
        OUT                 ; If number is exactly 0, just print '0' and return
        LD R7, PN_R7
        RET
        
PN_NOT_ZERO
        ; Handle negatives for printing
        BRp PN_POS
        ST R0, PN_SAV
        LD R0, ASCII_MINUS  
        OUT                 ; Print '-' sign
        LD R0, PN_SAV
        NOT R0, R0          
        ADD R0, R0, #1      ; Make number positive for the division loop
PN_POS
        LD R1, PN_STACK_B   ; We use a secondary stack just for printing digits
PN_DIV_LOOP
        ADD R0, R0, #0
        BRz PN_OUT_LOOP     ; If quotient is 0, we are done extracting digits
        
        ; Calculate Modulo 10 (Remainder)
        AND R2, R2, #0      ; R2 = Quotient
        ADD R3, R0, #0      ; R3 = Remainder tracker
PN_MOD10
        ADD R3, R3, #-10    ; Subtract 10
        BRn PN_MOD_END      ; If negative, we've found the remainder
        ADD R2, R2, #1      ; Else, increment Quotient
        BRnzp PN_MOD10
PN_MOD_END
        ADD R3, R3, #10     ; Add 10 back to fix the negative overshoot
        
        ADD R1, R1, #-1
        STR R3, R1, #0      ; Push the extracted remainder digit to the Print Stack
        
        ADD R0, R2, #0      ; Move Quotient to R0 for next division
        BRnzp PN_DIV_LOOP
        
PN_OUT_LOOP
        ; Pop digits off the Print Stack and print them
        LD R2, PN_STACK_B
        NOT R2, R2
        ADD R2, R2, #1
        ADD R2, R1, R2
        BRz PN_END          ; If print stack is empty, return
        
        LDR R0, R1, #0
        LD R3, POS_ZERO
        ADD R0, R0, R3      ; Convert integer digit back to ASCII (Add x30)
        OUT
        
        ADD R1, R1, #1
        BRnzp PN_OUT_LOOP
PN_END
        LD R7, PN_R7        ; Restore return address
        RET
; DATA POOL 2: Subroutine & Error Constants
STACK_BOT    .FILL x4000
PTR_START    .FILL START
ASCII_LF     .FILL x000A
POS_ZERO     .FILL x0030    
ASCII_MINUS  .FILL x002D    
PN_STACK_B   .FILL x4100
PN_SAV       .BLKW 1
PN_R7        .BLKW 1
POP_SAV1     .BLKW 1
POP_SAV2     .BLKW 1

MSG_ERR_INP  .STRINGZ "?- error occurred, input doesn't make sense\n"
MSG_ERR_STK  .STRINGZ "$stack error occurred\n"
MSG_ERR_OVR  .STRINGZ "!- numeric overflow or underflow\n"

        .END
