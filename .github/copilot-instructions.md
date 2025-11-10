# go-llama.cpp library

This is a library in go for binding llama.cpp models using cgo in golang projects.

## 🛠️ Work Methodology

### Essential First Steps

* Use the tool initial-context to gather all necessary information about the current status of the project
* **Check Serena onboarding**: Use `mcp_serena_check_onboarding_performed`
* **Read memories**: Use `mcp_serena_list_memories` and read relevant ones for context
* **Search knowledge base**: Use remembrances tools for recovering related information for the task and before context
* **Check the plan**: Review `.serena/memories/plan.md` for current tasks

### Development Workflow

- Use always english as language for all code, comments, and documentation although the user may write in other languages
- **Knowledge storage**: Save findings using remembrances tools for future reference

### External Research

- Use web search (google/perplexity/brave) for additional information when needed
- Use Context7 for API documentation and library usage patterns
