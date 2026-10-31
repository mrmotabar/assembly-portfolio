# Complete Guide: Building & Running NASM Assembly on macOS

This comprehensive manual explains how to write, assemble, link, and run **x86_64 NASM Assembly** on **macOS** (both Apple Silicon M1/M2/M3/M4 and Intel Macs).

---

## 1. Why Linux x86_64 Assembly Doesn't Run Natively on macOS

Most computer science courses, textbooks, and systems programming assignments target **Linux x86_64 (ELF64)**. However, attempting to assemble or run Linux assembly directly on macOS presents three fundamental architectural differences:

| Difference | Linux x86_64 | macOS (Darwin) |
| :--- | :--- | :--- |
| **Object File Format** | **ELF64** (`-f elf64`) | **Mach-O 64** (`-f macho64`) |
| **CPU Architecture** | Typically Intel/AMD x86_64 | Apple Silicon **ARM64** (or legacy Intel x86_64) |
| **Syscall ABI & Numbers** | Linux Table (e.g., `sys_write = 1`, `sys_exit = 60`) | BSD Table + Class offset (`0x2000004`, `0x2000001`) |
| **Symbol Naming** | Unprefixed (e.g., `_start`, `main`) | Leading underscore required (e.g., `_main`) |
| **Stack Alignment** | Standard System V ABI | Strictly requires 16-byte alignment before `call` |

Because this repository uses direct Linux kernel syscalls (`sys_getdents64`, `sys_open`, `sys_read`, `sys_write`), the recommended workflow on macOS is to build and run the code inside an **x86_64 Linux container or emulator**.

---

## 2. Method 1: Docker (Recommended — Automated in Makefile)

Docker is the cleanest, easiest, and most reliable method because macOS handles x86_64 virtualization seamlessly using Apple's Hypervisor framework and Rosetta 2.

### Step 1: Install Docker Desktop

Download and install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) or install via Homebrew:

```bash
brew install --cask docker
```

*(On Apple Silicon Macs, ensure **"Use Rosetta for x86/amd64 emulation on Apple Silicon"** is enabled in Docker Settings $\rightarrow$ General $\rightarrow$ Features in development).*

### Step 2: Use the Project Makefile

Our repository's `Makefile` **automatically detects macOS** and executes all compilation and testing commands inside a lightweight Linux container transparently:

```bash
# 1. Build the binary (creates build/image-processor)
make build

# 2. Run the processor interactively
make run

# 3. Run the automated 10-point test suite
make test

# 4. Run runtime performance benchmarks
make benchmark
```

### Manual Docker Command (Without Make)

If you ever want to compile and link arbitrary Linux NASM code manually on macOS:

```bash
# Compile and link using Docker
docker run --rm -v "$(pwd):/app" -w /app codeneomatrix/nasm sh -c \
    "nasm -f elf64 -Isrc/common/ src/image-processing/image-processor.asm -o build/image-processor.o && \
     ld build/image-processor.o -o build/image-processor"

# Run the resulting Linux ELF binary
docker run --rm -it -v "$(pwd):/app" -w /app codeneomatrix/nasm ./build/image-processor
```

---

## 3. Method 2: Homebrew + QEMU User Emulation (No Docker)

If you prefer a lightweight command-line setup without running the Docker daemon:

### Step 1: Install NASM, LLVM, and QEMU

```bash
brew install nasm llvm qemu
```

- `nasm`: The Netwide Assembler (compiles `.asm` to `.o`).
- `llvm`: Provides `ld.lld`, a cross-platform linker that outputs Linux ELF binaries on macOS.
- `qemu`: Provides `qemu-x86_64`, which executes Linux x86_64 binaries directly on macOS.

### Step 2: Assemble with NASM

```bash
nasm -f elf64 -Isrc/common/ src/image-processing/image-processor.asm -o build/image-processor.o
```

### Step 3: Link with `ld.lld`

```bash
# Locate LLVM lld
LLD="$(brew --prefix llvm)/bin/ld.lld"

# Link into a Linux ELF64 executable
$LLD -m elf_x86_64 build/image-processor.o -o build/image-processor
```

### Step 4: Run with `qemu-x86_64`

```bash
qemu-x86_64 ./build/image-processor
```

---

## 4. Method 3: Native macOS NASM Programming (Mach-O)

If you want to write assembly that targets macOS natively instead of Linux, follow these rules:

### Key Differences in Native macOS Assembly:

1. **Output format**: Use `-f macho64`.
2. **Entry point**: Use `_main` instead of `_start` if linking with clang, or `_start` if linking directly with ld.
3. **Leading Underscores**: All external and exported symbols must begin with an underscore `_` (e.g., `_print_string`, `_exit`).
4. **Syscall Numbers**: macOS uses BSD system calls with high byte mask `0x2000000`:
   - `exit`: `0x2000001` (Linux: `60`)
   - `read`: `0x2000003` (Linux: `0`)
   - `write`: `0x2000004` (Linux: `1`)
   - `open`: `0x2000005` (Linux: `2`)
   - `close`: `0x2000006` (Linux: `3`)
5. **16-Byte Stack Alignment**: macOS requires `RSP` to be a multiple of 16 bytes before calling any external C library function.

### Native macOS Hello World Example (`hello.asm`):

```nasm
section .data
    message     db  "Hello from native macOS assembly!", 0xA
    message_len equ $ - message

section .text
    global _start

_start:
    ; sys_write(stdout, message, message_len)
    mov     rax, 0x2000004          ; macOS sys_write
    mov     rdi, 1                  ; stdout
    mov     rsi, message            ; buffer
    mov     rdx, message_len        ; length
    syscall

    ; sys_exit(0)
    mov     rax, 0x2000001          ; macOS sys_exit
    xor     rdi, rdi                ; status 0
    syscall
```

### Assemble and Link natively on macOS:

```bash
# 1. Assemble to Mach-O 64-bit
nasm -f macho64 hello.asm -o hello.o

# 2. Link natively (on Intel Mac or via Rosetta on Apple Silicon)
ld -macosx_version_min 10.13 -lSystem -static -o hello hello.o
./hello
```

---

## 5. Troubleshooting Common macOS Errors

### Error: `cannot execute binary file: Exec format error`
- **Cause**: You tried to execute a Linux ELF binary (`-f elf64`) natively on macOS.
- **Solution**: Execute the binary through Docker (`make run`) or via QEMU (`qemu-x86_64 ./binary`).

### Error: `Bad CPU type in executable`
- **Cause**: An x86_64 binary is being executed on Apple Silicon without Rosetta 2 installed.
- **Solution**: Install Rosetta 2 by running:
  ```bash
  softwareupdate --install-rosetta
  ```

### Error: `Undefined symbols for architecture x86_64: "_main"`
- **Cause**: You assembled with `-f macho64` and linked with `clang` / `gcc`, but declared `_start` instead of `_main`.
- **Solution**: Change `global _start` to `global _main` and `_start:` to `_main:` in your assembly source.

### Error: `failed to connect to the docker API`
- **Cause**: Docker Desktop is not running.
- **Solution**: Open Docker Desktop from Applications or run:
  ```bash
  open -a Docker
  ```

---

## 6. Summary Cheat Sheet

| Task | Command |
| :--- | :--- |
| **Build Project on macOS** | `make build` *(runs automatically via Docker)* |
| **Run Image Processor** | `make run` |
| **Run Correctness Tests** | `make test` |
| **Run Benchmarks** | `make benchmark` |
| **Manual Assemble (Linux)** | `nasm -f elf64 -Isrc/common/ src/image-processing/image-processor.asm -o build/image-processor.o` |
| **Manual Assemble (macOS)** | `nasm -f macho64 src/image-processing/image-processor.asm -o build/image-processor.o` |
