# remember-everything-locally-super-duper-securly Premise

## What

A private, local AI memory system for macOS built on Khoj. It provides a stealth, offline-first personal knowledge base where users can capture, store, search, and chat with their notes using AI — entirely on their own machine with no cloud dependencies. Notes are ingested via file drops, Google Drive auto-import from iPhone, and keyboard-shortcut-triggered capture (text, screenshots, audio).

## Who

Privacy-conscious individuals who want a personal AI-powered second brain. People who capture thoughts, meeting notes, voice memos, screenshots, and research throughout the day and need instant retrieval via semantic search and AI chat. Primary platform is macOS with iPhone as a secondary input device.

## Why

Existing note-taking and AI tools require cloud storage, expose personal data to third parties, or lack multimodal capture. This system solves the problem by keeping everything local — no Docker, no cloud APIs required, no visible app traces — while still providing powerful AI-powered search and conversation over personal notes. The stealth design ensures the memory system remains invisible to casual observers.

## Domain

Personal knowledge management (PKM) and AI-assisted recall. Key terms:
- **Memory**: A single captured unit of information (text, screenshot, voice note)
- **Access code**: A 6-character secret required to launch the system
- **Stealth mode**: No dock icon, no menu bar item, no Spotlight indexing
- **Ingestion**: The process of adding content to the searchable knowledge base
- **Re-index**: Triggering the AI engine to process newly added files

## Scope

**In scope:**
- macOS desktop application (CLI + background services)
- Local AI engine (Khoj) with PostgreSQL + pgvector
- Multi-modal memory capture (text, screenshots, audio with transcription)
- Google Drive auto-import pipeline for iPhone voice notes
- Tailscale-based iPhone remote access to web UI
- Stealth operation (hidden directories, access code gate, Spotlight exclusion)

**Out of scope:**
- Windows or Linux support
- Multi-user or team collaboration
- Cloud-hosted deployment
- Native iOS or Android applications
- Plugin or extension ecosystem
