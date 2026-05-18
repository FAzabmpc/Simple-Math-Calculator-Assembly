; SMC RPN Calculator in LC3 Assembly
        .ORIG x3000
        BR START

; DATA POOL 1: Main Loop & Setup Variables
STACK_TOP    .FILL x4000
NEG_LF       .FILL xFFF6    ; -x0A
NEG_CR       .FILL xFFF3    ; -x0D
NEG_SPACE    .FILL xFFE0    ; -x20
NEG_STAR     .FILL xFFD6    ; -x2A '*'
NEG_PLUS     .FILL xFFD5    ; -x2B '+'
NEG_MINUS    .FILL xFFD3    ; -x2D '-'
NEG_DOT      .FILL xFFD2    ; -x2E '.'
NEG_SLASH    .FILL xFFD1    ; -x2F '/'
NEG_ZERO     .FILL xFFD0    ; -x30 '0'
NEG_NINE     .FILL xFFC7    ; -x39 '9'
CUR_OP       .BLKW 1

TITLE_MSG    .STRINGZ "\nSMC RPN Calculator\nEnter 0-9 or +, -, *, /\n'.' to display result on TOS\n"
PROMPT_MSG   .STRINGZ "\n> "

; MAIN ENTRY

START   
        ; 1. Initialize RPN stack
        LD R4, STACK_TOP
        
        ; 2. Print title and instructions
        LEA R0, TITLE_MSG
        PUTS

PROMPT_LOOP
        LEA R0, PROMPT_MSG
        PUTS

CLEAR_ACCUM
        AND R5, R5, #0      
        AND R6, R6, #0      

READ_LOOP
        GETC
        OUT                 

        LD R1, NEG_LF
        ADD R2, R0, R1
        BRz HANDLE_ENTER
        LD R1, NEG_CR
        ADD R2, R0, R1
        BRz HANDLE_ENTER

        LD R1, NEG_SPACE
        ADD R2, R0, R1
        BRz HANDLE_SPACE

        LD R1, NEG_ZERO
        ADD R2, R0, R1
        BRn CHK_OPS         
        LD R1, NEG_NINE
        ADD R2, R0, R1
        BRp CHK_OPS         

        ; Handle Digit Input
        ADD R1, R6, #-4
        BRz ERR_INPUT       

        ADD R1, R5, R5      
        ADD R2, R1, R1      
        ADD R2, R2, R2      
        ADD R5, R2, R1      

        LD R1, NEG_ZERO
        ADD R1, R0, R1      
        ADD R5, R5, R1      

        ADD R6, R6, #1      
        BRnzp READ_LOOP

CHK_OPS
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
        BRnzp READ_LOOP

MATCHED_OP
        ST R0, CUR_OP       
        ADD R6, R6, #0
        BRz DO_OP
        ADD R0, R5, #0
        JSR PUSH_RPN
        AND R6, R6, #0      
DO_OP
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

; DELIMITER HANDLERS
HANDLE_ENTER
        ADD R6, R6, #0
        BRz SKIP_PUSH_E
        ADD R0, R5, #0
        JSR PUSH_RPN        
SKIP_PUSH_E
        BRnzp PROMPT_LOOP   

HANDLE_SPACE
        ADD R6, R6, #0
        BRz SKIP_PUSH_S
        ADD R0, R5, #0
        JSR PUSH_RPN        
SKIP_PUSH_S
        BRnzp CLEAR_ACCUM   

; EXECUTION VECTORS

EXEC_ADD
        JSR POP_RPN
        ADD R2, R0, #0      
        JSR POP_RPN
        ADD R1, R0, #0      
        
        ADD R0, R1, R2      
        ADD R1, R1, #0
        BRn AD_NEG
        ADD R2, R2, #0
        BRn AD_DONE
        ADD R0, R0, #0
        BRn ERR_OVERFLOW
        BRnzp AD_DONE
AD_NEG  ADD R2, R2, #0
        BRzp AD_DONE
        ADD R0, R0, #0
        BRzp ERR_OVERFLOW
AD_DONE JSR PUSH_RPN
        BRnzp READ_LOOP

EXEC_SUB
        JSR POP_RPN
        ADD R2, R0, #0      
        JSR POP_RPN
        ADD R1, R0, #0      
        
        NOT R2, R2
        ADD R2, R2, #1      
        ADD R0, R1, R2      
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
SU_DONE JSR PUSH_RPN
        BRnzp READ_LOOP

EXEC_MUL
        JSR POP_RPN
        ADD R2, R0, #0
        JSR POP_RPN
        ADD R1, R0, #0
        
        AND R3, R3, #0      
        ADD R1, R1, #0
        BRzp MU_R1P
        NOT R1, R1
        ADD R1, R1, #1
        ADD R3, R3, #1
MU_R1P  ADD R2, R2, #0
        BRzp MU_R2P
        NOT R2, R2
        ADD R2, R2, #1
        ADD R3, R3, #1
MU_R2P  AND R3, R3, #1      
        
        AND R0, R0, #0      
MU_LOOP ADD R2, R2, #0
        BRz MU_SIGN
        ADD R0, R0, R1
        BRn ERR_OVERFLOW    
        ADD R2, R2, #-1
        BRnzp MU_LOOP
MU_SIGN ADD R3, R3, #0
        BRz MU_DONE
        NOT R0, R0
        ADD R0, R0, #1      
MU_DONE JSR PUSH_RPN
        BRnzp READ_LOOP

EXEC_DIV
        JSR POP_RPN
        ADD R2, R0, #0
        BRz ERR_INPUT       
        JSR POP_RPN
        ADD R1, R0, #0
        
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
        
        AND R0, R0, #0      
        NOT R2, R2
        ADD R2, R2, #1      
DI_LOOP ADD R1, R1, R2
        BRn DI_SIGN
        ADD R0, R0, #1
        BRnzp DI_LOOP
DI_SIGN ADD R3, R3, #0
        BRz DI_DONE
        NOT R0, R0
        ADD R0, R0, #1
DI_DONE JSR PUSH_RPN
        BRnzp READ_LOOP

EXEC_DOT
        LD R1, STACK_BOT    
        NOT R1, R1
        ADD R1, R1, #1
        ADD R2, R4, R1
        BRz ERR_STACK
        
        LD R0, ASCII_LF     
        OUT                 
        
        LDR R0, R4, #0      
        JSR PRINT_NUM       
        
        BRnzp PROMPT_LOOP   

; ERROR HANDLERS

ERR_INPUT
        LD R0, ASCII_LF     
        OUT
        LEA R0, MSG_ERR_INP
        PUTS
        LD R0, PTR_START    
        JMP R0

ERR_STACK
        LD R0, ASCII_LF
        OUT
        LEA R0, MSG_ERR_STK
        PUTS
        LD R0, PTR_START
        JMP R0

ERR_OVERFLOW
        LD R0, ASCII_LF
        OUT
        LEA R0, MSG_ERR_OVR
        PUTS
        LD R0, PTR_START
        JMP R0

; SUBROUTINES

PUSH_RPN
        ADD R4, R4, #-1
        STR R0, R4, #0
        RET
        
POP_RPN
        ST R1, POP_SAV1     ; Save R1 
        ST R2, POP_SAV2     ; Save R2 
        
        LD R1, STACK_BOT    
        NOT R1, R1
        ADD R1, R1, #1
        ADD R2, R4, R1
        BRz ERR_STACK       
        
        LDR R0, R4, #0
        ADD R4, R4, #1
        
        LD R1, POP_SAV1     ; Restore R1
        LD R2, POP_SAV2     ; Restore R2
        RET

PRINT_NUM
        ST R7, PN_R7
        ADD R0, R0, #0
        BRnp PN_NOT_ZERO
        LD R0, POS_ZERO     
        OUT
        LD R7, PN_R7
        RET
        
PN_NOT_ZERO
        BRp PN_POS
        ST R0, PN_SAV
        LD R0, ASCII_MINUS  
        OUT
        LD R0, PN_SAV
        NOT R0, R0          
        ADD R0, R0, #1
PN_POS
        LD R1, PN_STACK_B
PN_DIV_LOOP
        ADD R0, R0, #0
        BRz PN_OUT_LOOP
        
        AND R2, R2, #0      
        ADD R3, R0, #0      
PN_MOD10
        ADD R3, R3, #-10
        BRn PN_MOD_END
        ADD R2, R2, #1
        BRnzp PN_MOD10
PN_MOD_END
        ADD R3, R3, #10     
        
        ADD R1, R1, #-1
        STR R3, R1, #0
        
        ADD R0, R2, #0      
        BRnzp PN_DIV_LOOP
        
PN_OUT_LOOP
        LD R2, PN_STACK_B
        NOT R2, R2
        ADD R2, R2, #1
        ADD R2, R1, R2
        BRz PN_END          
        
        LDR R0, R1, #0
        LD R3, POS_ZERO
        ADD R0, R0, R3
        OUT
        
        ADD R1, R1, #1
        BRnzp PN_OUT_LOOP
PN_END
        LD R7, PN_R7
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