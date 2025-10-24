#!/bin/bash

# Static build script for llama.cpp library
# This script builds llama.cpp as a static library for cross-compilation
# Usage: build-static.sh <os> <arch>

set -e

OS="$1"
ARCH="$2"

if [ -z "$OS" ] || [ -z "$ARCH" ]; then
    echo "Usage: build-static.sh <os> <arch>"
    echo "Example: build-static.sh linux amd64"
    exit 1
fi

echo "Building llama.cpp static library for $OS-$ARCH..."

# Navigate to llama.cpp directory
cd "$(dirname "$0")/.."

# Clean previous builds
echo "Cleaning previous builds..."
make clean
rm -rf build

# Set platform-specific flags
case "$OS" in
    "linux")
        case "$ARCH" in
            "amd64")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=x86-64 -mtune=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -march=x86-64 -mtune=generic"
                ;;
            "386")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=i386 -mtune=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -march=i386 -mtune=generic"
                ;;
            "arm64")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -mcpu=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -mcpu=generic"
                ;;
            "arm")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -mcpu=arm1176jzf-s -mfpu=neon"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -mcpu=arm1176jzf-s -mfpu=neon"
                ;;
        esac
        LDFLAGS="-pthread"
        ;;
    "darwin")
        case "$ARCH" in
            "amd64")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=x86-64 -mtune=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -march=x86-64 -mtune=generic"
                ;;
            "arm64")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -mcpu=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -mcpu=generic"
                ;;
        esac
        LDFLAGS="-pthread -framework Accelerate -framework Foundation -framework Metal -framework MetalKit -framework MetalPerformanceShaders"
        ;;
    "windows")
        case "$ARCH" in
            "amd64")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=x86-64 -mtune=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -march=x86-64 -mtune=generic"
                ;;
            "386")
                CFLAGS="-O3 -DNDEBUG -std=c11 -fPIC -march=i386 -mtune=generic"
                CXXFLAGS="-O3 -DNDEBUG -std=c++11 -fPIC -march=i386 -mtune=generic"
                ;;
        esac
        LDFLAGS=""
        ;;
esac

# Add common flags
CFLAGS="$CFLAGS -I./llama.cpp -I. -Wall -Wextra -Wpedantic -Wcast-qual -Wdouble-promotion -Wshadow -Wstrict-prototypes -Wpointer-arith -Wno-unused-function"
CXXFLAGS="$CXXFLAGS -I./llama.cpp -I./llama.cpp/common -I. -Wall -Wextra -Wpedantic -Wcast-qual -Wno-unused-function"

# Create build directory
mkdir -p build

# Configure and build with cmake for cross-compilation
echo "Configuring with CMake..."
cd build

case "$OS" in
    "linux")
        case "$ARCH" in
            "amd64")
                CMAKE_TARGET="x86_64-linux-gnu"
                ;;
            "386")
                CMAKE_TARGET="i686-linux-gnu"
                ;;
            "arm64")
                CMAKE_TARGET="aarch64-linux-gnu"
                ;;
            "arm")
                CMAKE_TARGET="arm-linux-gnueabihf"
                ;;
        esac
        cmake ../llama.cpp \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR=$ARCH \
            -DCMAKE_C_COMPILER=gcc \
            -DCMAKE_CXX_COMPILER=g++ \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
            -DLLAMA_STATIC=ON \
            -DBUILD_SHARED_LIBS=OFF
        ;;
    "darwin")
        case "$ARCH" in
            "amd64")
                CMAKE_TARGET="x86_64-apple-darwin"
                ;;
            "arm64")
                CMAKE_TARGET="arm64-apple-darwin"
                ;;
        esac
        cmake ../llama.cpp \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_SYSTEM_NAME=Darwin \
            -DCMAKE_SYSTEM_PROCESSOR=$ARCH \
            -DCMAKE_C_COMPILER=clang \
            -DCMAKE_CXX_COMPILER=clang++ \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
            -DLLAMA_STATIC=ON \
            -DBUILD_SHARED_LIBS=OFF \
            -DLLAMA_ACCELERATE=ON
        ;;
    "windows")
        case "$ARCH" in
            "amd64")
                CMAKE_TARGET="x86_64-w64-mingw32"
                ;;
            "386")
                CMAKE_TARGET="i686-w64-mingw32"
                ;;
        esac
        cmake ../llama.cpp \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_SYSTEM_PROCESSOR=$ARCH \
            -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
            -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
            -DCMAKE_C_FLAGS="$CFLAGS" \
            -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
            -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
            -DLLAMA_STATIC=ON \
            -DBUILD_SHARED_LIBS=OFF
        ;;
esac

echo "Building llama.cpp..."
cmake --build . --config Release --parallel $(nproc 2>/dev/null || echo 4)

# Copy required object files back to parent directory
echo "Copying object files..."
cd ..

# Copy the static library and object files
mkdir -p llama.cpp
cp build/libllama.a llama.cpp/ 2>/dev/null || true
cp build/CMakeFiles/llama.dir/*.o llama.cpp/ 2>/dev/null || true
cp build/CMakeFiles/common.dir/*.o llama.cpp/ 2>/dev/null || true

# Build the Go binding with static library
echo "Building Go binding..."

# Compile binding.cpp to object file
g++ -c binding.cpp -o binding.o \
    $CXXFLAGS \
    -I./llama.cpp \
    -I./llama.cpp/common

# Extract object files from static libraries
echo "Extracting object files from static libraries..."
mkdir -p build/tmp_extract
cd build/tmp_extract

# Extract from libllama.a
ar x ../libllama.a

# Extract from libggml_static.a
ar x ../libggml_static.a

# Go back to parent directory
cd ../..

# Create static archive with all object files
echo "Creating combined static library..."
ar rcs libbinding.a binding.o build/tmp_extract/*.o

# Build common library objects from source
echo "Compiling common library..."
cd llama.cpp/common
g++ -c common.cpp -o ../../build/tmp_extract/common.o $CXXFLAGS -I.. -I.
g++ -c grammar-parser.cpp -o ../../build/tmp_extract/grammar-parser.o $CXXFLAGS -I.. -I.
g++ -c console.cpp -o ../../build/tmp_extract/console.o $CXXFLAGS -I.. -I.
cd ../..

# Recreate archive with all objects including common
ar rcs libbinding.a binding.o build/tmp_extract/*.o

# Clean up temporary directory
rm -rf build/tmp_extract

echo "Static build completed for $OS-$ARCH"
echo "libbinding.a is ready for static linking"
