# ==============================================================================
# Makefile: Assembly Implementations Portfolio (x86_64 NASM)
# ==============================================================================

NASM ?= nasm
LD   ?= ld
PYTHON ?= python3

SRC_DIR      := src
COMMON_DIR   := src/common
BUILD_DIR    := build
IMAGE_TARGET := $(BUILD_DIR)/image-processor
DOCKER_IMAGE := codeneomatrix/nasm

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Detect if we need Docker (macOS or non-x86_64 host)
USE_DOCKER ?= $(shell if [ "$(UNAME_S)" = "Linux" ] && [ "$(UNAME_M)" = "x86_64" ]; then echo 0; else echo 1; fi)

.PHONY: all build build-all run test benchmark clean help

all: build-all

# Build flagship image-processor
build: $(IMAGE_TARGET)

$(IMAGE_TARGET): $(SRC_DIR)/image-processing/image-processor.asm $(COMMON_DIR)/system-constants.asm $(COMMON_DIR)/console-io.asm
	@mkdir -p $(BUILD_DIR)
ifeq ($(USE_DOCKER),1)
	@echo "==> Building image-processor with Docker ($(DOCKER_IMAGE))..."
	docker run --rm -v "$(CURDIR):/app" -w /app $(DOCKER_IMAGE) sh -c \
		"mkdir -p $(BUILD_DIR) && \
		 nasm -f elf64 -I$(COMMON_DIR)/ $(SRC_DIR)/image-processing/image-processor.asm -o $(BUILD_DIR)/image-processor.o && \
		 ld $(BUILD_DIR)/image-processor.o -o $(IMAGE_TARGET)"
else
	@echo "==> Building image-processor natively..."
	$(NASM) -f elf64 -I$(COMMON_DIR)/ $(SRC_DIR)/image-processing/image-processor.asm -o $(BUILD_DIR)/image-processor.o
	$(LD) $(BUILD_DIR)/image-processor.o -o $(IMAGE_TARGET)
endif
	@echo "==> Binary built: $(IMAGE_TARGET)"

# Build all assembly implementations
build-all: build
	@mkdir -p $(BUILD_DIR)
ifeq ($(USE_DOCKER),1)
	@echo "==> Building all assembly implementations with Docker..."
	docker run --rm -v "$(CURDIR):/app" -w /app $(DOCKER_IMAGE) sh -c '\
		mkdir -p $(BUILD_DIR) && \
		for f in src/arithmetic/*.asm src/bit-manipulation/*.asm src/sorting-searching/*.asm; do \
		    base=$$(basename "$$f" .asm); \
		    nasm -f elf64 -Isrc/common/ "$$f" -o "$(BUILD_DIR)/$$base.o" && \
		    ld "$(BUILD_DIR)/$$base.o" -o "$(BUILD_DIR)/$$base" && \
		    echo "  [OK] Built $$base"; \
		done'
else
	@echo "==> Building all assembly implementations natively..."
	@for f in src/arithmetic/*.asm src/bit-manipulation/*.asm src/sorting-searching/*.asm; do \
	    base=$$(basename "$$f" .asm); \
	    $(NASM) -f elf64 -I$(COMMON_DIR)/ "$$f" -o "$(BUILD_DIR)/$$base.o" && \
	    $(LD) "$(BUILD_DIR)/$$base.o" -o "$(BUILD_DIR)/$$base" && \
	    echo "  [OK] Built $$base"; \
	done
endif
	@echo "==> All binaries built in $(BUILD_DIR)/"

run: build
ifeq ($(USE_DOCKER),1)
	@echo "==> Running image-processor in Docker..."
	docker run --rm -it -v "$(CURDIR):/app" -w /app $(DOCKER_IMAGE) ./$(IMAGE_TARGET)
else
	@echo "==> Running $(IMAGE_TARGET)..."
	./$(IMAGE_TARGET)
endif

test: build
	@echo "==> Running correctness test suite..."
	$(PYTHON) src/image-processing/tests/test_image_processor.py

benchmark: build
	@echo "==> Running performance benchmark suite..."
	$(PYTHON) src/image-processing/tests/benchmark_processor.py

clean:
	@echo "==> Cleaning build artifacts and test outputs..."
	rm -rf $(BUILD_DIR) *.o src/**/*.o test-output edited_photo src/image-processing/samples/edited_photo scratch .pytest_cache
	@echo "==> Clean complete."

help:
	@echo "Available Targets:"
	@echo "  make build      - Build the SIMD image processor"
	@echo "  make build-all  - Build all assembly implementations"
	@echo "  make run        - Run image processor interactively"
	@echo "  make test       - Run automated correctness test suite"
	@echo "  make benchmark  - Run runtime performance benchmark suite"
	@echo "  make clean      - Remove build artifacts and temporary files"
	@echo "  make help       - Display this help message"
