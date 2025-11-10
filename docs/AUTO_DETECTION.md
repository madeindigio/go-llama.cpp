# Automatic Embedding Dimension Detection

## Overview

As of commit `6bb69bc`, go-llama.cpp automatically detects the correct embedding dimensions from the model metadata. Users no longer need to manually specify embedding dimensions using `SetTokens()`.

## What Changed

### Before (Manual Configuration Required)

Previously, users had to manually specify the embedding dimensions, or the default of 128 would be used:

```go
// Without SetTokens - would only get 128 dimensions (TRUNCATED!)
embeddings, _ := l.Embeddings("hello world")
fmt.Println(len(embeddings)) // Output: 128 ❌

// Had to manually specify to get full dimensions
embeddings, _ := l.Embeddings("hello world", llama.SetTokens(768))
fmt.Println(len(embeddings)) // Output: 768 ✓
```

### After (Automatic Detection)

Now the correct dimensions are automatically detected from the model:

```go
// Auto-detects 768 dimensions from model metadata
embeddings, _ := l.Embeddings("hello world")
fmt.Println(len(embeddings)) // Output: 768 ✓

// Can still override if needed
embeddings, _ := l.Embeddings("hello world", llama.SetTokens(384))
fmt.Println(len(embeddings)) // Output: 384 ✓
```

## How It Works

1. **Default Token Setting**: Changed `DefaultOptions.Tokens` from `128` to `0`
2. **Auto-Detection Logic**: When `Tokens == 0`, the code calls `get_embedding_size()`
3. **Model Query**: `get_embedding_size()` calls `llama_n_embd(model)` to get the model's native embedding dimension
4. **Dimension Setting**: The detected dimension is used to allocate the embedding array

## Technical Details

### Code Changes

**options.go**
```go
var DefaultOptions PredictOptions = PredictOptions{
    Seed:    -1,
    Threads: 4,
    Tokens:  0,        // Changed from 128 to enable auto-detection
    // ... other fields
}
```

**llama.go** (existing auto-detection code now works)
```go
if po.Tokens == 0 {
    embdSize := int(C.get_embedding_size(l.state))
    if embdSize > 0 {
        po.Tokens = embdSize  // Use detected size
    } else {
        po.Tokens = 99999999  // Fallback
    }
}
```

**binding.cpp** (existing function)
```cpp
int get_embedding_size(void* state_pr) {
    llama_binding_state* state = (llama_binding_state*) state_pr;
    llama_model* model = state->model;
    return llama_n_embd(model);  // Returns model's native dimension
}
```

## Testing

### Simple Test
```bash
cd examples
go build test_embedding_size.go
./test_embedding_size /path/to/model.gguf
```

### Comprehensive Test
```bash
cd examples
go build test_autodetect.go
./test_autodetect /path/to/model.gguf "test text"
```

The comprehensive test verifies three scenarios:
1. **Auto-detection**: No `SetTokens()` specified → detects 768
2. **Explicit full**: `SetTokens(768)` → uses 768
3. **Explicit partial**: `SetTokens(128)` → truncates to 128

## Supported Models

Auto-detection works with all GGUF models that have embedding dimension metadata:

- ✅ **nomic-embed-text-v1.5** (768 dimensions)
- ✅ **BGE models** (various dimensions)
- ✅ **Sentence transformers** (various dimensions)
- ✅ **Custom embedding models** (any valid dimension)

## Benefits

1. **No Manual Configuration**: Users don't need to know model dimensions
2. **Model-Aware**: Automatically adapts to different architectures
3. **Backward Compatible**: Explicit `SetTokens()` still works for overrides
4. **Correct by Default**: No more accidentally truncated embeddings
5. **Production Ready**: Eliminates a common source of errors

## Migration Guide

If you have existing code that manually specifies `SetTokens()`:

### Option 1: Remove Manual Specification (Recommended)
```go
// Old code
embeddings, _ := l.Embeddings("text", llama.SetTokens(768))

// New code - auto-detects
embeddings, _ := l.Embeddings("text")
```

### Option 2: Keep Manual Specification (Still Works)
```go
// This still works if you need to override
embeddings, _ := l.Embeddings("text", llama.SetTokens(768))
```

## Use Cases for Manual Override

While auto-detection works for most cases, you might want to manually specify dimensions when:

1. **Dimension Reduction**: Intentionally truncate embeddings for reduced storage
2. **Testing**: Compare different dimension sizes
3. **Legacy Compatibility**: Match dimensions with existing systems
4. **Performance**: Use fewer dimensions for faster similarity calculations

Example:
```go
// Intentionally truncate to 384 dimensions for storage optimization
embeddings, _ := l.Embeddings("text", llama.SetTokens(384))
```

## Troubleshooting

### Problem: Still Getting 128 Dimensions

**Possible Causes:**
1. Using an older version of go-llama.cpp (before commit 6bb69bc)
2. Model doesn't have embedding metadata
3. Explicitly setting `SetTokens(128)` somewhere

**Solution:**
1. Update to latest version: `git pull`
2. Rebuild: `make clean && make`
3. Rebuild examples: `cd examples && go build -a`

### Problem: Auto-Detection Returns 0

**Possible Causes:**
1. Model failed to load
2. Model is not an embedding model
3. Corrupted GGUF file

**Solution:**
1. Check model loading errors
2. Verify model is an embedding model (not a text generation model)
3. Re-download the model

## Performance Impact

Auto-detection has **negligible performance impact**:
- Called once during `Embeddings()` invocation
- Simple function call to `llama_n_embd()`
- O(1) operation - just reads model metadata
- No additional memory allocation

## Example Output

### Before Auto-Detection
```
$ ./embeddings -m nomic-embed-text-v1.5.gguf -p "test"
Embeddings generated successfully (128 dimensions)  ❌ TRUNCATED!
```

### After Auto-Detection
```
$ ./embeddings -m nomic-embed-text-v1.5.gguf -p "test"
Embeddings generated successfully (768 dimensions)  ✅ CORRECT!
```

## Related Documentation

- [Examples README](../examples/README.md) - Comprehensive usage examples
- [Main README](../README.md) - Project overview
- [PLAN.md](../.serena/memories/PLAN.md) - Development history

## Future Enhancements

Potential future improvements:
- [ ] Auto-detect optimal batch size based on model
- [ ] Auto-detect context length from model
- [ ] Validate detected dimensions against known architectures
- [ ] Add dimension detection to model info API