package main

import (
	"fmt"
	"os"

	llama "github.com/go-skynet/go-llama.cpp"
)

func main() {
	modelPath := "/www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf"

	fmt.Fprintf(os.Stderr, "Loading model from: %s\n", modelPath)
	l, err := llama.New(
		modelPath,
		llama.EnableF16Memory,
		llama.SetContext(2048),
		llama.EnableEmbeddings,
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading model: %s\n", err.Error())
		os.Exit(1)
	}
	defer l.Free()
	fmt.Fprintf(os.Stderr, "Model loaded successfully\n")

	inputText := "hello world"
	fmt.Fprintf(os.Stderr, "Generating embeddings for: %s\n", inputText)

	// Generate embeddings with proper buffer size (768 for nomic)
	embeddings, err := l.Embeddings(inputText, llama.SetTokens(768))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating embeddings: %s\n", err.Error())
		os.Exit(1)
	}

	// Output embeddings
	fmt.Fprintf(os.Stderr, "Embeddings generated successfully (%d dimensions)\n", len(embeddings))
	fmt.Printf("First 10 dimensions: ")
	for i := 0; i < 10 && i < len(embeddings); i++ {
		if i > 0 {
			fmt.Print(", ")
		}
		fmt.Printf("%.6f", embeddings[i])
	}
	fmt.Println()
	fmt.Printf("Total dimensions: %d\n", len(embeddings))
}
