; vim: set filetype=nasm

%define SYSCALL_READ   0
%define SYSCALL_WRITE  1
%define SYSCALL_EXIT   60
%define STDIN   0
%define STDOUT  1

section .bss
        %define bufLen 80
        buf     resb bufLen
        maxRGB  resd 1          ; easier to zero (32 bits, double word)
        curRGB  resb 1

section .data
        sum     dq 0            ; total sum of powers

section .text
        global _start

_start:
        mov dword [maxRGB], 0   ; reset counters

        mov rdi, ' '            ; move file ptr to the actual values 
        call _readUntil
_nextCubes:
        mov rdi, ' '
        call _readUntil

        cmp rax, 1              ; \n reached?
        je _addPower            ; add power of current game to total

        cmp rax, 2              ; EOF?
        je _printTotPower       ; print results

        call _getInt            ; read the number of cubes
        mov byte [curRGB], al   ; .. and store it safely

        call _readColor         ; read color: R = 0. G = 1. B = 2
        
        mov sil, byte [curRGB]
        lea rdi, maxRGB         ; update overall maximum
        add rdi, rax
        movzx rdx, byte [rdi]   ; read current max for the current color
        cmp sil, dl             ; curRGB <?> maxRGB[currColor]
        jbe _nextCubes          ; go to next if overall max is correct so far

        mov byte [rdi], sil     ; update max
        jmp _nextCubes

_exit:
        mov rdi, 0
; "debug" exit: exit with RDI as error code
_dbg_exit:
        mov rax, SYSCALL_EXIT
        syscall

; calculates the power of the current game and adds it to the total
_addPower:
        mov eax, dword [maxRGB]         ; read all values at once

        mov rdi, rax                    ; extract G and B values via shift
        shr rdi, 8
        and rdi, 0xff

        mov r8, rax
        shr r8, 16
        and r8, 0xff
        and rax, 0xff

        mul dil                         ; no need for 16 b operands in 1st mul
        mul r8w                         ; R8W = low 16 bits of R8
        shl edx, 16                     ; result is in dx:ax. move to eax only
        or eax, edx

        add dword [sum], eax
        
        jmp _start

_printTotPower:
        mov edi, dword [sum]
        shl rdi, 32             ; clear high half
        shr rdi, 32
        call _printInt
        jmp _exit

; read 1 char from stdin and extract color info
; if char == 'r' -> ret 0
; if char == 'g' -> ret 1
; if char == 'b' -> ret 2
; otherwise, exit with `char` as error code
;
; This function assumes that EOF and \n are not reached while reading
_readColor:
        mov rax, SYSCALL_READ
        mov rdi, STDIN
        lea rsi, buf
        lea rdx, 1
        syscall

        mov al, byte [buf]
        cmp al, 'r'
        je _readColor_R
        cmp al, 'g'
        je _readColor_G
        cmp al, 'b'
        je _readColor_B
        
        mov dil, al             ; terminate program with error
        jmp _dbg_exit

_readColor_R:
        mov rax, 0
        ret
_readColor_G:
        mov rax, 1
        ret
_readColor_B:
        mov rax, 2
        ret

; reads stdin until the character in RDI has be read
; Reading also terminates on '\n' or EOF
; returns: 0 -> RDI reached. 1 -> '\n' reached. 2 -> EOF reached
; uses buf.
_readUntil:
        push rdi                ; push stop char to stack
        mov rax, SYSCALL_READ
        mov rdi, STDIN
        lea rsi, buf
        mov rdx, 1              ; read 1 char
        syscall

        cmp rax, 0              ; EOF?
        je _readuntil_eof

        mov cl, byte [buf]

        cmp cl, 10              ; end-of-line?
        je _readuntil_eol

        pop rdi                 ; restore saved stop char
        cmp cl, dil             ; DIL = 8 bit RDI
        jne _readUntil

        mov rax, 0              ; stop char found! return
        ret
_readuntil_eol:
        pop rdi
        mov rax, 1
        ret
_readuntil_eof:
        pop rdi
        mov rax, 2
        ret
        
; reads a 64bits unsigned integer from stdin and returns it
; reading stop when a non-digit character is read
; it is assumed that no EOF or \n will be encountered
_getInt:
        push r12                ; save CSR
        mov r12, 0              ; will store read number

_getInt_nextDigit:
        mov rax, SYSCALL_READ
        mov rdi, STDIN
        lea rsi, buf
        mov rdx, 1
        syscall
        
        movzx rdi, byte [buf]   ; ensure high bytes are 0
        call _getDigit          ; calculate digit value. -1 if not a digit
        cmp rax, -1
        je _getInt_ret

        mov rcx, rax            ; R12 = (R12 * 10) + RAX
        mov rax, 10             ; (i.e. take new decimal digit)
        mul r12
        add rax, rcx            ; MUL result is in RAX
        mov r12, rax
        jmp _getInt_nextDigit

_getInt_ret:
        mov rax, r12
        pop r12
        ret
        
; in: ASCII character
; out : numeric digit value if it's a digit. -1 otherwise
_getDigit:
        sub rdi, '0'
        jb _getDigit_invalid ; Jump Below (i.e. < 0x30)
        cmp rdi, 9
        ja _getDigit_invalid
        mov rax, rdi
        ret
_getDigit_invalid:
        mov rax, -1
        ret

; print RDI to stdout
; uses buf
_printInt:
        mov rsi, 0      ; number of decimal digits
        mov r8, 10      ; stores divisor
        lea r9, buf + bufLen - 1  ; points to where to store current digit

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
