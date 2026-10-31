; ==============================================================================
; File: digit-sum-even-odd.asm
; Description: Extracts the decimal digits of an input integer and outputs the
;              sum of odd digits followed by the sum of even digits.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .data
    separator_space     db " ", 0

section .text
    global _start

_start:
    call    read_number

    xor     r12, r12            ; R12 = sum of even digits
    xor     r13, r13            ; R13 = sum of odd digits
    mov     r8, 10              ; Base 10

.extract_loop:
    test    rax, rax
    jz      .output_results

    xor     rdx, rdx
    div     r8                  ; RAX = quotient, RDX = extracted digit

    ; Test if digit is odd or even (bit 0)
    test    rdx, 1
    jnz     .is_odd_digit

.is_even_digit:
    add     r12, rdx
    jmp     .extract_loop

.is_odd_digit:
    add     r13, rdx
    jmp     .extract_loop

.output_results:
    ; Print sum of odd digits
    mov     rax, r13
    call    write_number

    ; Print space separator
    mov     rsi, separator_space
    call    print_string

    ; Print sum of even digits
    mov     rax, r12
    call    write_number
    call    print_newline

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
