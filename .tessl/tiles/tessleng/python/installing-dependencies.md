# Installing dependencies

- Always use `uv add` to install the LATEST version of dependencies. 
- Never edit `pyproject.toml` directly when adding dependencies.
- Whenever you install a new dependency, use the tessl mcp `search` tool to look for corresponding documentation and the tessl mcp `install` tool to install any matching docs.

## Preferred dependencies

- Use Typer for CLI functionality