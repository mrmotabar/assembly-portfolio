; ==============================================================================
; File: file-io.asm
; Description: Low-level file input/output wrappers using Linux x86_64 system calls.
;              Provides routines for creating, opening, appending, reading,
;              writing, seeking, and deleting files on the filesystem.
; Architecture: x86_64 (Linux ELF64)
; ==============================================================================

%ifndef FILE_IO_ASM
%define FILE_IO_ASM

%include "system-constants.asm"
%include "console-io.asm"

section .data
    message_error_create   db "Error: Failed to create file.", ASCII_NEWLINE, 0
    message_error_close    db "Error: Failed to close file.", ASCII_NEWLINE, 0
    message_error_write    db "Error: Failed to write to file.", ASCII_NEWLINE, 0
    message_error_open     db "Error: Failed to open file.", ASCII_NEWLINE, 0
    message_error_append   db "Error: Failed to open file for appending.", ASCII_NEWLINE, 0
    message_error_delete   db "Error: Failed to delete file.", ASCII_NEWLINE, 0
    message_error_read     db "Error: Failed to read from file.", ASCII_NEWLINE, 0
    message_error_seek     db "Error: Failed to seek in file.", ASCII_NEWLINE, 0

    message_success_create db "Success: File created successfully.", ASCII_NEWLINE, 0
    message_success_close  db "Success: File closed successfully.", ASCII_NEWLINE, 0
    message_success_write  db "Success: Data written to file successfully.", ASCII_NEWLINE, 0
    message_success_open   db "Success: File opened successfully.", ASCII_NEWLINE, 0
    message_success_append db "Success: File opened for appending.", ASCII_NEWLINE, 0
    message_success_delete db "Success: File deleted successfully.", ASCII_NEWLINE, 0
    message_success_read   db "Success: File read successfully.", ASCII_NEWLINE, 0
    message_success_seek   db "Success: File seek completed successfully.", ASCII_NEWLINE, 0

section .text

; ------------------------------------------------------------------------------
; Routine: file_create (alias: createFile)
; Description: Creates a new file (or truncates an existing one).
; Inputs:
;   RDI - Pointer to null-terminated file path string
; Returns:
;   RAX - File descriptor on success, negative error code on failure
; ------------------------------------------------------------------------------
global file_create
global createFile

file_create:
createFile:
    push    rsi
    push    rdi

    mov     rax, SYS_CREAT
    mov     rsi, FILE_MODE_DEFAULT  ; Permissions: 0644 (rw-r--r--)
    syscall

    cmp     rax, 0
    jl      .create_error
    push    rax
    mov     rsi, message_success_create
    call    print_string
    pop     rax
    jmp     .create_done

.create_error:
    push    rax
    mov     rsi, message_error_create
    call    print_string
    pop     rax

.create_done:
    pop     rdi
    pop     rsi
    ret

; ------------------------------------------------------------------------------
; Routine: file_open (alias: openFile)
; Description: Opens an existing file for reading and writing (O_RDWR).
; Inputs:
;   RDI - Pointer to null-terminated file path string
; Returns:
;   RAX - File descriptor on success, negative error code on failure
; ------------------------------------------------------------------------------
global file_open
global openFile

file_open:
openFile:
    push    rsi
    push    rdi

    mov     rax, SYS_OPEN
    mov     rsi, O_RDWR
    syscall

    cmp     rax, 0
    jl      .open_error
    push    rax
    mov     rsi, message_success_open
    call    print_string
    pop     rax
    jmp     .open_done

.open_error:
    push    rax
    mov     rsi, message_error_open
    call    print_string
    pop     rax

.open_done:
    pop     rdi
    pop     rsi
    ret

; ------------------------------------------------------------------------------
; Routine: file_append (alias: appendFile)
; Description: Opens a file in append mode (O_RDWR | O_APPEND).
; Inputs:
;   RDI - Pointer to null-terminated file path string
; Returns:
;   RAX - File descriptor on success, negative error code on failure
; ------------------------------------------------------------------------------
global file_append
global appendFile

file_append:
appendFile:
    push    rsi
    push    rdi

    mov     rax, SYS_OPEN
    mov     rsi, O_RDWR | O_APPEND
    syscall

    cmp     rax, 0
    jl      .append_error
    push    rax
    mov     rsi, message_success_append
    call    print_string
    pop     rax
    jmp     .append_done

.append_error:
    push    rax
    mov     rsi, message_error_append
    call    print_string
    pop     rax

.append_done:
    pop     rdi
    pop     rsi
    ret

; ------------------------------------------------------------------------------
; Routine: file_write (alias: writeFile)
; Description: Writes a buffer of specified byte count to a file descriptor.
; Inputs:
;   RDI - Target file descriptor
;   RSI - Pointer to source buffer
;   RDX - Number of bytes to write
; Returns:
;   RAX - Number of bytes written, or negative error code
; ------------------------------------------------------------------------------
global file_write
global writeFile

file_write:
writeFile:
    mov     rax, SYS_WRITE
    syscall

    cmp     rax, 0
    jl      .write_error
    push    rax
    mov     rsi, message_success_write
    call    print_string
    pop     rax
    ret

.write_error:
    push    rax
    mov     rsi, message_error_write
    call    print_string
    pop     rax
    ret

; ------------------------------------------------------------------------------
; Routine: file_read (alias: readFile)
; Description: Reads up to RDX bytes from file descriptor RDI into buffer RSI.
; Inputs:
;   RDI - Source file descriptor
;   RSI - Pointer to destination buffer
;   RDX - Maximum bytes to read
; Returns:
;   RAX - Number of bytes read (0 on EOF), or negative error code
; ------------------------------------------------------------------------------
global file_read
global readFile

file_read:
readFile:
    mov     rax, SYS_READ
    syscall

    cmp     rax, 0
    jl      .read_error
    push    rax
    mov     rsi, message_success_read
    call    print_string
    pop     rax
    ret

.read_error:
    push    rax
    mov     rsi, message_error_read
    call    print_string
    pop     rax
    ret

; ------------------------------------------------------------------------------
; Routine: file_close (alias: closeFile)
; Description: Closes an open file descriptor.
; Inputs:
;   RDI - File descriptor to close
; Returns:
;   RAX - 0 on success, negative error code on failure
; ------------------------------------------------------------------------------
global file_close
global closeFile

file_close:
closeFile:
    mov     rax, SYS_CLOSE
    syscall

    cmp     rax, 0
    jl      .close_error
    push    rax
    mov     rsi, message_success_close
    call    print_string
    pop     rax
    ret

.close_error:
    push    rax
    mov     rsi, message_error_close
    call    print_string
    pop     rax
    ret

; ------------------------------------------------------------------------------
; Routine: file_delete (alias: deleteFile)
; Description: Unlinks (deletes) a file from the filesystem.
; Inputs:
;   RDI - Pointer to null-terminated file path string
; Returns:
;   RAX - 0 on success, negative error code on failure
; ------------------------------------------------------------------------------
global file_delete
global deleteFile

file_delete:
deleteFile:
    mov     rax, SYS_UNLINK
    syscall

    cmp     rax, 0
    jl      .delete_error
    push    rax
    mov     rsi, message_success_delete
    call    print_string
    pop     rax
    ret

.delete_error:
    push    rax
    mov     rsi, message_error_delete
    call    print_string
    pop     rax
    ret

; ------------------------------------------------------------------------------
; Routine: file_seek (alias: seekFile)
; Description: Repositions the read/write file offset.
; Inputs:
;   RDI - File descriptor
;   RSI - Signed byte offset
;   RDX - Whence directive (SEEK_SET = 0, SEEK_CUR = 1, SEEK_END = 2)
; Returns:
;   RAX - Resulting byte offset from the beginning of the file, or negative error
; ------------------------------------------------------------------------------
global file_seek
global seekFile

file_seek:
seekFile:
    mov     rax, SYS_LSEEK
    syscall

    cmp     rax, 0
    jl      .seek_error
    push    rax
    mov     rsi, message_success_seek
    call    print_string
    pop     rax
    ret

.seek_error:
    push    rax
    mov     rsi, message_error_seek
    call    print_string
    pop     rax
    ret

%endif ; FILE_IO_ASM
