# AI Backends Specification

## Overview
The system supports multiple AI backends for chat and search. Configuration is done through environment variables and the Khoj admin panel.

## Supported Backends

### 1. Ollama (Local, Free, Offline)
| Property | Value |
|----------|-------|
| Installation | `brew install ollama && ollama pull llama3.2` |
| Default model | llama3.2 |
| API endpoint | `http://localhost:11434/v1/` |
| Configuration | Uncomment `OPENAI_BASE_URL` in khoj.env |
| Privacy | Full — no data leaves the machine |
| Cost | Free |
| Internet required | No (after model download) |

### 2. OpenAI (Cloud)
| Property | Value |
|----------|-------|
| Configuration | Set `OPENAI_API_KEY` in khoj.env |
| Models | GPT-4, GPT-3.5-turbo, etc. (configured in Khoj admin) |
| Privacy | Data sent to OpenAI servers |
| Cost | Per-token pricing |
| Internet required | Yes |

### 3. Anthropic (Cloud)
| Property | Value |
|----------|-------|
| Configuration | Set `ANTHROPIC_API_KEY` in khoj.env |
| Models | Claude family (configured in Khoj admin) |
| Privacy | Data sent to Anthropic servers |
| Cost | Per-token pricing |
| Internet required | Yes |

## Configuration Hierarchy
1. Environment variables in `khoj.env` provide API keys and base URLs
2. Khoj admin panel (`/server/admin`) configures which models to use
3. Chat models are selected per-conversation in the Khoj UI

## How Khoj Uses AI
1. **Embedding generation** — creates vector representations of notes for semantic search
2. **Chat** — conversational interface for querying notes
3. **Summarization** — condensing search results into answers
4. **Context retrieval** — finding relevant notes to include in chat context

## Switching Between Backends
- Ollama and cloud APIs can coexist
- Model selection is per-chat in the Khoj UI
- Changing `OPENAI_BASE_URL` requires server restart
- API key changes require server restart

## Offline Operation
With Ollama configured:
- Full chat and search functionality without internet
- Embedding generation runs locally
- No telemetry or external calls
- Performance depends on local hardware (Apple Silicon recommended)
