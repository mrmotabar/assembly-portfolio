; ==============================================================================
; File: prime-checker.asm
; Description: Determines whether a given positive integer is prime using trial
;              division up to floor(sqrt(n)) in x86_64 assembly.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .data
    message_yes     db "Yes", ASCII_NEWLINE, 0
    message_no      db "No", ASCII_NEWLINE, 0

section .text
    global _start

_start:
    call    read_number
    mov     r8, rax             ; R8 = target number n

    ; Numbers <= 1 are not prime
    cmp     r8, 1
    jle     .not_prime

    ; 2 and 3 are prime
    cmp     r8, 2
    je      .is_prime
    cmp     r8, 3
    je      .is_prime

    ; Even numbers > 2 are not prime
    test    r8, 1
    jz      .not_prime

    ; Compute integer sqrt limit in R9
    call    compute_sqrt_limit  ; Returns ceil(sqrt(n)) in R9

    ; Trial division: check odd divisors starting at 3
    mov     r10, 3

.trial_division_loop:
    cmp     r10, r9
    ja      .is_prime           ; Divisors exhausted -> number is prime

    xor     rdx, rdx
    mov     rax, r8
    div     r10
    test    rdx, rdx
    jz      .not_prime          ; Divisible without remainder -> composite

    add     r10, 2              ; Test next odd divisor
    jmp     .trial_division_loop

.is_prime:
    mov     rsi, message_yes
    call    print_string
    jmp     .exit_program

.not_prime:
    mov     rsi, message_no
    call    print_string

.exit_program:
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall

; ------------------------------------------------------------------------------
; Routine: compute_sqrt_limit
; Computes smallest integer R9 such that R9 * R9 >= R8
; ------------------------------------------------------------------------------
compute_sqrt_limit:
    mov     r12, 1
.sqrt_loop:
    inc     r12
    mov     rax, r12
    mul     r12
    cmp     rax, r8
    jbe     .sqrt_loop
    mov     r9, r12
    ret
