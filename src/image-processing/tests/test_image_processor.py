#!/usr/bin/env python3
"""
Test Suite: Assembly Image Processor (x86_64 NASM)
Description: Automated correctness test suite verifying 24-bit BMP image
             processing, SSE2 saturation arithmetic, row padding handling,
             directory traversal, and non-BMP file filtering.
Standard: Uniform Naming Standards (Core Rules)
"""

import os
import sys
import shutil
import struct
import platform
import subprocess
from typing import Tuple, List

# Paths
def _find_project_root():
    curr = os.path.dirname(os.path.abspath(__file__))
    while curr and curr != "/":
        if os.path.isfile(os.path.join(curr, "Makefile")):
            return curr
        curr = os.path.dirname(curr)
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))

PROJECT_ROOT = _find_project_root()
BUILD_DIR = os.path.join(PROJECT_ROOT, "build")
TARGET_BINARY = os.path.join(BUILD_DIR, "image-processor")
TEST_OUTPUT_DIR = os.path.join(PROJECT_ROOT, "test-output")
DOCKER_IMAGE = "codeneomatrix/nasm"


def create_24bpp_bmp(file_path: str, width: int, height: int, pixel_generator, is_top_down: bool = False) -> None:
    """Creates a valid 24-bit uncompressed BMP file with proper row padding."""
    row_bytes = width * 3
    padding_bytes = (4 - (row_bytes % 4)) % 4
    image_data_size = (row_bytes + padding_bytes) * abs(height)
    file_size = 54 + image_data_size
    stored_height = -abs(height) if is_top_down else abs(height)

    # BITMAPFILEHEADER (14 bytes)
    # Type (2B 'BM'), Size (4B), Reserved1 (2B), Reserved2 (2B), OffBits (4B = 54)
    file_header = struct.pack("<2sIHHI", b"BM", file_size, 0, 0, 54)

    # BITMAPINFOHEADER (40 bytes)
    # Size (4B = 40), Width (4B), Height (4B signed), Planes (2B = 1), BitCount (2B = 24),
    # Compression (4B = 0), SizeImage (4B), XPelsPerMeter (4B), YPelsPerMeter (4B),
    # ClrUsed (4B), ClrImportant (4B)
    dib_header = struct.pack(
        "<IIiHHIIIIII",
        40, width, stored_height, 1, 24, 0, image_data_size, 2835, 2835, 0, 0
    )

    with open(file_path, "wb") as f:
        f.write(file_header)
        f.write(dib_header)
        for y in range(abs(height)):
            row_data = bytearray()
            for x in range(width):
                blue, green, red = pixel_generator(x, y, width, abs(height))
                row_data.extend([blue & 0xFF, green & 0xFF, red & 0xFF])
            row_data.extend(b"\x00" * padding_bytes)
            f.write(row_data)


def run_assembly_processor(directory_path: str, delta: int) -> Tuple[int, str]:
    """Executes the image-processor binary with directory and delta input."""
    # Ensure binary exists
    if not os.path.isfile(TARGET_BINARY):
        subprocess.run(["make", "build"], cwd=PROJECT_ROOT, check=True)

    rel_dir = os.path.relpath(directory_path, PROJECT_ROOT)
    system_name = platform.system()
    machine_arch = platform.machine()

    if system_name == "Linux" and machine_arch == "x86_64":
        input_payload = f"{directory_path}\n{delta}\n"
        proc = subprocess.run(
            [TARGET_BINARY],
            input=input_payload,
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )
    else:
        # Run inside Docker container for macOS / non-x86_64 hosts
        input_payload = f"{rel_dir}\n{delta}\n"
        docker_cmd = [
            "docker", "run", "--rm", "-i",
            "-v", f"{PROJECT_ROOT}:/app",
            "-w", "/app",
            DOCKER_IMAGE,
            f"./{os.path.relpath(TARGET_BINARY, PROJECT_ROOT)}"
        ]
        proc = subprocess.run(
            docker_cmd,
            input=input_payload,
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )

    return proc.returncode, proc.stdout + proc.stderr


def verify_processed_image(original_path: str, edited_path: str, delta: int) -> Tuple[bool, str]:
    """Compares the edited BMP pixel-by-pixel with the mathematical saturation model."""
    if not os.path.exists(edited_path):
        return False, f"Output file does not exist: {edited_path}"

    with open(original_path, "rb") as f_orig, open(edited_path, "rb") as f_edit:
        orig_data = f_orig.read()
        edit_data = f_edit.read()

    if len(orig_data) != len(edit_data):
        return False, f"File size mismatch: {len(orig_data)} vs {len(edit_data)} bytes"

    # Extract pixel offset from original header
    pixel_offset = struct.unpack("<I", orig_data[10:14])[0]
    dib_size = struct.unpack("<I", orig_data[14:18])[0]
    width = struct.unpack("<I", orig_data[18:22])[0]
    height = abs(struct.unpack("<i", orig_data[22:26])[0])

    # Check headers match exactly
    if orig_data[:pixel_offset] != edit_data[:pixel_offset]:
        return False, "File header mismatch between original and edited image."

    row_bytes = width * 3
    padding_bytes = (4 - (row_bytes % 4)) % 4
    row_stride = row_bytes + padding_bytes

    # Clamp delta
    effective_delta = max(-255, min(255, delta))

    for y in range(height):
        row_start = pixel_offset + y * row_stride
        # Verify pixels
        for byte_idx in range(row_bytes):
            idx = row_start + byte_idx
            orig_val = orig_data[idx]
            edit_val = edit_data[idx]
            expected_val = min(255, max(0, orig_val + effective_delta))
            if edit_val != expected_val:
                return False, (
                    f"Pixel mismatch at row {y}, byte {byte_idx}: "
                    f"orig={orig_val}, delta={effective_delta}, "
                    f"expected={expected_val}, got={edit_val}"
                )
        # Verify padding bytes preserved
        for pad_idx in range(padding_bytes):
            idx = row_start + row_bytes + pad_idx
            if edit_data[idx] != orig_data[idx]:
                return False, f"Padding byte corrupted at row {y}, pad {pad_idx}"

    return True, "Valid"


class TestSuite:
    def __init__(self):
        self.total_tests = 0
        self.passed_tests = 0
        self.failed_tests = 0

    def record_result(self, test_name: str, passed: bool, message: str = ""):
        self.total_tests += 1
        if passed:
            self.passed_tests += 1
            print(f"  \033[32m[PASS]\033[0m {test_name}")
        else:
            self.failed_tests += 1
            print(f"  \033[31m[FAIL]\033[0m {test_name} - {message}")

    def run_all(self):
        print("\n=======================================================")
        print("  Running Assembly Image Processor Test Suite")
        print("=======================================================\n")

        self.test_basic_brightening()
        self.test_basic_darkening()
        self.test_saturation_clamping_upper()
        self.test_saturation_clamping_lower()
        self.test_row_padding_variations()
        self.test_zero_delta_identity()
        self.test_top_down_bmp()
        self.test_batch_directory_traversal()
        self.test_non_bmp_file_handling()
        self.test_large_image()

        print("\n-------------------------------------------------------")
        print(f"Test Summary: {self.passed_tests}/{self.total_tests} passed, {self.failed_tests} failed.")
        print("=======================================================\n")
        return self.failed_tests == 0

    def setup_case_dir(self, case_name: str) -> str:
        case_dir = os.path.join(TEST_OUTPUT_DIR, case_name)
        if os.path.exists(case_dir):
            shutil.rmtree(case_dir)
        os.makedirs(case_dir, exist_ok=True)
        return case_dir

    def test_basic_brightening(self):
        test_dir = self.setup_case_dir("case_brighten")
        img_path = os.path.join(test_dir, "sample.bmp")
        create_24bpp_bmp(img_path, 8, 8, lambda x, y, w, h: (50, 100, 150))

        delta = 35
        run_assembly_processor(test_dir, delta)
        edited_path = os.path.join(test_dir, "edited_photo", "sample.bmp")
        ok, msg = verify_processed_image(img_path, edited_path, delta)
        self.record_result("Positive Brightness Adjustment (+35)", ok, msg)

    def test_basic_darkening(self):
        test_dir = self.setup_case_dir("case_darken")
        img_path = os.path.join(test_dir, "sample.bmp")
        create_24bpp_bmp(img_path, 8, 8, lambda x, y, w, h: (100, 150, 200))

        delta = -45
        run_assembly_processor(test_dir, delta)
        edited_path = os.path.join(test_dir, "edited_photo", "sample.bmp")
        ok, msg = verify_processed_image(img_path, edited_path, delta)
        self.record_result("Negative Brightness Adjustment (-45)", ok, msg)

    def test_saturation_clamping_upper(self):
        test_dir = self.setup_case_dir("case_clamp_upper")
        img_path = os.path.join(test_dir, "sample.bmp")
        create_24bpp_bmp(img_path, 16, 16, lambda x, y, w, h: (200, 220, 240))

        delta = 100
        run_assembly_processor(test_dir, delta)
        edited_path = os.path.join(test_dir, "edited_photo", "sample.bmp")
        ok, msg = verify_processed_image(img_path, edited_path, delta)
        self.record_result("Upper Saturation Clamping at 255 (paddusb)", ok, msg)

    def test_saturation_clamping_lower(self):
        test_dir = self.setup_case_dir("case_clamp_lower")
        img_path = os.path.join(test_dir, "sample.bmp")
        create_24bpp_bmp(img_path, 16, 16, lambda x, y, w, h: (20, 40, 60))

        delta = -100
        run_assembly_processor(test_dir, delta)
        edited_path = os.path.join(test_dir, "edited_photo", "sample.bmp")
        ok, msg = verify_processed_image(img_path, edited_path, delta)
        self.record_result("Lower Saturation Clamping at 0 (psubusb)", ok, msg)

    def test_row_padding_variations(self):
        test_dir = self.setup_case_dir("case_paddings")
        # Test widths with 0, 1, 2, 3 bytes padding
        # Width 4 -> row bytes 12 -> 0 pad
        # Width 5 -> row bytes 15 -> 1 pad
        # Width 6 -> row bytes 18 -> 2 pad
        # Width 7 -> row bytes 21 -> 3 pad
        widths = [4, 5, 6, 7]
        all_ok = True
        err_msg = ""
        delta = 25

        for w in widths:
            img_path = os.path.join(test_dir, f"width_{w}.bmp")
            create_24bpp_bmp(img_path, w, 5, lambda x, y, _w, h: (x * 30, y * 40, (x + y) * 20))

        run_assembly_processor(test_dir, delta)

        for w in widths:
            orig = os.path.join(test_dir, f"width_{w}.bmp")
            edit = os.path.join(test_dir, "edited_photo", f"width_{w}.bmp")
            ok, msg = verify_processed_image(orig, edit, delta)
            if not ok:
                all_ok = False
                err_msg = f"Failed on width {w}: {msg}"
                break

        self.record_result("BMP Row Byte Padding Variations (0, 1, 2, 3 bytes)", all_ok, err_msg)

    def test_zero_delta_identity(self):
        test_dir = self.setup_case_dir("case_identity")
        img_path = os.path.join(test_dir, "identity.bmp")
        create_24bpp_bmp(img_path, 10, 10, lambda x, y, w, h: (x * 20, y * 20, 128))

        delta = 0
        run_assembly_processor(test_dir, delta)
        edited_path = os.path.join(test_dir, "edited_photo", "identity.bmp")
        ok, msg = verify_processed_image(img_path, edited_path, delta)
        self.record_result("Zero Delta Identity Transformation (Delta = 0)", ok, msg)

    def test_top_down_bmp(self):
        test_dir = self.setup_case_dir("case_top_down")
        img_path = os.path.join(test_dir, "top_down.bmp")
        create_24bpp_bmp(img_path, 8, 8, lambda x, y, w, h: (80, 120, 160), is_top_down=True)

        delta = 30
        run_assembly_processor(test_dir, delta)
        edited_path = os.path.join(test_dir, "edited_photo", "top_down.bmp")
        ok, msg = verify_processed_image(img_path, edited_path, delta)
        self.record_result("Top-Down BMP Handling (Negative biHeight)", ok, msg)

    def test_batch_directory_traversal(self):
        test_dir = self.setup_case_dir("case_batch")
        file_count = 16
        delta = 20

        for i in range(file_count):
            img_path = os.path.join(test_dir, f"batch_image_{i:02d}.bmp")
            create_24bpp_bmp(img_path, 6, 6, lambda x, y, w, h: (i * 10, i * 12, i * 14))

        run_assembly_processor(test_dir, delta)

        edited_dir = os.path.join(test_dir, "edited_photo")
        if not os.path.isdir(edited_dir):
            self.record_result("Batch Directory Traversal (16 Files)", False, "edited_photo directory not created")
            return

        produced_files = [f for f in os.listdir(edited_dir) if f.endswith(".bmp")]
        if len(produced_files) != file_count:
            self.record_result(
                "Batch Directory Traversal (16 Files)",
                False,
                f"Expected {file_count} files, found {len(produced_files)}"
            )
            return

        all_ok = True
        err_msg = ""
        for i in range(file_count):
            orig = os.path.join(test_dir, f"batch_image_{i:02d}.bmp")
            edit = os.path.join(edited_dir, f"batch_image_{i:02d}.bmp")
            ok, msg = verify_processed_image(orig, edit, delta)
            if not ok:
                all_ok = False
                err_msg = f"Mismatch in {orig}: {msg}"
                break

        self.record_result("Batch Directory Traversal (All 16 Files Processed)", all_ok, err_msg)

    def test_non_bmp_file_handling(self):
        test_dir = self.setup_case_dir("case_non_bmp")
        # Put 2 valid BMPs and 2 non-BMP text files
        create_24bpp_bmp(os.path.join(test_dir, "valid_1.bmp"), 4, 4, lambda x, y, w, h: (50, 50, 50))
        create_24bpp_bmp(os.path.join(test_dir, "valid_2.bmp"), 4, 4, lambda x, y, w, h: (80, 80, 80))

        with open(os.path.join(test_dir, "notes.txt"), "w") as f:
            f.write("This is a plain text file, not a bitmap image.\n")
        with open(os.path.join(test_dir, "fake_image.bmp"), "w") as f:
            f.write("Corrupted file without BM signature.\n")

        delta = 30
        run_assembly_processor(test_dir, delta)

        edited_dir = os.path.join(test_dir, "edited_photo")
        edited_files = os.listdir(edited_dir)

        passed = ("valid_1.bmp" in edited_files and
                  "valid_2.bmp" in edited_files and
                  "notes.txt" not in edited_files and
                  "fake_image.bmp" not in edited_files)

        self.record_result("Non-BMP and Corrupted File Filtering", passed, f"Produced files: {edited_files}")

    def test_large_image(self):
        test_dir = self.setup_case_dir("case_large")
        img_path = os.path.join(test_dir, "full_hd.bmp")
        # 1920x1080 resolution (5760 row bytes > 4KB, tests row buffer capacity)
        width, height = 1920, 108
        create_24bpp_bmp(img_path, width, height, lambda x, y, w, h: ((x % 256), (y % 256), ((x + y) % 256)))

        delta = 50
        run_assembly_processor(test_dir, delta)
        edited_path = os.path.join(test_dir, "edited_photo", "full_hd.bmp")
        ok, msg = verify_processed_image(img_path, edited_path, delta)
        self.record_result(f"Large Image Buffer Test ({width}x{height} pixels)", ok, msg)


if __name__ == "__main__":
    suite = TestSuite()
    success = suite.run_all()
    sys.exit(0 if success else 1)
