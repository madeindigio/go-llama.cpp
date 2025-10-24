#!/bin/bash

# Multi-platform static build script for llama.cpp library
# This script builds llama.cpp as a static library for cross-compilation
# Usage: build-static-multi.sh <os> <arch>
#
# Designed to work with goreleaser-cross Docker image
# Supported platforms:
#   - linux/amd64, linux/arm64
#   - darwin/amd64, darwin/arm64
#   - windows/amd64

set -e

OS="$1"
ARCH="$2"

if [ -z "$OS" ] || [ -z "$ARCH" ]; then
    echo "Usage: build-static-multi.sh <os> <arch>"
    echo "Example: build-static-multi.sh linux amd64"
    echo ""
    echo "Supported platforms:"
    echo "  linux/amd64   - Linux x86_64"
    echo "  linux/arm64   - Linux ARM64"
    echo "  darwin/amd64  - macOS Intel"
    echo "  darwin/arm64  - macOS Apple Silicon"
    echo "  windows/amd64 - Windows x86_64"
    exit 1
fi

PLATFORM="${OS}-${ARCH}"
echo "=========================================="
echo "Building llama.cpp static library"
echo "Platform: $PLATFORM"
echo "=========================================="

# Fix git ownership issues in Docker
if [ -d "./llama.cpp/.git" ]; then
    git config --global --add safe.directory "$(pwd)/llama.cpp" 2>/dev/null || true
    git config --global --add safe.directory "/go/src/github.com/madeindigio/remembrances-mcp/go-llama.cpp/llama.cpp" 2>/dev/null || true
fi
# Also configure parent directory
git config --global --add safe.directory "$(pwd)" 2>/dev/null || true
git config --global --add safe.directory "/go/src/github.com/madeindigio/remembrances-mcp/go-llama.cpp" 2>/dev/null || true

# Navigate to llama.cpp directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LLAMA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$LLAMA_DIR"

# Create build directory for this platform
BUILD_DIR="build/${PLATFORM}"
echo "Build directory: $BUILD_DIR"

# Clean previous builds for this platform
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -f "libbinding-${PLATFORM}.a"

# Set platform-specific compiler and flags
case "$OS" in
    "linux")
        case "$ARCH" in
            "amd64")
                CC="x86_64-linux-gnu-gcc"
                CXX="x86_64-linux-gnu-g++"
                AR="x86_64-linux-gnu-ar"
                CMAKE_SYSTEM_PROCESSOR="x86_64"
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=x86-64 -mtune=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++14 -fPIC -march=x86-64 -mtune=generic"
                LDFLAGS="-pthread"
                ;;
            "arm64")
                CC="aarch64-linux-gnu-gcc"
                CXX="aarch64-linux-gnu-g++"
                AR="aarch64-linux-gnu-ar"
                CMAKE_SYSTEM_PROCESSOR="aarch64"
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC"
                CXXFLAGS="-O3 -DNDEBUG -std=c++14 -fPIC"
                LDFLAGS="-pthread"
                ;;
            *)
                echo "Unsupported Linux architecture: $ARCH"
                exit 1
                ;;
        esac
        CMAKE_SYSTEM_NAME="Linux"
        ;;
    "darwin")
        case "$ARCH" in
            "amd64")
                CC="o64-clang"
                CXX="o64-clang++"
                AR="x86_64-apple-darwin21.1-ar"
                CMAKE_SYSTEM_PROCESSOR="x86_64"
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=x86-64 -mtune=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++14 -fPIC -march=x86-64 -mtune=generic"
                ;;
            "arm64")
                CC="oa64-clang"
                CXX="oa64-clang++"
                AR="aarch64-apple-darwin21.1-ar"
                CMAKE_SYSTEM_PROCESSOR="arm64"
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC"
                CXXFLAGS="-O3 -DNDEBUG -std=c++14 -fPIC"
                ;;
            *)
                echo "Unsupported Darwin architecture: $ARCH"
                exit 1
                ;;
        esac
        CMAKE_SYSTEM_NAME="Darwin"
        LDFLAGS="-pthread"
        # Disable Apple frameworks for cross-compilation (not available in Docker)
        DISABLE_APPLE_FRAMEWORKS="ON"
        ;;
    "windows")
        case "$ARCH" in
            "amd64")
                # Use POSIX-threaded MinGW for full C++11/14 threading support
                CC="x86_64-w64-mingw32-gcc-posix"
                CXX="x86_64-w64-mingw32-g++-posix"
                AR="x86_64-w64-mingw32-gcc-ar-posix"
                CMAKE_SYSTEM_PROCESSOR="x86_64"
                # Target Windows 7 for better compatibility with older MinGW headers
                # Disable mmap to avoid WIN32_MEMORY_RANGE_ENTRY dependency (Windows 8+ API)
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=x86-64 -mtune=generic -D_WIN32_WINNT=0x0601"
                CXXFLAGS="-O3 -DNDEBUG -std=c++14 -fPIC -march=x86-64 -mtune=generic -D_WIN32_WINNT=0x0601 -DGGML_USE_MMAP=0"
                LDFLAGS="-static -pthread -static-libgcc -static-libstdc++"
                ;;
            *)
                echo "Unsupported Windows architecture: $ARCH"
                exit 1
                ;;
        esac
        CMAKE_SYSTEM_NAME="Windows"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Add common flags
CFLAGS="$CFLAGS -I./llama.cpp -I. -Wall -Wextra -Wpedantic -Wcast-qual -Wdouble-promotion -Wshadow -Wstrict-prototypes -Wpointer-arith -Wno-unused-function"
CXXFLAGS="$CXXFLAGS -I./llama.cpp -I./llama.cpp/common -I. -Wall -Wextra -Wpedantic -Wcast-qual -Wno-unused-function"

echo "Compiler: $CC / $CXX"
echo "Archiver: $AR"
echo "CFLAGS: $CFLAGS"
echo "CXXFLAGS: $CXXFLAGS"
echo "LDFLAGS: $LDFLAGS"

# Fix BUILD_NUMBER and BUILD_COMMIT for build-info.h
export BUILD_NUMBER=0
export BUILD_COMMIT="unknown"

# Remove old build-info.h to force regeneration with correct BUILD_NUMBER
rm -f "llama.cpp/build-info.h"

# Configure with CMake
echo ""
echo "Configuring with CMake..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

CMAKE_ARGS=(
    "../../llama.cpp"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_SYSTEM_NAME=$CMAKE_SYSTEM_NAME"
    "-DCMAKE_SYSTEM_PROCESSOR=$CMAKE_SYSTEM_PROCESSOR"
    "-DCMAKE_C_COMPILER=$CC"
    "-DCMAKE_CXX_COMPILER=$CXX"
    "-DCMAKE_C_FLAGS=$CFLAGS"
    "-DCMAKE_CXX_FLAGS=$CXXFLAGS"
    "-DCMAKE_EXE_LINKER_FLAGS=$LDFLAGS"
    "-DLLAMA_STATIC=ON"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DLLAMA_BUILD_TESTS=OFF"
    "-DLLAMA_BUILD_EXAMPLES=OFF"
    "-DBUILD_NUMBER=0"
    "-DBUILD_COMMIT=unknown"
)



# Add platform-specific CMake arguments
if [ "$OS" = "darwin" ]; then
    # Disable Apple-specific features for cross-compilation
    if [ "$DISABLE_APPLE_FRAMEWORKS" = "ON" ]; then
        CMAKE_ARGS+=("-DLLAMA_ACCELERATE=OFF")
        CMAKE_ARGS+=("-DLLAMA_METAL=OFF")
    else
        CMAKE_ARGS+=("-DLLAMA_ACCELERATE=ON")
    fi
fi

cmake "${CMAKE_ARGS[@]}"

# Build with CMake
echo ""
echo "Building llama.cpp..."
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
cmake --build . --config Release --parallel "$NPROC"

# Extract and combine object files
echo ""
echo "Extracting and combining object files..."
cd "$LLAMA_DIR"

# Create temporary directory for extraction
TEMP_DIR="$BUILD_DIR/tmp_extract"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Extract from libllama.a
if [ -f "../libllama.a" ]; then
    $AR x ../libllama.a
else
    echo "Error: libllama.a not found in $BUILD_DIR"
    exit 1
fi

# Extract from libggml_static.a
if [ -f "../libggml_static.a" ]; then
    $AR x ../libggml_static.a
else
    echo "Error: libggml_static.a not found in $BUILD_DIR"
    exit 1
fi

# Go back to main directory
cd "$LLAMA_DIR"

# Compile binding.cpp
echo ""
echo "Compiling binding.cpp..."
$CXX -c binding.cpp -o "$TEMP_DIR/binding.o" \
    $CXXFLAGS \
    -I./llama.cpp \
    -I./llama.cpp/common

# Compile common library sources
echo "Compiling common library..."
cd llama.cpp/common

$CXX -c common.cpp -o "$LLAMA_DIR/$TEMP_DIR/common.o" \
    $CXXFLAGS -I.. -I.

$CXX -c grammar-parser.cpp -o "$LLAMA_DIR/$TEMP_DIR/grammar-parser.o" \
    $CXXFLAGS -I.. -I.

$CXX -c console.cpp -o "$LLAMA_DIR/$TEMP_DIR/console.o" \
    $CXXFLAGS -I.. -I.

cd "$LLAMA_DIR"

# Create combined static archive
echo ""
echo "Creating combined static library..."
OUTPUT_LIB="libbinding-${PLATFORM}.a"
$AR rcs "$OUTPUT_LIB" "$TEMP_DIR"/*.o

# Verify the library was created
if [ ! -f "$OUTPUT_LIB" ]; then
    echo "Error: Failed to create $OUTPUT_LIB"
    exit 1
fi

# Get library size
LIB_SIZE=$(du -h "$OUTPUT_LIB" | cut -f1)
echo ""
echo "✓ Successfully created: $OUTPUT_LIB ($LIB_SIZE)"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Verify the library was created
if [ ! -f "libbinding-${PLATFORM}.a" ]; then
    echo "Error: libbinding-${PLATFORM}.a not found"
    exit 1
fi

# Note: We don't create a libbinding.a symlink here to avoid conflicts
# when multiple platforms are built in parallel. GoReleaser provides
# platform-specific -lbinding-${PLATFORM} flags in CGO_LDFLAGS.
echo "✓ Library ready for linking with -lbinding-${PLATFORM}"

echo ""
echo "=========================================="
echo "Build completed successfully!"
echo "Platform: $PLATFORM"
echo "Output: $OUTPUT_LIB"
echo "=========================================="
