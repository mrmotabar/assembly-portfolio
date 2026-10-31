; ==============================================================================
; File: expression-calculator.asm
; Description: Recursive-descent arithmetic expression evaluator supporting
;              addition, subtraction, multiplication, integer division, parentheses
;              grouping, unary +/- signs, and previous answer recall ('ans').
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards
; ==============================================================================

%include "console-io.asm"

section .data
    decimal_base            dq  10
    prompt_expression       db  "Enter expression (or '&' to exit): ", 0

section .bss
    expression_input        resb 256
    expression_length       resq 1
    parenthesis_matching_table resq 256
    unary_minus_mask        resb 256
    current_answer          resq 1
    previous_answer         resq 1

section .text
    global _start

; ------------------------------------------------------------------------------
; Routine: read_expression_line
; Reads a line of text into expression_input until newline.
; ------------------------------------------------------------------------------
read_expression_line:
    push    r8
    push    rax

    mov     qword [expression_length], 0
    mov     r8, expression_input

.read_char_loop:
    call    get_character
    cmp     al, ASCII_NEWLINE
    je      .read_done
    cmp     al, ASCII_RETURN
    je      .read_done
    test    al, al
    jz      .read_done

    mov     [r8], al
    inc     r8
    inc     qword [expression_length]
    jmp     .read_char_loop

.read_done:
    mov     byte [r8], 0
    pop     rax
    pop     r8
    ret

; ------------------------------------------------------------------------------
; Routine: match_parentheses
; Matches opening '(' and closing ')' indices using a stack table.
; ------------------------------------------------------------------------------
match_parentheses:
    xor     r9, r9
    mov     r8, expression_input

.scan_loop:
    cmp     r9, qword [expression_length]
    jge     .match_done

    cmp     byte [r8], '('
    je      .push_open_paren
    cmp     byte [r8], ')'
    je      .pop_close_paren

.advance:
    inc     r8
    inc     r9
    jmp     .scan_loop

.push_open_paren:
    push    r8
    jmp     .advance

.pop_close_paren:
    pop     r15
    mov     r10, r15
    sub     r10, expression_input
    mov     qword [parenthesis_matching_table + r10 * 8], r8
    mov     qword [parenthesis_matching_table + r9 * 8], r15
    jmp     .advance

.match_done:
    ret

; ------------------------------------------------------------------------------
; Routine: identify_unary_operators
; Distinguishes unary '+' and '-' from binary addition/subtraction.
; ------------------------------------------------------------------------------
identify_unary_operators:
    xor     r9, r9
    mov     r8, expression_input

.unary_loop:
    cmp     r9, qword [expression_length]
    jge     .unary_done

    cmp     byte [r8], '-'
    je      .check_sign
    cmp     byte [r8], '+'
    je      .check_sign

.unary_advance:
    inc     r8
    inc     r9
    jmp     .unary_loop

.check_sign:
    test    r9, r9
    jz      .mark_unary

    mov     r10, r8
    dec     r10
    cmp     byte [r10], '('
    je      .mark_unary
    cmp     byte [r10], '+'
    je      .mark_unary
    cmp     byte [r10], '-'
    je      .mark_unary
    cmp     byte [r10], '*'
    je      .mark_unary
    cmp     byte [r10], '/'
    je      .mark_unary
    jmp     .unary_advance

.mark_unary:
    mov     byte [unary_minus_mask + r9], 1
    jmp     .unary_advance

.unary_done:
    ret

; ------------------------------------------------------------------------------
; Routine: evaluate_subexpression
; Recursively evaluates subexpression between [RBP+24] (start) and [RBP+16] (end).
; Returns evaluated integer in [current_answer].
; ------------------------------------------------------------------------------
evaluate_subexpression:
    enter   16, 0

    mov     r8, qword [rbp + 16]

    ; Check if enclosed entirely by outer parentheses
    cmp     byte [r8], ')'
    jne     .scan_low_precedence

    mov     r15, r8
    sub     r15, expression_input
    mov     r15, qword [parenthesis_matching_table + r15 * 8]
    cmp     r15, qword [rbp + 24]
    jne     .scan_low_precedence

    ; Strip outer parentheses and recurse
    mov     r15, qword [rbp + 24]
    inc     r15
    push    r15
    mov     r15, r8
    dec     r15
    push    r15
    call    evaluate_subexpression
    jmp     .eval_complete

.scan_low_precedence:
    ; Search right-to-left for lowest precedence operators (+ and -)
    cmp     byte [r8], '+'
    je      .handle_addition
    cmp     byte [r8], '-'
    je      .handle_subtraction
    cmp     byte [r8], ')'
    je      .skip_parenthesized_block

.next_low_char:
    cmp     r8, qword [rbp + 24]
    je      .scan_high_precedence
    dec     r8
    jmp     .scan_low_precedence

.skip_parenthesized_block:
    push    r15
    mov     r15, r8
    sub     r15, expression_input
    mov     r8, qword [parenthesis_matching_table + r15 * 8]
    pop     r15
    jmp     .next_low_char

.handle_addition:
    mov     r15, r8
    sub     r15, expression_input
    cmp     byte [unary_minus_mask + r15], 1
    je      .next_low_char       ; Skip unary plus

    push    qword [rbp + 24]
    mov     r15, r8
    dec     r15
    push    r15
    mov     qword [rbp - 8], r8
    call    evaluate_subexpression

    mov     r8, qword [rbp - 8]
    mov     r15, qword [current_answer]
    mov     qword [rbp - 16], r15

    mov     r15, r8
    inc     r15
    push    r15
    push    qword [rbp + 16]
    call    evaluate_subexpression

    mov     r15, qword [rbp - 16]
    add     qword [current_answer], r15
    jmp     .eval_complete

.handle_subtraction:
    mov     r15, r8
    sub     r15, expression_input
    cmp     byte [unary_minus_mask + r15], 1
    je      .next_low_char       ; Skip unary minus

    push    qword [rbp + 24]
    mov     r15, r8
    dec     r15
    push    r15
    mov     qword [rbp - 8], r8
    call    evaluate_subexpression

    mov     r8, qword [rbp - 8]
    mov     r15, qword [current_answer]
    mov     qword [rbp - 16], r15

    mov     r15, r8
    inc     r15
    push    r15
    push    qword [rbp + 16]
    call    evaluate_subexpression

    mov     r15, qword [rbp - 16]
    sub     r15, qword [current_answer]
    mov     qword [current_answer], r15
    jmp     .eval_complete

.scan_high_precedence:
    ; Search right-to-left for multiplication and division (* and /)
    mov     r8, qword [rbp + 16]

.high_loop:
    cmp     byte [r8], '*'
    je      .handle_multiplication
    cmp     byte [r8], '/'
    je      .handle_division
    cmp     byte [r8], ')'
    je      .skip_high_paren

.next_high_char:
    cmp     r8, qword [rbp + 24]
    je      .parse_terminal
    dec     r8
    jmp     .high_loop

.skip_high_paren:
    push    r15
    mov     r15, r8
    sub     r15, expression_input
    mov     r8, qword [parenthesis_matching_table + r15 * 8]
    pop     r15
    jmp     .next_high_char

.handle_multiplication:
    push    qword [rbp + 24]
    mov     r15, r8
    dec     r15
    push    r15
    mov     qword [rbp - 8], r8
    call    evaluate_subexpression

    mov     r8, qword [rbp - 8]
    mov     r15, qword [current_answer]
    mov     qword [rbp - 16], r15

    mov     r15, r8
    inc     r15
    push    r15
    push    qword [rbp + 16]
    call    evaluate_subexpression

    mov     rax, qword [rbp - 16]
    imul    rax, qword [current_answer]
    mov     qword [current_answer], rax
    jmp     .eval_complete

.handle_division:
    push    qword [rbp + 24]
    mov     r15, r8
    dec     r15
    push    r15
    mov     qword [rbp - 8], r8
    call    evaluate_subexpression

    mov     r8, qword [rbp - 8]
    mov     r15, qword [current_answer]
    mov     qword [rbp - 16], r15

    mov     r15, r8
    inc     r15
    push    r15
    push    qword [rbp + 16]
    call    evaluate_subexpression

    mov     rax, qword [rbp - 16]
    cqo
    idiv    qword [current_answer]
    mov     qword [current_answer], rax
    jmp     .eval_complete

.parse_terminal:
    ; Terminal literal parsing (number, unary negation, or previous answer 'ans')
    mov     r15, qword [rbp + 24]
    cmp     byte [r15], '-'
    je      .terminal_unary_minus
    cmp     byte [r15], '+'
    je      .terminal_unary_plus
    cmp     byte [r15], 'a'
    je      .terminal_recall_ans

    ; Parse integer constant string to 64-bit value
    xor     rax, rax
    xor     rbx, rbx
    mov     r8, qword [rbp + 24]

.accumulate_digits:
    mul     qword [decimal_base]
    mov     bl, byte [r8]
    sub     bl, '0'
    add     rax, rbx
    inc     r8
    cmp     r8, qword [rbp + 16]
    jbe     .accumulate_digits

    mov     qword [current_answer], rax
    jmp     .eval_complete

.terminal_unary_minus:
    mov     r15, qword [rbp + 24]
    inc     r15
    push    r15
    push    qword [rbp + 16]
    call    evaluate_subexpression
    neg     qword [current_answer]
    jmp     .eval_complete

.terminal_unary_plus:
    mov     r15, qword [rbp + 24]
    inc     r15
    push    r15
    push    qword [rbp + 16]
    call    evaluate_subexpression
    jmp     .eval_complete

.terminal_recall_ans:
    mov     rax, qword [previous_answer]
    mov     qword [current_answer], rax

.eval_complete:
    leave
    ret     16

; ------------------------------------------------------------------------------
; Main Loop
; ------------------------------------------------------------------------------
_start:
.repl_loop:
    call    read_expression_line
    cmp     byte [expression_input], '&'
    je      .exit_program

    ; Skip empty lines
    cmp     qword [expression_length], 0
    jle     .repl_loop

    ; Reset tables
    mov     rcx, 256
.clear_tables:
    mov     qword [parenthesis_matching_table + rcx * 8 - 8], 0
    mov     byte [unary_minus_mask + rcx - 1], 0
    loop    .clear_tables

    call    match_parentheses
    call    identify_unary_operators

    ; Evaluate full expression range
    push    expression_input
    mov     r15, expression_input
    add     r15, qword [expression_length]
    dec     r15
    push    r15
    call    evaluate_subexpression

    ; Output answer
    mov     rax, qword [current_answer]
    call    write_number
    call    print_newline
    mov     qword [previous_answer], rax
    jmp     .repl_loop

.exit_program:
    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall
