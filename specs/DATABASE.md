# Database Specification

## Engine
PostgreSQL 17 (or 16, auto-detected) with pgvector extension.

## Installation
1. Installer checks for existing PostgreSQL 17 or 16
2. Installs PostgreSQL 17 via Homebrew if not found
3. Installs pgvector via Homebrew
4. Symlinks pgvector extension files into PostgreSQL's extension directory:
   - `vector.control` → PostgreSQL extension dir
   - `vector*.sql` → PostgreSQL extension dir
   - `vector.dylib` → PostgreSQL lib dir
5. Starts PostgreSQL service via `brew services`
6. Creates `khoj` database owned by current macOS user

## Connection Details
| Parameter | Value |
|-----------|-------|
| Host | localhost |
| Port | 5432 |
| Database | khoj |
| User | (macOS username) |
| Password | (empty — peer auth) |
| Connection | Unix socket (local) |

## Schema
Managed entirely by Khoj/Django migrations. The installer does not create any tables directly.

Khoj uses Django ORM with these key models (managed by Khoj, not this project):
- Note content and metadata
- Vector embeddings (via pgvector)
- Chat history
- Admin users and sessions
- Content source configuration

## pgvector
Enables semantic search over notes via vector similarity. Khoj automatically:
1. Generates embeddings when indexing notes
2. Stores embeddings in pgvector columns
3. Performs similarity search for chat context retrieval

## Backup Considerations
- Database: standard `pg_dump` of the `khoj` database
- Notes: file copy of `~/.systemname/files/`
- Config: copy of `~/.systemname/config/khoj.env`
- Access code: copy of `~/.systemname/.sys/.grvmap`

## Known Issues
- pgvector symlink approach is fragile across Homebrew updates
- No automated backup mechanism
- No database migration tooling beyond what Khoj provides
- PostgreSQL runs as a shared Homebrew service (not isolated)
- No connection pooling configuration
