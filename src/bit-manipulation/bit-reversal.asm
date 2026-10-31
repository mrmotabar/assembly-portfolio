; ==============================================================================
; File: bit-reversal.asm
; Description: Reads a 64-bit unsigned integer and outputs its binary representation
;              in reverse bit order (from LSB to MSB) across all 64 bits.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .text
    global _start

_start:
    call    read_number         ; Input integer in RAX

    mov     ecx, 64             ; 64 bit positions
    mov     r8, 2

.reversal_loop:
    xor     rdx, rdx
    div     r8                  ; RAX = RAX / 2, RDX = lowest bit (0 or 1)

    push    rax
    mov     al, dl
    add     al, '0'             ; Convert 0/1 to '0'/'1'
    call    print_character
    pop     rax

    loop    .reversal_loop

    call    print_newline

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
