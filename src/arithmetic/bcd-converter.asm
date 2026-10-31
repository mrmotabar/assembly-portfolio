; ==============================================================================
; File: bcd-converter.asm
; Description: Converts a 3-digit decimal integer into its Binary-Coded Decimal
;              (BCD) representation and outputs the binary bit stream.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .text
    global _start

_start:
    mov     r8, 2
    mov     r9, 10
    mov     r10, 100

    call    read_number

    xor     r11, r11
    xor     r12, r12
    xor     r13, r13
    xor     r14, r14

    mul     r9
    add     rax, 1

.reverse_digits:
    test    rax, rax
    jz      .reverse_digits_done

    push    rax
    mov     rax, r14
    mul     r9
    mov     r14, rax
    pop     rax

    xor     rdx, rdx
    div     r9
    add     r14, rdx
    jmp     .reverse_digits

.reverse_digits_done:
    mov     rax, r14
    xor     r14, r14

.construct_binary:
    cmp     rax, 1
    jz      .binary_constructed

    push    rax
    mov     rax, r14
    mul     r8
    mov     r14, rax
    pop     rax

    div     r9
    add     r14, rdx
    jmp     .construct_binary

.binary_constructed:
    mov     rax, r14
    xor     r14, r14

    ; Unpack 3-digit BCD nibbles (ones, tens, hundreds)
    mov     r11, rax
    mov     r12, rax
    mov     r13, rax

    and     r11, 0x0F           ; Lowest nibble (ones)
    and     r12, 0xF0           ; Middle nibble (tens)
    and     r13, 0xF00          ; High nibble (hundreds)

    shr     r13, 2
    add     r11, r13
    shr     r13, 1
    add     r11, r13
    shr     r13, 3
    add     r11, r13

    shr     r12, 1
    add     r11, r12
    shr     r12, 2
    add     r11, r12

    mov     rax, r11
    shl     rax, 1
    add     rax, 1

.reverse_bits:
    test    rax, rax
    jz      .reverse_bits_done

    push    rax
    mov     rax, r14
    mul     r8
    mov     r14, rax
    pop     rax

    xor     rdx, rdx
    div     r8
    add     r14, rdx
    jmp     .reverse_bits

.reverse_bits_done:
    mov     rax, r14
    xor     r14, r14

.print_bits:
    cmp     rax, 1
    jz      .exit_program

    xor     rdx, rdx
    div     r8

    test    rdx, rdx
    jz      .print_zero

.print_one:
    push    rax
    mov     al, '1'
    call    print_character
    pop     rax
    jmp     .print_bits

.print_zero:
    push    rax
    mov     al, '0'
    call    print_character
    pop     rax
    jmp     .print_bits

.exit_program:
    call    print_newline
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
