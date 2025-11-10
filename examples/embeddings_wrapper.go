package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
)

// EmbeddingResult represents the output from the llama.cpp embedding binary
type EmbeddingResult struct {
	Embeddings []float32 `json:"embeddings"`
	Dimensions int       `json:"dimensions"`
}

// GenerateEmbeddings calls the llama.cpp embedding binary and returns the embeddings
func GenerateEmbeddings(modelPath string, prompt string, threads int, gpuLayers int) ([]float32, error) {
	// Build the command
	args := []string{
		"-m", modelPath,
		"-p", prompt,
	}

	if threads > 0 {
		args = append(args, "-t", strconv.Itoa(threads))
	}

	if gpuLayers > 0 {
		args = append(args, "-ngl", strconv.Itoa(gpuLayers))
	}

	// Execute the embedding binary
	// Try to find the binary in parent directory or current directory
	embeddingBinary := "../build/bin/embedding"
	if _, err := os.Stat(embeddingBinary); os.IsNotExist(err) {
		embeddingBinary = "./build/bin/embedding"
		if _, err := os.Stat(embeddingBinary); os.IsNotExist(err) {
			embeddingBinary = "build/bin/embedding"
		}
	}

	cmd := exec.Command(embeddingBinary, args...)

	// Capture stdout and stderr
	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return nil, fmt.Errorf("failed to run embedding binary: %w\nStderr: %s", err, stderr.String())
	}

	// Parse the output to extract embeddings
	// Try stdout first, then stderr (llama.cpp outputs to stdout but metadata to stderr)
	embeddings, err := parseEmbeddingsOutput(stdout.String())
	if err != nil {
		// Try stderr if stdout didn't work
		embeddings, err = parseEmbeddingsOutput(stderr.String())
		if err != nil {
			return nil, fmt.Errorf("failed to parse embeddings output: %w", err)
		}
	}

	return embeddings, nil
}

// parseEmbeddingsOutput extracts the embedding values from the binary output
func parseEmbeddingsOutput(output string) ([]float32, error) {
	lines := strings.Split(output, "\n")

	for _, line := range lines {
		// Look for the line that starts with "embedding 0:"
		if strings.HasPrefix(line, "embedding 0:") {
			// Extract the numbers part
			numbersStr := strings.TrimPrefix(line, "embedding 0:")
			numbersStr = strings.TrimSpace(numbersStr)

			// Split by spaces and convert to float32
			parts := strings.Fields(numbersStr)
			embeddings := make([]float32, 0, len(parts))

			for _, part := range parts {
				val, err := strconv.ParseFloat(part, 32)
				if err != nil {
					continue // Skip non-numeric values
				}
				embeddings = append(embeddings, float32(val))
			}

			if len(embeddings) > 0 {
				return embeddings, nil
			}
		}
	}

	return nil, fmt.Errorf("no embeddings found in output")
}

func main() {
	var modelPath string
	var prompt string
	var threads int
	var gpuLayers int
	var outputFormat string

	// Parse command-line flags
	flag.StringVar(&modelPath, "m", "", "path to GGUF model file (required)")
	flag.StringVar(&prompt, "p", "", "prompt text for embeddings (if not provided, reads from stdin)")
	flag.StringVar(&prompt, "prompt", "", "prompt text for embeddings (if not provided, reads from stdin)")
	flag.IntVar(&threads, "t", runtime.NumCPU(), "number of threads to use during computation")
	flag.IntVar(&gpuLayers, "ngl", 0, "number of GPU layers to use")
	flag.StringVar(&outputFormat, "format", "text", "output format: text or json")
	flag.Parse()

	// Validate model path
	if modelPath == "" {
		fmt.Fprintln(os.Stderr, "Error: Model path is required")
		fmt.Fprintln(os.Stderr, "Usage: embeddings_wrapper -m <model_path> [-p <prompt>] [-t <threads>] [-ngl <gpu_layers>] [-format text|json]")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Example:")
		fmt.Fprintln(os.Stderr, "  embeddings_wrapper -m /www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf -p \"Hello world\"")
		fmt.Fprintln(os.Stderr, "  echo \"Hello world\" | embeddings_wrapper -m /www/Remembrances/nomic-embed-text-v1.5.Q4_K_M.gguf")
		os.Exit(1)
	}

	// Get input text
	var inputText string
	if prompt != "" {
		inputText = prompt
	} else {
		// Read from stdin
		fmt.Fprintln(os.Stderr, "Reading from stdin (press Ctrl+D when done)...")
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

	// Generate embeddings using the wrapper function
	embeddings, err := GenerateEmbeddings(modelPath, inputText, threads, gpuLayers)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating embeddings: %s\n", err.Error())
		os.Exit(1)
	}

	// Output embeddings
	fmt.Fprintf(os.Stderr, "Embeddings generated successfully (%d dimensions)\n", len(embeddings))

	if outputFormat == "json" {
		result := EmbeddingResult{
			Embeddings: embeddings,
			Dimensions: len(embeddings),
		}
		jsonData, err := json.MarshalIndent(result, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error encoding JSON: %s\n", err)
			os.Exit(1)
		}
		fmt.Println(string(jsonData))
	} else {
		// Text format
		fmt.Println("Embeddings:")
		for i, val := range embeddings {
			if i > 0 {
				fmt.Print(", ")
			}
			fmt.Printf("%.6f", val)
		}
		fmt.Println()
	}
}
