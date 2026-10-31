; ==============================================================================
; File: digit-sum.asm
; Description: Reads a non-negative decimal integer and calculates the sum
;              of its decimal digits.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .text
    global _start

_start:
    call    read_number         ; Input integer in RAX

    mov     r8, 10              ; Divisor base 10
    xor     r9, r9              ; R9 = accumulated sum of digits

.extract_digits_loop:
    test    rax, rax
    jz      .sum_completed

    xor     rdx, rdx
    div     r8                  ; RAX = RAX / 10, RDX = digit (0..9)
    add     r9, rdx             ; Sum += digit
    jmp     .extract_digits_loop

.sum_completed:
    mov     rax, r9
    call    write_number
    call    print_newline

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
