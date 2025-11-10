# go-llama.cpp Examples

This directory contains example programs demonstrating how to use go-llama.cpp for embeddings with GGUF models, including nomic-bert models.

## Embeddings Wrapper (RECOMMENDED)

The `embeddings_wrapper.go` is a simple Go wrapper around the llama.cpp embedding binary that works perfectly with nomic-bert models.

### Features

- ✅ **Works with nomic-bert models** (e.g., nomic-embed-text-v1.5)
- ✅ Support for all GGUF embedding models
- ✅ Multiple output formats (text and JSON)
- ✅ Command-line interface
- ✅ Stdin support for piping text
- ✅ Thread and GPU layer configuration
- ✅ No complex C++ bindings required

### Prerequisites

Make sure the llama.cpp embedding binary is built:
```bash
# From the go-llama.cpp root directory
make libbinding.a
```

This will build `build/bin/embedding` binary.

### Usage

#### Running with Go

```bash
# Basic usage
go run embeddings_wrapper.go -m /path/to/model.gguf -p "your text here"

# With JSON output
go run embeddings_wrapper.go -m /path/to/model.gguf -p "your text" -format json

# With GPU layers
go run embeddings_wrapper.go -m /path/to/model.gguf -p "your text" -ngl 32

# From stdin
echo "your text" | go run embeddings_wrapper.go -m /path/to/model.gguf
```

#### Building and Running Binary

```bash
# Build
go build -o embeddings_wrapper embeddings_wrapper.go

# Run
./embeddings_wrapper -m /path/to/model.gguf -p "your text"
```

### Examples with Nomic Models

```bash
# Generate embeddings for text
./embeddings_wrapper -m /www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf -p "hola mundo"

# JSON output for programmatic use
./embeddings_wrapper -m /www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf -p "hola mundo" -format json

# Using nomic-embed-text v2 MoE model
./embeddings_wrapper -m /www/Remembrances/nomic-embed-text-v2-moe.Q4_K_M.gguf -p "your text here"
```

### Command-Line Options

- `-m` : Path to GGUF model file (**required**)
- `-p` or `-prompt` : Text to generate embeddings for (if omitted, reads from stdin)
- `-t` : Number of threads (default: number of CPU cores)
- `-ngl` : Number of GPU layers to use (default: 0)
- `-format` : Output format: `text` or `json` (default: `text`)

### Output Formats

#### Text Format
```
Embeddings:
0.039979, 0.023464, -0.154149, 0.064967, ...
```

#### JSON Format
```json
{
  "embeddings": [
    0.039979,
    0.023464,
    -0.154149,
    0.064967,
    ...
  ],
  "dimensions": 768
}
```

### Using in Your Go Code

You can import and use the `GenerateEmbeddings` function:

```go
package main

import (
    "fmt"
    "log"
)

func main() {
    modelPath := "/www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf"
    text := "hello world"
    
    embeddings, err := GenerateEmbeddings(modelPath, text, 8, 0)
    if err != nil {
        log.Fatal(err)
    }
    
    fmt.Printf("Generated %d-dimensional embeddings\n", len(embeddings))
    // Use embeddings...
}
```

## Original Embeddings Example (NEEDS UPDATE)

The `embeddings.go` file is the original implementation using direct go-llama.cpp bindings. **Note**: This currently doesn't work with the updated llama.cpp that supports nomic-bert because the sampling API has changed.

If you need the direct bindings approach, consider using `embeddings_wrapper.go` instead, which provides a simpler and more reliable interface.

## Troubleshooting

### "no such file or directory" Error

If you get an error about `build/bin/embedding` not found, make sure you've built llama.cpp:

```bash
make libbinding.a
```

Or create the embedding binary directly:

```bash
cd llama.cpp
make embedding
cd ..
```

### Nomic Model Architecture Errors

If you get "unknown model architecture: nomic-bert", your llama.cpp version is too old. The llama.cpp submodule should be at commit 4524290e8 or later. Check the main project README for update instructions.

## Performance Tips

1. **Use GPU acceleration**: Add `-ngl 32` (or higher) to offload layers to GPU
2. **Adjust threads**: Use `-t` to match your CPU cores for better performance
3. **Batch processing**: For multiple texts, call the wrapper multiple times or modify the code to support batch processing

## License

Same as go-llama.cpp main project.
