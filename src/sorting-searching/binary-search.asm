; ==============================================================================
; File: binary-search.asm
; Description: Binary Search algorithm in x86_64 NASM assembly. Reads an array
;              of sorted integers and multiple query targets, returning the
;              0-based index of each query or "NaN" if not present.
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

MAX_ELEMENTS        equ 100010

section .data
    message_not_found   db "NaN", ASCII_NEWLINE, 0
    constant_two        dq 2

section .bss
    sorted_array        resq MAX_ELEMENTS
    total_elements      resq 1

section .text
    global _start

; ------------------------------------------------------------------------------
; Routine: binary_search_recursive
; Stack parameters:
;   [RBP + 32] - Low index (left)
;   [RBP + 24] - High index (right)
;   [RBP + 16] - Target value
; Returns:
;   R8 - Matching index (or boundary)
; ------------------------------------------------------------------------------
binary_search_recursive:
    enter   0, 0

    mov     rax, qword [rbp + 24]       ; right
    sub     rax, qword [rbp + 32]       ; right - left
    cmp     rax, 1
    mov     r8, qword [rbp + 24]
    jle     .search_return

    ; Calculate midpoint = (left + right) / 2
    mov     rax, qword [rbp + 24]
    add     rax, qword [rbp + 32]
    xor     rdx, rdx
    div     qword [constant_two]        ; RAX = midpoint

    mov     rdx, qword [sorted_array + rax * 8]
    cmp     rdx, qword [rbp + 16]       ; Compare array[mid] with target
    jae     .search_left_half

.search_right_half:
    push    rax                         ; left = mid
    push    qword [rbp + 24]            ; right = right
    push    qword [rbp + 16]            ; target
    call    binary_search_recursive
    jmp     .search_return

.search_left_half:
    push    qword [rbp + 32]            ; left = left
    push    rax                         ; right = mid
    push    qword [rbp + 16]            ; target
    call    binary_search_recursive

.search_return:
    leave
    ret     24

; ------------------------------------------------------------------------------
; Main Program
; ------------------------------------------------------------------------------
_start:
    ; Read number of elements N
    call    read_number
    mov     qword [total_elements], rax

    ; Set sentinel at index 0
    mov     qword [sorted_array], -1
    mov     rcx, 1
    inc     qword [total_elements]

.read_elements_loop:
    cmp     rcx, qword [total_elements]
    je      .read_queries

    push    rcx
    call    read_number
    pop     rcx

    mov     qword [sorted_array + rcx * 8], rax
    inc     rcx
    jmp     .read_elements_loop

.read_queries:
    ; Add positive infinity sentinel
    mov     qword [sorted_array + rcx * 8], 1
    shl     qword [sorted_array + rcx * 8], 62
    inc     qword [total_elements]

    ; Read number of queries Q
    call    read_number
    mov     r12, rax                    ; R12 = Q
    xor     r13, r13                    ; R13 = query counter

.process_queries_loop:
    cmp     r13, r12
    jge     .exit_program

    call    read_number
    mov     r15, rax                    ; Target query value

    ; Perform binary search on [0, total_elements]
    push    0
    push    qword [total_elements]
    push    r15
    call    binary_search_recursive

    ; Check if sorted_array[R8] == target
    cmp     qword [sorted_array + r8 * 8], r15
    je      .target_found

.target_not_found:
    mov     rsi, message_not_found
    call    print_string
    inc     r13
    jmp     .process_queries_loop

.target_found:
    mov     rax, r8
    dec     rax                         ; Convert 1-based index to 0-based
    call    write_number
    call    print_newline
    inc     r13
    jmp     .process_queries_loop

.exit_program:
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
