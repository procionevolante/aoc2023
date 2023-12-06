; vim: set filetype=nasm

; Idea is to figure out the line length and then flow through the text having 3
; lines at a time and analyzing the central one.
;
; Once a \n is met, the data in the 2 newest arrays is copied on the previous
; one (`curr` copied into `prev`, `next` copied into `curr` and `next` read
; from input)

section .bss
        %define maxLineLen 0xff
        lineLen  resb 1                 ; actual line length

section .data
        linePrev db maxLineLen DUP('.')   ; stores previous line
        lineCurr db maxLineLen DUP('.')   ; stores current line
        lineNext db maxLineLen DUP('.')   ; stores next line
        sum dq 0                        ; sum of part numbers

section .text
        %define SYSCALL_READ   0
        %define SYSCALL_WRITE  1
        %define SYSCALL_EXIT   60
        %define STDIN   0
        %define STDOUT  1
        %define STATUS_LAST_LINE 1

        global _start
_start:
        xor r12, r12            ; clear status register

        lea rdi, lineCurr       ; read 1st line
        mov rsi, maxLineLen
        call _readLine          ; it is assumed at least 1 line is supplied
        mov byte [lineLen], al  ; `lineLen` will be used to check if we should
                                ; check around numbers on the right
_main_nextLine:
        lea rdi, lineNext       ; you need `lineNext` to analyze `lineCurr`
        mov rsi, maxLineLen
        call _readLine
        
        cmp rax, -1             ; EOF? -> lineCurr is the last line
        jne _main_countPNs

_main_handleLast:
        or r12, STATUS_LAST_LINE
        lea rdi, lineNext       ; lineNext = '....' using string instructions
        mov al, '.'
        movzx rcx, byte [lineLen]
        rep stosb               ; REPeat STOre Byte string

_main_countPNs:
        call _searchCountPartNumbers ; look for part numbers in lineCurr
        add qword [sum], rax    ; add result to total

        test r12, STATUS_LAST_LINE
        jnz _main_printResult

        movzx rdx, byte [lineLen]
        lea rdi, linePrev       ; linePrev = lineCurr using string instructions
        lea rsi, lineCurr
        mov rcx, rdx            ; RCX = repetition count
        rep movsb

        lea rdi, lineCurr       ; lineCurr = lineNext
        lea rsi, lineNext
        mov rcx, rdx
        rep movsb

        jmp _main_nextLine

_main_printResult:
        mov rdi, qword [sum]
        call _printInt

_exit:
        mov rdi, 0
_dbg_exit:
        mov rax, SYSCALL_EXIT
        syscall


; searches for "part numbers" in `lineCurr`
; returns the sum of part numbers in RAX
;
; part numbers are searched starting from the symbols and then looking around
; them for numbers
; it assumed that no number is touched by more than 1 symbol
_searchCountPartNumbers:
        push rbx                        ; save CSRs
        push r12
        push r13
        push r14                        ; used during sarch analysis

        movzx rbx, byte [lineLen]       ; index in lineCurr
        xor r12, r12                    ; stores sum of PNs

_searchCntPN_nextChar:
        sub rbx, 1
        js _searchCntPN_ret             ; if index went negative, return

        lea r13, lineCurr               ; stores addr of lineCurr
        add r13, rbx                    ; cache lineCurr[rbx] address

        mov sil, byte [r13]             ; read current char. Is it a symbol?
        cmp sil, 10                     ; C is symbol <-> C != '\n', '.', [0-9]
        je _searchCntPN_nextChar
        cmp sil, '.'
        je _searchCntPN_nextChar
        cmp sil, '0'                    ; check that it's not a digit
        jb _searchCntPN_partFound       ; ensure < '0'
        cmp sil, '9'
        jbe _searchCntPN_nextChar       ; ensure > '9'

_searchCntPN_partFound:
        ; at this point we know that lineCurr[rbx] has a "part":
        ; look for part numbers around it
        mov rdi, r13                    ; search on the RIGHT:
        add rdi, 1                      ; numbers on right have to start here
        call _getInt
        add r12, rax                    ; add to total (RAX = 0 if no num found)

        ; note: can search on left even at line begin:
        ; in that case, there will be either \n or '.' from linePrev
        mov rdi, r13                    ; search on the LEFT:
        sub rdi, 1
        call _searchNumStart

        cmp rax, 0                      ; didn't find anything?
        je _searchCntPN_top

        mov rdi, rax                    ; if num on left, RAX has ptr to start
        call _getInt
        add r12, rax

_searchCntPN_top:                       ; search on top line
        mov rdi, r13                    ; search on TOP RIGHT:
        sub rdi, maxLineLen - 1         ; move 1 char up and right
        call _searchNumStart
        push rax                        ; save search result for later
        
        mov rdi, r13                    ; search on TOP:
        sub rdi, maxLineLen             ; move 1 char up
        call _searchNumStart
        push rax                        ; save search result for later

        mov rdi, r13                    ; search TOP LEFT
        sub rdi, maxLineLen + 1         ; move 1 char up and left
        call _searchNumStart
        push rax                        ; save result for later

_searchCntPN_bottom:
        mov rdi, r13                    ; search BOTTOM LEFT
        add rdi, maxLineLen - 1
        call _searchNumStart
        push rax

        mov rdi, r13                    ; search BOTTOM
        add rdi, maxLineLen
        call _searchNumStart
        push rax

        mov rdi, r13                    ; search BOTTOM RIGHT
        add rdi, maxLineLen + 1
        call _searchNumStart
        push rax

        ; here r13 is temporarely used to store a cycle counter
        ; need to remove duplicates in case multiple digits of the same number
        ; surround the symbol ("part") found
        ; r14 contains how many results to check. It's 6 because of
        ; (left, mid, right) * (top, bottom)
        mov r13, 0                      ; used to store last search result
        mov r14, 6                      ; how many results to check
_searchCntPN_checkResults:
        sub r14, 1
        js _searchCntPN_nextChar

        pop rdi                         ; restore last search result
        cmp rdi, 0
        je _searchCntPN_checkResults    ; skip if 0 (nothing found)
        cmp rdi, r13                    
        je _searchCntPN_checkResults    ; skip if found same numer as last time

        mov r13, rdi                    ; memorize that last num starts at RDI
        call _getInt                    ; get number value
        add r12, rax

        jmp _searchCntPN_checkResults   ; check next search result

_searchCntPN_ret:
        mov rax, r12

        pop r14                         ; restore CSRs
        pop r13
        pop r12
        pop rbx

        ret

; Searches for start of decimal number at string with address RDI
; Returns start addr, or 0 if not found
_searchNumStart:
        mov al, byte [rdi]
        cmp al, '0'
        jb _searchNumStart_notFound
        cmp al, '9'
        ja _searchNumStart_notFound

_searchNumStart_nextChar:       ; if we're here -> num found! Search beginning
        dec rdi
        mov al, byte [rdi]
        cmp al, '0'
        jb _searchNumStart_ret
        cmp al, '9'
        ja _searchNumStart_ret
        jmp _searchNumStart_nextChar
        
_searchNumStart_ret:
        mov rax, rdi
        inc rax
        ret

_searchNumStart_notFound:
        mov rax, 0
        ret

; Read a string from stdin.
; RDI -> where to store the string. (will include '\n')
;(RSI)-> (NOT IMPLEMENTED) max string length (program will exit if exceeded)
; return: . length (comprised of '\n')
;         . -1 (if EOF)
_readLine:
        push rbx                ; save CSR. Used to store current dest addr
        push rdi                ; restored later to get string length
        
        mov rbx, rdi

_readLine_nextChar:
        mov rax, SYSCALL_READ
        mov rdi, STDIN
        mov rsi, rbx
        mov rdx, 1
        syscall

        cmp rax, 0              ; EOF?
        je _readLine_EOF

        mov al, byte [rbx]
        inc rbx                 ; point to next character
        cmp al, 10              ; \n ?
        jne _readLine_nextChar

_readLine_eol:                  ; end-of-line
        pop rdi
        sub rbx, rdi            ; calculate string length
        mov rax, rbx

_readLine_ret:
        pop rbx                 ; restore CSR
        ret

_readLine_EOF:
        pop rdi                 ; discard saved RDI
        mov rax, -1
        jmp _readLine_ret

; reads a 64bits unsigned decimal integer from string at [RDI] and returns it
; reading stops when a non-digit character is read
; (so, it will read 1 byte past the end)
_getInt:
        push r12                ; save CSR
        mov r12, 0              ; will store read number
        push rbx                ; save CSR
        mov rbx, rdi            ; RBX used to store ptr of read char

_getInt_nextDigit:
        movzx rdi, byte [rbx]   ; ensure high bytes are 0
        call _getDigit          ; calculate digit value. -1 if not a digit
        cmp rax, -1
        je _getInt_ret

        mov rcx, rax            ; R12 = (R12 * 10) + RAX
        mov rax, 10             ; (i.e. take new decimal digit)
        mul r12
        add rax, rcx            ; MUL result is in RAX
        mov r12, rax
        inc rbx
        jmp _getInt_nextDigit

_getInt_ret:
        pop rbx
        mov rax, r12
        pop r12
        ret
        
; in: ASCII character
; out : numeric digit value if it's a digit. -1 otherwise
_getDigit:
        sub rdi, '0'
        jb _getDigit_invalid    ; Jump Below (i.e. < 0x30)
        cmp rdi, 9
        ja _getDigit_invalid
        mov rax, rdi
        ret
_getDigit_invalid:
        mov rax, -1
        ret

; Prints the unsigned number in `RDI` to stdout
; Reserves string on stack (TODO test)
_printInt:
        mov rsi, 0      ; number of decimal digits
        mov r8, 10      ; stores divisor
        dec rsp
        mov r9, rsp     ; points to where to store current digit
        sub rsp, 19     ; 0xff..ff is 20 digits long.
                        ; note: RSP always points to the last pushed entry

        mov byte [r9], 10 ; print line feed after number
        dec r9
        inc rsi

        cmp rdi, 0      ; handle special case when number to print is 0
        je _printInt_print0

        mov rax, rdi    ; dividend is in rdx:rax

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
        
        add rsp, 20     ; restore stack space

        ret

_printInt_print0:
        mov byte [r9], '0'
        dec r9
        inc rsi
        jmp _printInt_print
