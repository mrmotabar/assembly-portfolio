; ==============================================================================
; File: perfect-number.asm
; Description: Tests if a positive integer is a perfect number (equal to the sum
;              of its proper positive divisors). Prints "Perfect" and lists the
;              divisors, or prints "Nope".
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .data
    message_perfect     db "Perfect", ASCII_NEWLINE, 0
    message_not_perfect db "Nope", ASCII_NEWLINE, 0
    string_space        db " ", 0

section .text
    global _start

_start:
    call    read_number
    mov     r8, rax             ; R8 = target number N

    xor     r9, r9              ; R9 = running sum of divisors
    mov     r10, r8             ; R10 = candidate divisor counter
    xor     r12, r12            ; R12 = count of found divisors

.find_divisors_loop:
    dec     r10
    cmp     r10, 1
    jl      .evaluation

    xor     rdx, rdx
    mov     rax, r8
    div     r10
    test    rdx, rdx
    jnz     .find_divisors_loop ; Not a divisor

    ; Found divisor r10
    inc     r12
    push    r10                 ; Save divisor on stack
    add     r9, r10             ; Accumulate sum
    jmp     .find_divisors_loop

.evaluation:
    cmp     r9, r8
    je      .handle_perfect

    mov     rsi, message_not_perfect
    call    print_string
    jmp     .print_divisors

.handle_perfect:
    mov     rsi, message_perfect
    call    print_string

.print_divisors:
    test    r12, r12
    jz      .exit_program

    dec     r12
    pop     rax
    call    write_number

    test    r12, r12
    jz      .finish_printing
    mov     rsi, string_space
    call    print_string
    jmp     .print_divisors

.finish_printing:
    call    print_newline

.exit_program:
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
