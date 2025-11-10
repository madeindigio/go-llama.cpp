package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"runtime"
	"strings"

	llama "github.com/go-skynet/go-llama.cpp"
)

func main() {
	var modelPath string
	var prompt string
	var threads int
	var gpuLayers int

	// Parse command-line flags
	flag.StringVar(&modelPath, "m", "", "path to GGUF model file (required)")
	flag.StringVar(&prompt, "p", "", "prompt text for embeddings (if not provided, reads from stdin)")
	flag.StringVar(&prompt, "prompt", "", "prompt text for embeddings (if not provided, reads from stdin)")
	flag.IntVar(&threads, "t", runtime.NumCPU(), "number of threads to use during computation")
	flag.IntVar(&gpuLayers, "ngl", 0, "number of GPU layers to use")
	flag.Parse()

	// Validate model path
	if modelPath == "" {
		fmt.Fprintln(os.Stderr, "Error: Model path is required")
		fmt.Fprintln(os.Stderr, "Usage: embeddings -m <model_path> [-p <prompt>] [-t <threads>] [-ngl <gpu_layers>]")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Example:")
		fmt.Fprintln(os.Stderr, "  embeddings -m /www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf -p \"Hello world\"")
		fmt.Fprintln(os.Stderr, "  echo \"Hello world\" | embeddings -m /www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf")
		os.Exit(1)
	}

	// Load the model
	fmt.Fprintf(os.Stderr, "Loading model from: %s\n", modelPath)
	l, err := llama.New(
		modelPath,
		llama.EnableF16Memory,
		llama.SetContext(2048),
		llama.EnableEmbeddings,
		llama.SetGPULayers(gpuLayers),
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading model: %s\n", err.Error())
		os.Exit(1)
	}
	defer l.Free()
	fmt.Fprintf(os.Stderr, "Model loaded successfully\n")

	// Get input text
	var inputText string
	if prompt != "" {
		inputText = prompt
	} else {
		// Read from stdin
		fmt.Fprintf(os.Stderr, "Reading from stdin (press Ctrl+D when done)...\n")
		reader := bufio.NewReader(os.Stdin)
		var lines []string
		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				if err == io.EOF {
					break
				}
				fmt.Fprintf(os.Stderr, "Error reading input: %s\n", err)
				os.Exit(1)
			}
			lines = append(lines, line)
		}
		inputText = strings.Join(lines, "")
		inputText = strings.TrimSpace(inputText)
	}

	if inputText == "" {
		fmt.Fprintln(os.Stderr, "Error: No input text provided")
		os.Exit(1)
	}

	fmt.Fprintf(os.Stderr, "Generating embeddings for: %s\n", inputText)

	// Generate embeddings
	embeddings, err := l.Embeddings(inputText, llama.SetThreads(threads))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating embeddings: %s\n", err.Error())
		os.Exit(1)
	}

	// Output embeddings
	fmt.Fprintf(os.Stderr, "Embeddings generated successfully (%d dimensions)\n", len(embeddings))
	fmt.Println("Embeddings:")
	for i, val := range embeddings {
		if i > 0 {
			fmt.Print(", ")
		}
		fmt.Printf("%.6f", val)
	}
	fmt.Println()
}
