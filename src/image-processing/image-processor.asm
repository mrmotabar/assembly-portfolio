; ==============================================================================
; File: image-processor.asm
; Description: High-performance, SIMD-accelerated 24-bit BMP image brightness
;              processor written in x86_64 assembly for Linux.
;
; Core Features:
;   - Batch Directory Processing: Iterates through all files in a specified
;     directory using the Linux sys_getdents64 system call.
;   - Robust BMP Validation: Verifies magic 'BM' bytes and parses BITMAPINFOHEADER
;     and BITMAPCOREHEADER metadata, including dimensions and row byte padding.
;   - SSE2 SIMD Acceleration: Applies brightness delta (brighten or darken) across
;     16 color channels simultaneously using packed unsigned byte saturation
;     instructions (paddusb and psubusb), ensuring values clamp gracefully to
;     [0, 255] without overflow or underflow artifacts.
;   - Non-Destructive Output: Writes edited photos into a dedicated subfolder
;     ("edited_photo") without modifying the original source images.
;
; Architecture: x86_64 (Linux ELF64)
; Standard: Uniform Naming Standards (Core Rules)
; ==============================================================================

%include "system-constants.asm"
%include "console-io.asm"

; ------------------------------------------------------------------------------
; Constants & Buffer Capacities
; ------------------------------------------------------------------------------
ROW_BUFFER_CAPACITY         equ     65536   ; Max row size (supports up to ~21,800 px wide)
DIRECTORY_BUFFER_CAPACITY   equ     8192    ; Buffer for directory entries (sys_getdents64)
PATH_BUFFER_CAPACITY        equ     1024    ; Max path string length

; BMP Format Specific Constants
BMP_MAGIC_WORD              equ     0x4D42  ; 'BM' in little-endian (0x42, 0x4D)
BMP_OFFSET_PIXEL_ARRAY      equ     10      ; Offset to bfOffBits in BITMAPFILEHEADER
BMP_OFFSET_DIB_HEADER_SIZE  equ     14      ; Offset to biSize in BITMAPINFOHEADER

section .data
    ; Directory navigation names (null-terminated)
    output_directory_name       db  "edited_photo", 0
    current_directory_name      db  ".", 0
    parent_directory_name       db  "..", 0

    ; Console prompt messages
    prompt_directory            db  "Enter target directory path: ", 0
    prompt_brightness           db  "Enter brightness adjustment (-255 to 255): ", 0

    ; Status and error messages
    status_processing_file      db  "Processing: ", 0
    status_completed            db  "Finished processing all images.", ASCII_NEWLINE, 0
    error_directory_open        db  "Error: Unable to open target directory.", ASCII_NEWLINE, 0

    ; Operational state variables
    directory_file_descriptor   dq  0       ; FD for target directory
    source_file_descriptor      dq  0       ; FD for input BMP image
    destination_file_descriptor dq  0       ; FD for output BMP image
    current_filename_pointer    dq  0       ; Pointer to current filename string

    brightness_delta            db  0       ; Unsigned magnitude of adjustment (0-255)
    is_darkening                db  0       ; Boolean flag: 1 if subtract, 0 if add

section .bss
    ; Path and directory entry buffers
    target_directory_path       resb PATH_BUFFER_CAPACITY
    directory_entries_buffer    resb DIRECTORY_BUFFER_CAPACITY

    ; BMP Header and Dimension Metadata
    dib_header_size             resd 1       ; Header size (12 = CORE, 40+ = INFO/V4/V5)
    pixel_data_offset           resd 1       ; Byte offset from file start to pixel array
    image_width_pixels          resd 1       ; Width in pixels
    image_width_bytes           resd 1       ; Pixel bytes per row: width * 3
    row_padding_bytes           resd 1       ; BMP row padding bytes: (4 - (width*3 % 4)) % 4
    image_height_rows           resd 1       ; Height in rows (|biHeight|)

    ; Pixel Row Streaming Buffer (with 32-byte tail padding for safe SIMD overrun)
    pixel_row_buffer            resb ROW_BUFFER_CAPACITY + 32

section .text
    global _start

; ==============================================================================
; Program Entry Point (_start)
; ==============================================================================
_start:
    ; 1. Prompt and read target directory path
    mov     rsi, prompt_directory
    call    print_string
    call    read_directory_path

    ; 2. Prompt and read brightness adjustment delta
    mov     rsi, prompt_brightness
    call    print_string
    call    read_number             ; Signed integer returned in RAX

    ; 3. Normalize delta to [0, 255] and set is_darkening flag
    call    normalize_brightness_delta

    ; 4. Broadcast the brightness delta into SIMD register XMM2 using SSE2
    call    initialize_simd_delta_vector

    ; 5. Change current working directory to the target directory
    mov     rax, SYS_CHDIR
    mov     rdi, target_directory_path
    syscall
    test    rax, rax
    js      .handle_directory_error

    ; 6. Create the output subfolder "edited_photo" (mode 0755: rwxr-xr-x)
    mov     rax, SYS_MKDIR
    mov     rdi, output_directory_name
    mov     rsi, DIR_MODE_DEFAULT
    syscall

    ; 7. Open current directory (".") to obtain a directory file descriptor
    mov     rax, SYS_OPEN
    mov     rdi, current_directory_name
    mov     rsi, O_RDONLY
    syscall
    test    rax, rax
    js      .handle_directory_error
    mov     [directory_file_descriptor], rax

    ; 8. Traverse directory and process every regular BMP file
    call    traverse_and_process_directory

    ; 9. Close directory descriptor
    mov     rax, SYS_CLOSE
    mov     rdi, [directory_file_descriptor]
    syscall

    ; 10. Print completion message and exit cleanly with code 0
    mov     rsi, status_completed
    call    print_string

    mov     rax, SYS_EXIT
    xor     rdi, rdi                ; Exit code 0
    syscall

.handle_directory_error:
    mov     rsi, error_directory_open
    call    print_string
    mov     rax, SYS_EXIT
    mov     rdi, 1                  ; Exit code 1
    syscall

; ==============================================================================
; Routine: read_directory_path
; Description: Reads a string from standard input into target_directory_path
;              until a newline (0x0A) or carriage return (0x0D) is encountered.
; ==============================================================================
read_directory_path:
    push    rax
    push    rdi

    mov     rdi, target_directory_path

.read_char_loop:
    call    get_character
    test    al, al
    jz      .terminate_string
    cmp     al, ASCII_NEWLINE
    je      .terminate_string
    cmp     al, ASCII_RETURN
    je      .terminate_string

    mov     [rdi], al
    inc     rdi
    jmp     .read_char_loop

.terminate_string:
    mov     byte [rdi], 0           ; Null-terminate string
    pop     rdi
    pop     rax
    ret

; ==============================================================================
; Routine: normalize_brightness_delta
; Description: Parses signed integer in RAX. If negative, marks is_darkening = 1
;              and negates RAX. Clamps magnitude to 255 and stores in brightness_delta.
; Inputs:
;   RAX - Signed integer
; Outputs:
;   brightness_delta - Clamped magnitude (0..255)
;   is_darkening - 1 if negative, 0 if non-negative
; ==============================================================================
normalize_brightness_delta:
    cmp     rax, 0
    jge     .is_positive
    neg     rax
    mov     byte [is_darkening], 1
    jmp     .clamp_maximum

.is_positive:
    mov     byte [is_darkening], 0

.clamp_maximum:
    cmp     rax, 255
    jle     .store_delta
    mov     rax, 255

.store_delta:
    mov     [brightness_delta], al
    ret

; ==============================================================================
; Routine: initialize_simd_delta_vector
; Description: Replicates the 8-bit brightness_delta across all 16 byte lanes
;              of XMM2 using pure SSE2 instructions (universal on all x86_64 CPUs).
; Outputs:
;   XMM2 - 128-bit register containing 16 identical copies of brightness_delta
; ==============================================================================
initialize_simd_delta_vector:
    movzx   eax, byte [brightness_delta]
    movd    xmm2, eax               ; Low 32 bits = 0x000000XX
    punpcklbw xmm2, xmm2            ; Low 16 bits = 0xXXXX
    pshuflw xmm2, xmm2, 0           ; Low 64 bits = 0xXXXXXXXXXXXXXXXX
    pshufd  xmm2, xmm2, 0           ; All 128 bits = 16 copies of XX
    ret

; ==============================================================================
; Routine: traverse_and_process_directory
; Description: Streams directory entries using sys_getdents64. For each entry,
;              checks if d_type == DT_REG (8). If so, invokes process_single_image.
;
; Linux dirent64 structure layout:
;   Offset  0 (8 bytes): ino64_t        d_ino
;   Offset  8 (8 bytes): off64_t        d_off
;   Offset 16 (2 bytes): unsigned short d_reclen  (Record length to next entry)
;   Offset 18 (1 byte) : unsigned char  d_type    (File type: DT_REG = 8)
;   Offset 19 (var)    : char           d_name[]  (Null-terminated filename)
; ==============================================================================
traverse_and_process_directory:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

.read_entries_chunk:
    mov     rax, SYS_GETDENTS64
    mov     rdi, [directory_file_descriptor]
    mov     rsi, directory_entries_buffer
    mov     rdx, DIRECTORY_BUFFER_CAPACITY
    syscall

    test    rax, rax
    jle     .traversal_complete     ; Exit when no more entries (<= 0)

    mov     r12, directory_entries_buffer   ; R12 = buffer start
    lea     r13, [r12 + rax]                ; R13 = buffer end

.process_current_entry:
    cmp     r12, r13
    jge     .read_entries_chunk     ; Buffer exhausted, fetch next chunk

    movzx   r14, word [r12 + 16]    ; R14 = d_reclen (length of this record)
    movzx   r15, byte [r12 + 18]    ; R15 = d_type

    ; Check if this entry is a regular file (DT_REG = 8)
    cmp     r15, DT_REG
    jne     .advance_to_next_entry

    ; R12 + 19 points to the null-terminated filename string
    lea     rax, [r12 + 19]
    mov     [current_filename_pointer], rax

    ; Process this file if it is a valid BMP
    call    process_single_image

.advance_to_next_entry:
    add     r12, r14                ; Advance pointer by d_reclen
    jmp     .process_current_entry

.traversal_complete:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==============================================================================
; Routine: process_single_image
; Description: Opens the file referenced by [current_filename_pointer], verifies
;              its BMP signature, parses dimensions, creates the output copy in
;              "edited_photo", and streams rows through SIMD brightness adjustment.
; ==============================================================================
process_single_image:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; 1. Open source file for reading only (O_RDONLY)
    mov     rax, SYS_OPEN
    mov     rdi, [current_filename_pointer]
    mov     rsi, O_RDONLY
    syscall
    test    rax, rax
    js      .exit_processing
    mov     [source_file_descriptor], rax

    ; 2. Read first 2 bytes to check BMP magic identifier 'BM' (0x42, 0x4D)
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, pixel_row_buffer
    mov     rdx, 2
    syscall
    cmp     rax, 2
    jne     .close_source_and_exit

    cmp     word [pixel_row_buffer], BMP_MAGIC_WORD
    jne     .close_source_and_exit

    ; 3. Read pixel data offset (offset 10 in file, 4 bytes)
    mov     rax, SYS_LSEEK
    mov     rdi, [source_file_descriptor]
    mov     rsi, BMP_OFFSET_PIXEL_ARRAY
    mov     rdx, SEEK_SET
    syscall

    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, pixel_data_offset
    mov     rdx, 4
    syscall

    ; 4. Read DIB header size (offset 14 in file, 4 bytes)
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, dib_header_size
    mov     rdx, 4
    syscall

    ; DIB header sizes: 12 = BITMAPCOREHEADER (16-bit width/height)
    ;                   40+ = BITMAPINFOHEADER (32-bit width/height)
    mov     r14, 4                  ; Default: read 4 bytes for 32-bit dimensions
    cmp     dword [dib_header_size], 12
    jne     .read_dimensions
    mov     r14, 2                  ; 16-bit dimensions for Core Header

.read_dimensions:
    ; Clear dimension buffers
    mov     dword [image_width_pixels], 0
    mov     dword [image_height_rows], 0

    ; Read image width
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, image_width_pixels
    mov     rdx, r14
    syscall

    ; Read image height
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, image_height_rows
    mov     rdx, r14
    syscall

    ; Ensure image height is positive (support top-down BMP with negative height)
    mov     eax, dword [image_height_rows]
    test    eax, eax
    jns     .height_normalized
    neg     eax
    mov     dword [image_height_rows], eax

.height_normalized:
    ; Calculate row pixel bytes: image_width_pixels * 3 (24bpp RGB)
    mov     eax, dword [image_width_pixels]
    imul    rax, 3
    mov     dword [image_width_bytes], eax

    ; Calculate row padding bytes: (4 - (image_width_bytes % 4)) % 4
    xor     rdx, rdx
    mov     rcx, 4
    div     rcx                     ; RDX = remainder (image_width_bytes % 4)
    test    rdx, rdx
    jz      .zero_padding
    mov     rax, 4
    sub     rax, rdx
    mov     dword [row_padding_bytes], eax
    jmp     .create_destination_file

.zero_padding:
    mov     dword [row_padding_bytes], 0

.create_destination_file:
    ; Change directory to "edited_photo"
    mov     rax, SYS_CHDIR
    mov     rdi, output_directory_name
    syscall

    ; Create destination file with standard permissions (0644)
    mov     rax, SYS_CREAT
    mov     rdi, [current_filename_pointer]
    mov     rsi, FILE_MODE_DEFAULT
    syscall
    test    rax, rax
    js      .return_to_parent_and_close
    mov     [destination_file_descriptor], rax

    ; 5. Copy file headers (everything before pixel array) verbatim
    ; Rewind source file to offset 0
    mov     rax, SYS_LSEEK
    mov     rdi, [source_file_descriptor]
    xor     rsi, rsi
    mov     rdx, SEEK_SET
    syscall

    ; Copy pixel_data_offset bytes from source to destination
    mov     r15d, dword [pixel_data_offset]

.copy_header_chunks:
    test    r15d, r15d
    jz      .begin_pixel_processing

    mov     edx, r15d
    cmp     edx, ROW_BUFFER_CAPACITY
    jbe     .read_header_chunk
    mov     edx, ROW_BUFFER_CAPACITY

.read_header_chunk:
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, pixel_row_buffer
    ; EDX already set
    syscall
    test    rax, rax
    jle     .finish_file_editing

    mov     r14, rax                ; Bytes actually read
    mov     rax, SYS_WRITE
    mov     rdi, [destination_file_descriptor]
    mov     rsi, pixel_row_buffer
    mov     rdx, r14
    syscall

    sub     r15d, r14d
    jmp     .copy_header_chunks

.begin_pixel_processing:
    ; 6. Iterate through all image rows and adjust brightness via SIMD
    xor     r13d, r13d              ; R13D = current row counter (0 .. height-1)

.process_rows_loop:
    cmp     r13d, dword [image_height_rows]
    jge     .copy_trailing_data

    ; Read current row pixel data (image_width_bytes)
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, pixel_row_buffer
    mov     edx, dword [image_width_bytes]
    syscall
    test    rax, rax
    jle     .finish_file_editing

    ; Process pixels in pixel_row_buffer using vector saturation instructions
    mov     rdi, pixel_row_buffer
    mov     ecx, dword [image_width_bytes]
    call    apply_simd_row_brightness

    ; Write adjusted pixel data to destination file
    mov     rax, SYS_WRITE
    mov     rdi, [destination_file_descriptor]
    mov     rsi, pixel_row_buffer
    mov     edx, dword [image_width_bytes]
    syscall

    ; Check and copy row alignment padding bytes (if any)
    mov     edx, dword [row_padding_bytes]
    test    edx, edx
    jz      .advance_row_counter

    ; Read padding bytes unmodified
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, pixel_row_buffer
    ; EDX already contains row_padding_bytes
    syscall

    ; Write padding bytes to destination file
    mov     rax, SYS_WRITE
    mov     rdi, [destination_file_descriptor]
    mov     rsi, pixel_row_buffer
    mov     edx, dword [row_padding_bytes]
    syscall

.advance_row_counter:
    inc     r13d
    jmp     .process_rows_loop

.copy_trailing_data:
    ; 7. Copy any trailing metadata (color profiles, EOF padding, etc.)
    mov     rax, SYS_READ
    mov     rdi, [source_file_descriptor]
    mov     rsi, pixel_row_buffer
    mov     rdx, ROW_BUFFER_CAPACITY
    syscall
    test    rax, rax
    jle     .finish_file_editing

    mov     r14, rax
    mov     rax, SYS_WRITE
    mov     rdi, [destination_file_descriptor]
    mov     rsi, pixel_row_buffer
    mov     rdx, r14
    syscall
    jmp     .copy_trailing_data

.finish_file_editing:
    ; Close destination file descriptor
    mov     rax, SYS_CLOSE
    mov     rdi, [destination_file_descriptor]
    syscall

.return_to_parent_and_close:
    ; Change directory back to parent ("..")
    mov     rax, SYS_CHDIR
    mov     rdi, parent_directory_name
    syscall

.close_source_and_exit:
    mov     rax, SYS_CLOSE
    mov     rdi, [source_file_descriptor]
    syscall

.exit_processing:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==============================================================================
; Routine: apply_simd_row_brightness
; Description: Accelerates pixel brightness manipulation across 16 color channels
;              simultaneously using SSE2 saturated arithmetic.
;
; Saturated Arithmetic Behavior:
;   - Brightening (paddusb): If pixel + delta > 255, clamps to 255 (no wrap to 0).
;   - Darkening   (psubusb): If pixel - delta < 0,   clamps to 0   (no wrap to 255).
;
; Inputs:
;   RDI  - Memory pointer to row pixel buffer
;   RCX  - Row pixel byte count (image_width_bytes)
;   XMM2 - 16 broadcasted copies of brightness_delta
; Preserves: All non-volatile registers
; ==============================================================================
apply_simd_row_brightness:
    test    rcx, rcx
    jle     .simd_done

    ; Branch once outside the inner pixel loop based on is_darkening
    cmp     byte [is_darkening], 1
    je      .darken_loop

    ; --------------------------------------------------------------------------
    ; Brightening Loop: paddusb
    ; --------------------------------------------------------------------------
.brighten_loop:
    cmp     rcx, 16
    jb      .brighten_tail

    movdqu  xmm0, [rdi]
    paddusb xmm0, xmm2
    movdqu  [rdi], xmm0

    add     rdi, 16
    sub     rcx, 16
    jmp     .brighten_loop

.brighten_tail:
    test    rcx, rcx
    jz      .simd_done

    ; Process the final 1-15 bytes using the padded tail buffer safely
    movdqu  xmm0, [rdi]
    paddusb xmm0, xmm2
    movdqu  [rdi], xmm0
    jmp     .simd_done

    ; --------------------------------------------------------------------------
    ; Darkening Loop: psubusb
    ; --------------------------------------------------------------------------
.darken_loop:
    cmp     rcx, 16
    jb      .darken_tail

    movdqu  xmm0, [rdi]
    psubusb xmm0, xmm2
    movdqu  [rdi], xmm0

    add     rdi, 16
    sub     rcx, 16
    jmp     .darken_loop

.darken_tail:
    test    rcx, rcx
    jz      .simd_done

    ; Process the final 1-15 bytes using the padded tail buffer safely
    movdqu  xmm0, [rdi]
    psubusb xmm0, xmm2
    movdqu  [rdi], xmm0

.simd_done:
    ret
