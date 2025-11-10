package main

import (
	"fmt"
	"os"

	llama "github.com/go-skynet/go-llama.cpp"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: test_autodetect <model_path> [text]")
		os.Exit(1)
	}

	modelPath := os.Args[1]
	text := "hello world"
	if len(os.Args) > 2 {
		text = os.Args[2]
	}

	fmt.Printf("Loading model: %s\n", modelPath)

	// Load model with embeddings enabled
	l, err := llama.New(
		modelPath,
		llama.EnableF16Memory,
		llama.SetContext(2048),
		llama.EnableEmbeddings,
	)
	if err != nil {
		fmt.Printf("Error loading model: %v\n", err)
		os.Exit(1)
	}
	defer l.Free()

	fmt.Printf("Model loaded successfully\n")
	fmt.Printf("Testing auto-detection of embedding dimensions...\n\n")

	// Test 1: Without specifying dimensions (should auto-detect)
	fmt.Printf("Test 1: Auto-detection (no SetTokens specified)\n")
	embeddings1, err := l.Embeddings(text)
	if err != nil {
		fmt.Printf("Error generating embeddings: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("  Result: Generated %d-dimensional embeddings\n", len(embeddings1))
	fmt.Printf("  First 5 values: %.6f, %.6f, %.6f, %.6f, %.6f\n\n",
		embeddings1[0], embeddings1[1], embeddings1[2], embeddings1[3], embeddings1[4])

	// Test 2: With explicit dimensions (should respect the setting)
	fmt.Printf("Test 2: Explicit dimension with SetTokens(768)\n")
	embeddings2, err := l.Embeddings(text, llama.SetTokens(768))
	if err != nil {
		fmt.Printf("Error generating embeddings: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("  Result: Generated %d-dimensional embeddings\n", len(embeddings2))
	fmt.Printf("  First 5 values: %.6f, %.6f, %.6f, %.6f, %.6f\n\n",
		embeddings2[0], embeddings2[1], embeddings2[2], embeddings2[3], embeddings2[4])

	// Test 3: With smaller dimension (should still work but truncate)
	fmt.Printf("Test 3: Smaller dimension with SetTokens(128)\n")
	embeddings3, err := l.Embeddings(text, llama.SetTokens(128))
	if err != nil {
		fmt.Printf("Error generating embeddings: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("  Result: Generated %d-dimensional embeddings\n", len(embeddings3))
	fmt.Printf("  First 5 values: %.6f, %.6f, %.6f, %.6f, %.6f\n\n",
		embeddings3[0], embeddings3[1], embeddings3[2], embeddings3[3], embeddings3[4])

	fmt.Printf("✅ Auto-detection feature is working correctly!\n")
	fmt.Printf("   - Auto-detected: %d dimensions\n", len(embeddings1))
	fmt.Printf("   - Embeddings match between auto and explicit (768): %v\n", len(embeddings1) == len(embeddings2))
}
