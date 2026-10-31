; ==============================================================================
; File: system-constants.asm
; Description: Linux x86_64 system call numbers, file access modes, permission
;              flags, and standard ASCII constants for the assembly image processor.
; Architecture: x86_64 (Linux ELF64)
; ==============================================================================

%ifndef SYSTEM_CONSTANTS_ASM
%define SYSTEM_CONSTANTS_ASM

; ------------------------------------------------------------------------------
; Linux x86_64 System Call Numbers
; Reference: Linux kernel arch/x86/entry/syscalls/syscall_64.tbl
; ------------------------------------------------------------------------------
SYS_READ            equ     0       ; sys_read(fd, buf, count)
SYS_WRITE           equ     1       ; sys_write(fd, buf, count)
SYS_OPEN            equ     2       ; sys_open(filename, flags, mode)
SYS_CLOSE           equ     3       ; sys_close(fd)
SYS_LSEEK           equ     8       ; sys_lseek(fd, offset, whence)
SYS_MMAP            equ     9       ; sys_mmap(addr, len, prot, flags, fd, off)
SYS_MUNMAP          equ     11      ; sys_munmap(addr, len)
SYS_BRK             equ     12      ; sys_brk(brk)
SYS_EXIT            equ     60      ; sys_exit(error_code)
SYS_CHDIR           equ     80      ; sys_chdir(path) [0x50]
SYS_MKDIR           equ     83      ; sys_mkdir(pathname, mode) [0x53]
SYS_CREAT           equ     85      ; sys_creat(pathname, mode)
SYS_UNLINK          equ     87      ; sys_unlink(pathname)
SYS_GETDENTS64      equ     217     ; sys_getdents64(fd, dirp, count) [0xD9]

; Backward-compatibility aliases
sys_read            equ     SYS_READ
sys_write           equ     SYS_WRITE
sys_open            equ     SYS_OPEN
sys_close           equ     SYS_CLOSE
sys_lseek           equ     SYS_LSEEK
sys_mmap            equ     SYS_MMAP
sys_mumap           equ     SYS_MUNMAP
sys_brk             equ     SYS_BRK
sys_exit            equ     SYS_EXIT
sys_chdir           equ     SYS_CHDIR
sys_mkdir           equ     SYS_MKDIR
sys_create          equ     SYS_CREAT
sys_unlink          equ     SYS_UNLINK
sys_getdents64      equ     SYS_GETDENTS64

; ------------------------------------------------------------------------------
; Standard POSIX File Descriptors
; ------------------------------------------------------------------------------
STDIN_FILENO        equ     0       ; Standard input
STDOUT_FILENO       equ     1       ; Standard output
STDERR_FILENO       equ     2       ; Standard error (corrected from 3)

; Backward-compatibility aliases
stdin               equ     STDIN_FILENO
stdout              equ     STDOUT_FILENO
stderr              equ     STDERR_FILENO

; ------------------------------------------------------------------------------
; Memory Protection and Mapping Flags
; ------------------------------------------------------------------------------
PROT_READ           equ     0x1     ; Page can be read
PROT_WRITE          equ     0x2     ; Page can be written
MAP_PRIVATE         equ     0x02    ; Changes are private
MAP_ANONYMOUS       equ     0x20    ; Don't use a file

; ------------------------------------------------------------------------------
; File Access Modes (Octal values for open)
; ------------------------------------------------------------------------------
O_RDONLY            equ     0q000000 ; Open for reading only
O_WRONLY            equ     0q000001 ; Open for writing only
O_RDWR              equ     0q000002 ; Open for reading and writing
O_CREAT             equ     0q000100 ; Create file if it does not exist
O_APPEND            equ     0q002000 ; Append data to end of file

; ------------------------------------------------------------------------------
; File Creation Permission Modes (Octal values)
; ------------------------------------------------------------------------------
sys_IRWXU           equ     0q700   ; User (owner) has read, write, and execute
sys_IRUSR           equ     0q400   ; User read permission
sys_IWUSR           equ     0q200   ; User write permission
sys_IXUSR           equ     0q100   ; User execute permission
sys_IRGRP           equ     0q040   ; Group read permission
sys_IWGRP           equ     0q020   ; Group write permission
sys_IROTH           equ     0q004   ; Others read permission

; Standard file creation permissions (rw-r--r--)
FILE_MODE_DEFAULT   equ     0q644
; Standard directory creation permissions (rwxr-xr-x)
DIR_MODE_DEFAULT    equ     0q755

; ------------------------------------------------------------------------------
; lseek Seek Directives
; ------------------------------------------------------------------------------
SEEK_SET            equ     0       ; Seek relative to start of file
SEEK_CUR            equ     1       ; Seek relative to current file offset
SEEK_END            equ     2       ; Seek relative to end of file

; ------------------------------------------------------------------------------
; Directory Entry Types (linux_dirent64 d_type field at offset 18)
; ------------------------------------------------------------------------------
DT_UNKNOWN          equ     0
DT_FIFO             equ     1
DT_CHR              equ     2
DT_DIR              equ     4       ; Directory
DT_BLK              equ     6
DT_REG              equ     8       ; Regular file
DT_LNK              equ     10
DT_SOCK             equ     12

; ------------------------------------------------------------------------------
; Standard ASCII Characters
; ------------------------------------------------------------------------------
ASCII_TAB           equ     0x09
ASCII_NEWLINE       equ     0x0A    ; '\n'
ASCII_RETURN        equ     0x0D    ; '\r'
ASCII_SPACE         equ     0x20    ; ' '
ASCII_MINUS         equ     0x2D    ; '-'
ASCII_PLUS          equ     0x2B    ; '+'
ASCII_ZERO          equ     0x30    ; '0'
ASCII_NINE          equ     0x39    ; '9'

; Backward-compatibility aliases
NL                  equ     ASCII_NEWLINE
Space               equ     ASCII_SPACE

%endif ; SYSTEM_CONSTANTS_ASM
