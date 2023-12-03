; vim:set filetype=nasm

%define SYSCALL_READ   0
%define SYSCALL_WRITE  1
%define SYSCALL_EXIT   60
%define STDIN   0
%define STDOUT  1

; statuses
%define LAST_SET        1
%define FIRST_SET       1

section .data
        sum     dq 0

section .bss    ; store variables here
        %define lineInLen 80
        lineIn  resb lineInLen
        first   resb 1
        last    resb 1

section .text
        global _start
        extern convertDigits

_start:
        xor r12, r12    ; reset status
        mov byte [first], 0
        mov byte [last], 0

        ;call _getline  ; more efficient but only works if input is keyboard
        call _getline_file
        cmp rax, 0      ; EOF?
        je printSum

        mov rbx, rax ; rax is a scratch reg. `convertDigits` can use it
        ; comment the following if compiling exercise 1.1
        lea rdi, lineIn
        mov rsi, rax
        call convertDigits

        ; skim through the input line from the end to the start
        mov r13, rbx
nextChar:
        sub r13, 1      ; use as index. Didn't use DEC as doesn't set sign flag
        js useFirstLast ; when r13 is negative entire line has been read

        lea rsi, lineIn
        movzx rdi, byte [rsi + r13] ; MOVe Zero eXtend: move byte into 64 bits

        call _getDigit
        cmp rax, -1     ; -1 returned if not digit
        je nextChar

        ; it's a digit! set first (and maybe last)
        mov byte [first], al    ; AL is the lowest byte of RAX, check here:
        test r12, LAST_SET      ; https://wiki.osdev.org/CPU_Registers_x86-64
        jnz nextChar
        mov byte [last], al
        or r12, LAST_SET
        jmp nextChar

useFirstLast:           ; compose the number <first><last> and add it to total
        mov al, 10
        mov bl, byte [first]
        mul bl          ; remember that result is in AL
        movzx rbx, byte [last] ; so that rbx later will already be correct
        add bl, al
        add [sum], rbx

        jmp _start

printSum:
        mov rdi, [sum]
        call _printInt

_exit:
        mov rax, SYSCALL_EXIT
        mov rdi, 0              ; no errors
        syscall
 
; "debug" exit: exit with RDI as error code
_dbg_exit:
        mov rax, SYSCALL_EXIT
        syscall
        
; read 1 line from stdin.
; Return length into rax
; return 0 if EOF
_getline:
        mov rax, SYSCALL_READ
        mov rdi, STDIN
        mov rsi, lineIn
        mov rdx, lineInLen
        syscall
        ret

; read 1 line from stdin.
; But plot twist, if stdin is a redirected file
; this function is needed because if the file is redirected the read()
; doesn't stop reading at \n
;
; Return length into rax
; return 0 if EOF
_getline_file:
        push r12
        mov r12, 0

_getline_file_nextchar:
        mov rax, SYSCALL_READ
        mov rdi, STDIN
        mov rsi, lineIn
        add rsi, r12
        mov rdx, 1
        syscall

        cmp rax, 0              ; EOF?
        je _getline_file_ret

        inc r12
        cmp byte [rsi], 10      ; was \n read?
        jne _getline_file_nextchar

_getline_file_ret:
        mov rax, r12
        pop r12
        ret

; in: ASCII character
; out : numeric digit value if it's a digit. -1 otherwise
_getDigit:
        ; digits in ASCII are all 0011 ....
        ; ex. '5' is 0011 0101
        sub rdi, 0x30 ; NASM supports also writing '0'...
        jb _getDigit_invalid ; Jump Below (i.e. < 0x30)
        cmp rdi, 9
        ja _getDigit_invalid
        mov rax, rdi
        ret
_getDigit_invalid:
        mov rax, -1
        ret

; print RDI to stdout
; uses lineIn
_printInt:
        mov rsi, 0      ; number of decimal digits
        mov r8, 10      ; stores divisor
        lea r9, lineIn + lineInLen - 1  ; points to where to store current digit

        mov byte [r9], 10 ; print line feed after number
        dec r9
        inc rsi

        cmp rdi, 0      ; handle special case when number to print is 0
        je _printInt_print0

        ; division in x86 is a PITA
        ; dividend is in rdx:rax
        mov rax, rdi

_printInt_nextDigit:
        mov rdx, 0
        div r8          ; result in RAX. Remainder in RDX
        cmp rdx, 0      ; if both result and remainder == 0 -> goto print
        jne _printInt_pushDigit
        cmp rax, 0
        je _printInt_print
_printInt_pushDigit:
        ; convert remainder (RDX) to ASCII and push to lineIn
        add dl, '0'
        mov byte [r9], dl
        dec r9
        inc rsi
        jmp _printInt_nextDigit

_printInt_print:        ; write(stdout, r9, rsi)
        inc r9
        mov rax, SYSCALL_WRITE
        mov rdi, STDOUT
        mov rdx, rsi
        mov rsi, r9
        syscall

        ret

_printInt_print0:
        mov byte [r9], '0'
        dec r9
        inc rsi
        jmp _printInt_print
