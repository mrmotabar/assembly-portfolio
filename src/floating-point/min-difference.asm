; ==============================================================================
; File: min-difference.asm
; Description: Finds the pair of floating-point numbers with the minimum absolute
;              difference in an array using the x87 FPU comparison instructions.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; Dependencies: Linked with libc for formatted floating-point I/O (printf, scanf)
; ==============================================================================

%include "console-io.asm"

extern fflush
extern printf
extern scanf

section .data
    format_scan_float       db  "%lf", 0
    format_print_pair       db  "%.6lf %.6lf", ASCII_NEWLINE, 0

    array_size              dq  0
    minimum_difference      dq  999999999.0
    best_element_first      dq  0.0
    best_element_second     dq  0.0
    garbage_trash           dq  0.0

section .bss
    float_array             resq 500

section .text
    global main

main:
    ; Read N
    call    read_number
    mov     qword [array_size], rax

    mov     r15, qword [array_size]
    mov     r14, float_array

.read_elements_loop:
    test    r15, r15
    jz      .find_minimum_pair

    push    rbp
    mov     rdi, format_scan_float
    mov     rsi, r14
    xor     rax, rax
    call    scanf
    pop     rbp

    add     r14, 8
    dec     r15
    jmp     .read_elements_loop

.find_minimum_pair:
    xor     r8, r8              ; Outer loop i = 0

.outer_loop:
    cmp     r8, qword [array_size]
    jge     .print_best_pair

    xor     r9, r9              ; Inner loop j = 0

.inner_loop:
    cmp     r9, r8
    jge     .advance_outer

    ; Compute diff = |array[i] - array[j]|
    fld     qword [float_array + r8 * 8]
    fsub    qword [float_array + r9 * 8]

    ; Check if difference is negative
    ftst
    fstsw   ax
    and     ax, 0100011100000000B
    cmp     ax, 0000000100000000B
    jne     .compare_with_min

    fchs                        ; Negate to make positive

.compare_with_min:
    fcom    qword [minimum_difference]
    fstsw   ax
    and     ax, 0100011100000000B
    cmp     ax, 0000000100000000B
    je      .new_minimum_found

    ; Discard comparison value
    fstp    qword [garbage_trash]
    inc     r9
    jmp     .inner_loop

.new_minimum_found:
    fst     qword [minimum_difference]
    mov     rax, [float_array + r9 * 8]
    mov     [best_element_first], rax
    mov     rax, [float_array + r8 * 8]
    mov     [best_element_second], rax

    fstp    qword [garbage_trash]
    inc     r9
    jmp     .inner_loop

.advance_outer:
    inc     r8
    jmp     .outer_loop

.print_best_pair:
    push    rbp
    mov     rdi, format_print_pair
    movq    xmm0, qword [best_element_first]
    movq    xmm1, qword [best_element_second]
    mov     rax, 2              ; 2 floating point args in XMM0, XMM1
    call    printf
    pop     rbp

.exit_program:
    xor     rdi, rdi
    call    fflush

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
