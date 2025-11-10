package main

import (
	"fmt"
	"os"

	llama "github.com/go-skynet/go-llama.cpp"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: test_embedding_size <model_path>")
		os.Exit(1)
	}

	modelPath := os.Args[1]

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

	fmt.Printf("Model loaded successfully\n\n")

	// Test embedding with no tokens specified (should auto-detect)
	text := "test"
	fmt.Printf("Generating embeddings for: '%s'\n", text)
	fmt.Printf("Testing with NO SetTokens() - should auto-detect from model...\n\n")

	embeddings, err := l.Embeddings(text)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("✅ Success!\n")
	fmt.Printf("   Auto-detected embedding size: %d dimensions\n", len(embeddings))
	fmt.Printf("   First 10 values: ")
	for i := 0; i < 10 && i < len(embeddings); i++ {
		fmt.Printf("%.4f ", embeddings[i])
	}
	fmt.Printf("\n")
}
