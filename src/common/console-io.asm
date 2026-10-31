; ==============================================================================
; File: console-io.asm
; Description: Standard console input and output routines for Linux x86_64.
;              Provides functions for reading/writing characters, strings, and
;              signed 64-bit integers using Linux system calls.
; Architecture: x86_64 (Linux ELF64)
; ==============================================================================

%ifndef CONSOLE_IO_ASM
%define CONSOLE_IO_ASM

%include "system-constants.asm"

section .text

; ------------------------------------------------------------------------------
; Routine: print_newline (alias: newLine)
; Description: Prints a single newline character (0x0A) to standard output.
; Preserves: All general-purpose registers.
; ------------------------------------------------------------------------------
global print_newline
global newLine

print_newline:
newLine:
    push    rax
    mov     al, ASCII_NEWLINE
    call    print_character
    pop     rax
    ret

; ------------------------------------------------------------------------------
; Routine: print_character (alias: putc)
; Description: Writes a single character to standard output.
; Inputs:
;   AL - Character to print
; Preserves: RCX, RDX, RSI, RDI, R11, RAX
; ------------------------------------------------------------------------------
global print_character
global putc

print_character:
putc:
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r11
    push    rax

    ; Allocate 1 byte on stack for the character buffer
    push    ax
    mov     rsi, rsp            ; Pointer to character buffer
    mov     rdx, 1              ; Byte count = 1
    mov     rax, SYS_WRITE      ; Syscall 1 (sys_write)
    mov     rdi, STDOUT_FILENO  ; stdout fd = 1
    syscall
    pop     ax

    pop     rax
    pop     r11
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    ret

; ------------------------------------------------------------------------------
; Routine: get_character (alias: getc)
; Description: Reads a single character from standard input.
; Returns:
;   AL - Character read, or 0 if EOF / error
; Preserves: RCX, RDX, RSI, RDI, R11
; ------------------------------------------------------------------------------
global get_character
global getc

get_character:
getc:
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r11

    sub     rsp, 8              ; Allocate 8-byte aligned buffer on stack
    mov     byte [rsp], 0       ; Initialize byte to 0
    mov     rsi, rsp            ; Pointer to destination buffer
    mov     rdx, 1              ; Read 1 byte
    mov     rax, SYS_READ       ; Syscall 0 (sys_read)
    mov     rdi, STDIN_FILENO   ; stdin fd = 0
    syscall

    cmp     rax, 1              ; Did we read exactly 1 byte?
    je      .read_success
    mov     al, 0               ; Return 0 on EOF or error
    jmp     .getc_done

.read_success:
    mov     al, [rsp]

.getc_done:
    add     rsp, 8
    pop     r11
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    ret

; ------------------------------------------------------------------------------
; Routine: print_string (alias: printString)
; Description: Writes a null-terminated string to standard output.
; Inputs:
;   RSI - Address of the null-terminated string
; Preserves: RAX, RCX, RDX, RSI, RDI, R11
; ------------------------------------------------------------------------------
global print_string
global printString

print_string:
printString:
    push    rax
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r11

    mov     rdi, rsi            ; Set RDI to string pointer for GetStrlen
    call    get_string_length   ; Returns length in RDX
    mov     rax, SYS_WRITE      ; Syscall 1 (sys_write)
    mov     rdi, STDOUT_FILENO  ; stdout fd = 1
    syscall

    pop     r11
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rax
    ret

; ------------------------------------------------------------------------------
; Routine: get_string_length (alias: GetStrlen)
; Description: Computes the length of a null-terminated string.
; Inputs:
;   RDI - Pointer to null-terminated string
; Returns:
;   RDX - Length of the string (excluding terminating null byte)
; Preserves: RAX, RBX, RCX, RDI
; ------------------------------------------------------------------------------
global get_string_length
global GetStrlen

get_string_length:
GetStrlen:
    push    rax
    push    rbx
    push    rcx
    push    rdi

    xor     rcx, rcx
    not     rcx                 ; RCX = -1 (maximum count)
    xor     rax, rax            ; Look for null terminator (0x00)
    cld
    repne   scasb               ; Scan until [RDI] == 0
    not     rcx                 ; Invert RCX to get characters scanned + 1
    lea     rdx, [rcx - 1]      ; RDX = string length

    pop     rdi
    pop     rcx
    pop     rbx
    pop     rax
    ret

; ------------------------------------------------------------------------------
; Routine: read_number (alias: readNum)
; Description: Reads a signed 64-bit integer from standard input in decimal form.
;              Supports optional '+' or '-' prefix, and terminates on whitespace
;              (space, newline, carriage return) or EOF.
; Returns:
;   RAX - Parsed signed 64-bit integer
; Preserves: RBX, RCX, RDX
; ------------------------------------------------------------------------------
global read_number
global readNum

read_number:
readNum:
    push    rbx
    push    rcx
    push    rdx

    xor     rbx, rbx            ; BL = 1 if negative, 0 if positive
    xor     rdx, rdx            ; RDX = accumulated numeric value

.skip_leading_whitespace:
    call    get_character
    test    al, al
    jz      .parse_done         ; EOF reached
    cmp     al, ASCII_SPACE
    je      .skip_leading_whitespace
    cmp     al, ASCII_TAB
    je      .skip_leading_whitespace
    cmp     al, ASCII_NEWLINE
    je      .skip_leading_whitespace
    cmp     al, ASCII_RETURN
    je      .skip_leading_whitespace

    ; Check for leading sign characters
    cmp     al, ASCII_MINUS
    jne     .check_plus
    mov     bl, 1               ; Set negative flag
    jmp     .read_digits

.check_plus:
    cmp     al, ASCII_PLUS
    je      .read_digits
    jmp     .process_first_char

.read_digits:
    call    get_character

.process_first_char:
.accumulate_loop:
    ; Check for termination delimiters
    test    al, al
    jz      .parse_done
    cmp     al, ASCII_NEWLINE
    je      .parse_done
    cmp     al, ASCII_RETURN
    je      .parse_done
    cmp     al, ASCII_SPACE
    je      .parse_done
    cmp     al, ASCII_TAB
    je      .parse_done

    ; Validate digit range ('0' through '9')
    cmp     al, ASCII_ZERO
    jb      .parse_done
    cmp     al, ASCII_NINE
    ja      .parse_done

    ; Convert ASCII character to numeric digit
    sub     al, ASCII_ZERO
    movzx   rax, al
    imul    rdx, 10
    add     rdx, rax

    call    get_character
    jmp     .accumulate_loop

.parse_done:
    mov     rax, rdx
    test    bl, bl
    jz      .exit_read_number
    neg     rax                 ; Negate if sign was negative

.exit_read_number:
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ------------------------------------------------------------------------------
; Routine: write_number (alias: writeNum)
; Description: Writes a signed 64-bit integer in decimal form to standard output.
; Inputs:
;   RAX - Signed integer to print
; Preserves: RAX, RBX, RCX, RDX
; ------------------------------------------------------------------------------
global write_number
global writeNum

write_number:
writeNum:
    push    rax
    push    rbx
    push    rcx
    push    rdx

    xor     rdx, rdx
    mov     rbx, 10
    xor     rcx, rcx            ; RCX counts the number of digits pushed

    ; Check if number is negative
    cmp     rax, 0
    jge     .extract_digits
    push    rax
    mov     al, ASCII_MINUS
    call    print_character
    pop     rax
    neg     rax

.extract_digits:
    xor     rdx, rdx
    div     rbx                 ; RAX = quotient, RDX = remainder
    push    rdx                 ; Save remainder digit on stack
    inc     rcx                 ; Digit count++
    test    rax, rax
    jnz     .extract_digits

.print_digits_loop:
    pop     rax
    add     al, ASCII_ZERO      ; Convert digit to ASCII
    call    print_character
    dec     rcx
    jnz     .print_digits_loop

    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

%endif ; CONSOLE_IO_ASM
