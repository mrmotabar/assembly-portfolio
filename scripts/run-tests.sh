#!/usr/bin/env bash
# ==============================================================================
# Script: run-tests.sh
# Description: Convenience runner for test suite and performance benchmarks.
# Standard: Uniform Naming Standards (Core Rules)
# ==============================================================================

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "=========================================================="
echo "  1. Building Assembly Image Processor..."
echo "=========================================================="
make build

echo ""
echo "=========================================================="
echo "  2. Running Automated Correctness Test Suite..."
echo "=========================================================="
make test

echo ""
echo "=========================================================="
echo "  3. Running Performance Benchmark Suite..."
echo "=========================================================="
make benchmark

echo ""
echo "=========================================================="
echo "  All tests and benchmarks completed successfully!"
echo "=========================================================="
