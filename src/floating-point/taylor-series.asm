; ==============================================================================
; File: taylor-series.asm
; Description: Calculates the exponential function e^x using its Taylor series
;              expansion e^x = sum(x^k / k!) for k = 0 to N using the x87
;              Floating-Point Unit (FPU) stack in x86_64 assembly.
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
    format_print_float      db  "%.8lf", ASCII_NEWLINE, 0

    max_terms               dq  0
    input_x                 dq  0.0
    series_result           dq  1.0
    iteration_temp          dq  0

section .text
    global main

main:
    ; Read number of series terms N using integer reader
    call    read_number
    mov     qword [max_terms], rax

    ; Read floating-point value x via scanf
    push    rbp
    mov     rdi, format_scan_float
    mov     rsi, input_x
    xor     rax, rax
    call    scanf
    pop     rbp

    mov     r8, 1               ; Term index k = 1

    ; Push 1.0 (running term) and 1.0 (accumulated sum) onto x87 FPU stack
    fld     qword [series_result]   ; st1 = accumulated sum (1.0)
    fld     qword [series_result]   ; st0 = current term (1.0)

.series_iteration_loop:
    cmp     r8, qword [max_terms]
    jg      .print_result

    ; Compute next term: term_k = term_{k-1} * (x / k)
    fld     qword [input_x]     ; Push x
    mov     qword [iteration_temp], r8
    fild    qword [iteration_temp] ; Push k
    fdivp   st1, st0            ; st0 = x / k
    fmul    st1, st0            ; current term = previous term * (x / k)
    fstp    st0                 ; Clean up quotient

    fadd    st1, st0            ; sum += current term

    inc     r8
    jmp     .series_iteration_loop

.print_result:
    fstp    st0                 ; Discard current term
    fstp    qword [series_result] ; Pop accumulated sum into series_result

    ; Print result via printf
    push    rbp
    mov     rdi, format_print_float
    movq    xmm0, qword [series_result]
    mov     rax, 1              ; 1 floating-point argument in XMM0
    call    printf
    pop     rbp

.exit_program:
    xor     rdi, rdi
    call    fflush

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
