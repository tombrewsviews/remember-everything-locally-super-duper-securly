# Project Overview

## Name
remember-everything-locally-super-duper-securly (logmem)

## Description
A private, local AI memory system for macOS built on Khoj. Hardened for privacy, stealth, and offline-first operation with zero cloud dependencies.

## Core Value Proposition
Users can capture, search, and chat with their personal notes using AI — entirely locally — with no visible traces on the system and a security-gated launch process.

## Architecture Summary

```
User Layer
  CLI command (custom name) → access code gate → Khoj server

Application Layer
  Khoj (Python/Django) → REST API + Web UI on localhost:9371
  Anonymous mode → no per-user auth (secured by localhost binding + access code)

Data Layer
  PostgreSQL 17 + pgvector → structured storage + vector embeddings
  ~/.systemname/files/ → raw markdown/text note storage

Integration Layer
  Google Drive watcher (fswatch) → auto-import .md/.txt from iPhone
  Tailscale VPN → iPhone remote access
  Ollama / OpenAI / Anthropic → chat AI backends

Security Layer
  SHA-256 hashed access code → silent failure on wrong input
  Spotlight exclusion → .metadata_never_index markers
  Localhost-only binding → optional --remote for Tailscale
  chmod 600 → on .env and .grvmap files
```

## Tech Stack
| Component | Technology |
|-----------|-----------|
| AI Engine | Khoj (open-source, Python/Django) |
| Database | PostgreSQL 17 + pgvector |
| Language | Bash (installer + scripts) |
| File Watcher | fswatch |
| VPN | Tailscale |
| AI Models | Ollama (local) / OpenAI / Anthropic (cloud) |
| Package Manager | Homebrew, pipx |
| OS Service | macOS LaunchAgent |

## Target Platform
macOS only (Apple Silicon + Intel via Homebrew)
