; ==============================================================================
; File: popcount.asm
; Description: Calculates the population count (Hamming weight / number of set bits)
;              across a byte buffer or sliced character sequence in x86_64 assembly.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .bss
    text_buffer     resb 10000

section .text
    global _start

; ------------------------------------------------------------------------------
; Routine: count_byte_ones
; Counts set bits in register AL using bitwise shift and accumulation.
; Inputs:
;   AL - Byte to inspect
; Outputs:
;   RBX - Accumulated total set bits
; ------------------------------------------------------------------------------
count_byte_ones:
    mov     dl, 1

.bit_scan_loop:
    test    al, al
    jz      .byte_scan_done

    test    al, 1
    jz      .shift_next_bit
    inc     rbx

.shift_next_bit:
    shr     al, 1
    jmp     .bit_scan_loop

.byte_scan_done:
    ret

; ------------------------------------------------------------------------------
; Main Program: Reads start_index, end_index, reads string, and counts ones
; ------------------------------------------------------------------------------
_start:
    xor     rbx, rbx            ; RBX = total set bits accumulator

    ; Read start index
    call    read_number
    mov     r9, rax

    ; Read end index
    call    read_number
    mov     r10, rax

    ; Skip bytes before start_index
    test    r9, r9
    jz      .read_target_span

    mov     rsi, text_buffer
    mov     rdx, r9
    mov     rax, SYS_READ
    mov     rdi, STDIN_FILENO
    syscall

.read_target_span:
    ; Read the span between start and end (r10 - r9 + 1)
    sub     r10, r9
    inc     r10

    mov     rsi, text_buffer
    mov     rdx, r10
    mov     rax, SYS_READ
    mov     rdi, STDIN_FILENO
    syscall

    test    rax, rax
    jle     .output_count

    ; Iterate through bytes read and count ones
    mov     rcx, rax
    mov     r8, text_buffer

.process_bytes_loop:
    mov     al, [r8]
    push    rcx
    call    count_byte_ones
    pop     rcx
    inc     r8
    loop    .process_bytes_loop

.output_count:
    mov     rax, rbx
    call    write_number
    call    print_newline

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
