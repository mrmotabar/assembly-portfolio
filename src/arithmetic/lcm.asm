; ==============================================================================
; File: lcm.asm
; Description: Calculates the Least Common Multiple (LCM) of two 64-bit integers
;              using the formula: LCM(a, b) = (|a * b|) / GCD(a, b).
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .text
    global _start

_start:
    ; Read first integer a
    call    read_number
    mov     r8, rax
    mov     r12, rax            ; Save original a in R12

    ; Read second integer b
    call    read_number
    mov     r9, rax
    mov     r13, rax            ; Save original b in R13

    ; Order: ensure r8 >= r9
    cmp     r8, r9
    jge     .compute_gcd
    xchg    r8, r9

.compute_gcd:
    test    r9, r9
    jz      .compute_lcm

    xor     rdx, rdx
    mov     rax, r8
    div     r9
    mov     r8, r9
    mov     r9, rdx
    jmp     .compute_gcd

.compute_lcm:
    ; R8 now holds GCD(a, b)
    ; LCM = (R12 * R13) / R8
    mov     rax, r12
    mul     r13                 ; RDX:RAX = R12 * R13
    div     r8                  ; RAX = (R12 * R13) / GCD

    call    write_number
    call    print_newline

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
