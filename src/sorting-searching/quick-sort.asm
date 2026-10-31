; ==============================================================================
; File: quick-sort.asm
; Description: Recursive QuickSort algorithm implemented in 64-bit x86_64 NASM
;              assembly. Reads N 64-bit signed integers from stdin, sorts them
;              in ascending order using partition recursion, and prints them.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

MAX_ARRAY_CAPACITY  equ 1000000

section .data
    separator_space db  " ", 0

section .bss
    integer_array   resq MAX_ARRAY_CAPACITY
    element_count   resq 1

section .text
    global _start

; ------------------------------------------------------------------------------
; Routine: quicksort_recursive
; Inputs on stack:
;   [RBP + 24] - Low index (left)
;   [RBP + 16] - High index (right)
; ------------------------------------------------------------------------------
quicksort_recursive:
    enter   8, 0

    mov     r8, qword [rbp + 24]        ; Left index
    mov     r9, qword [rbp + 16]        ; Right index
    mov     r10, qword [integer_array + r8 * 8] ; Pivot element = array[left]
    mov     r14, qword [rbp + 24]       ; Save original left
    mov     r15, qword [rbp + 16]       ; Save original right

    ; Base condition: if left >= right, return
    cmp     r14, r15
    jge     .sort_complete

    inc     r15

.partition_loop:
    cmp     r8, r15
    je      .place_pivot
    cmp     r8, r9
    jg      .place_pivot

    ; Scan right until element > pivot
    cmp     qword [integer_array + r8 * 8], r10
    jg      .scan_from_right

    inc     r8
    jmp     .partition_loop

.scan_from_right:
    cmp     r8, r9
    je      .place_pivot

    ; Scan left until element <= pivot
    cmp     qword [integer_array + r9 * 8], r10
    jle     .swap_elements

    dec     r9
    jmp     .scan_from_right

.swap_elements:
    ; Swap array[r8] and array[r9]
    push    qword [integer_array + r8 * 8]
    push    qword [integer_array + r9 * 8]
    pop     qword [integer_array + r8 * 8]
    pop     qword [integer_array + r9 * 8]

    dec     r9
    inc     r8
    jmp     .partition_loop

.place_pivot:
    dec     r8
    mov     qword [rbp - 8], r8

    ; Swap array[r8] and array[left]
    push    qword [integer_array + r8 * 8]
    push    qword [integer_array + r14 * 8]
    pop     qword [integer_array + r8 * 8]
    pop     qword [integer_array + r14 * 8]

    dec     r8

    ; Recursive call: left subarray (left to r8-1)
    push    qword [rbp + 24]
    push    r8
    call    quicksort_recursive

    ; Recursive call: right subarray (r8+1 to right)
    mov     r9, qword [rbp - 8]
    inc     r9
    push    r9
    push    qword [rbp + 16]
    call    quicksort_recursive

.sort_complete:
    leave
    ret     16

; ------------------------------------------------------------------------------
; Main Program Entry Point
; ------------------------------------------------------------------------------
_start:
    ; 1. Read array length N
    call    read_number
    mov     qword [element_count], rax

    test    rax, rax
    jle     .exit_program

    ; 2. Read N integers into integer_array
    xor     rcx, rcx

.read_array_loop:
    cmp     rcx, qword [element_count]
    je      .start_sorting

    push    rcx
    call    read_number
    pop     rcx

    mov     qword [integer_array + rcx * 8], rax
    inc     rcx
    jmp     .read_array_loop

.start_sorting:
    ; 3. Execute recursive QuickSort on range [0, N - 1]
    mov     rax, qword [element_count]
    dec     rax
    push    0                           ; Left = 0
    push    rax                         ; Right = N - 1
    call    quicksort_recursive

    ; 4. Print sorted integers separated by spaces
    xor     r8, r8
    mov     r9, qword [element_count]
    dec     r9

.print_array_loop:
    cmp     r8, qword [element_count]
    jge     .finish_output

    mov     rax, qword [integer_array + r8 * 8]
    call    write_number

    cmp     r8, r9
    je      .finish_output

    mov     rsi, separator_space
    call    print_string
    inc     r8
    jmp     .print_array_loop

.finish_output:
    call    print_newline

.exit_program:
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
