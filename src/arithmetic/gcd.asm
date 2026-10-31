; ==============================================================================
; File: gcd.asm
; Description: Calculates the Greatest Common Divisor (GCD) of two 64-bit signed
;              integers using Euclid's division algorithm in x86_64 assembly.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .data
    prompt_first_number     db "Enter first integer: ", 0
    prompt_second_number    db "Enter second integer: ", 0
    message_result          db "GCD: ", 0

section .text
    global _start

_start:
    ; Read first integer
    call    read_number
    mov     r8, rax

    ; Read second integer
    call    read_number
    mov     r9, rax

    ; Ensure r8 >= r9 (normalize ordering)
    cmp     r8, r9
    jge     .euclid_loop
    xchg    r8, r9

.euclid_loop:
    ; While r9 != 0: r8, r9 = r9, r8 % r9
    test    r9, r9
    jz      .compute_done

    xor     rdx, rdx
    mov     rax, r8
    div     r9                  ; RDX = R8 % R9
    mov     r8, r9              ; R8 = old R9
    mov     r9, rdx             ; R9 = remainder
    jmp     .euclid_loop

.compute_done:
    ; Print result
    mov     rax, r8
    call    write_number
    call    print_newline

    ; Exit cleanly (sys_exit, status 0)
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
