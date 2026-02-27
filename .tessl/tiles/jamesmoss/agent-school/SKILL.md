---
name: agent-school
description: Investigates a problem area in the codebase and finds or creates a tessl tile (rules, docs, skills) to teach agents how to handle it correctly. Use when agents keep making the same mistakes around a library, design pattern, or convention.
---

# Tile from Codebase

You are a tile author. Your job is to investigate a problem area in this codebase and either find an existing tessl tile or create a new one that permanently teaches agents how to handle it correctly.

A tessl tile can contain any combination of:

- **Steering rules** — loaded eagerly into every agent session. Best for conventions, patterns, and standards agents must always follow.
- **Docs** — loaded on-demand when agents query for library information. Best for API references, version-specific behavior, and usage guides.
- **Skills** — loaded when relevant to the user's request. Best for repeatable multi-step workflows.

Your output is not an explanation to the user. Your output is a **tile** — either an existing one from the registry or a new one — installed into the project that will steer all future agents.

## Phase 1: Interview the User

Start by understanding what the user is experiencing. Parse their initial prompt, then ask clarifying questions. You need to understand:

1. **What specific mistakes are agents making?** Get concrete examples if possible — wrong function calls, incorrect patterns, misused APIs, etc.
2. **Can they point to examples?** Ask for file paths showing the correct approach, or descriptions of the wrong behavior they've seen.
3. **What is the scope?** Is this problem specific to one app or project-wide?
4. **What does "correct" look like?** How should agents handle this area? Are there existing examples of the right approach in the codebase?

Do not skip this phase. Ask your questions, wait for answers, then proceed.

## Phase 2: Search the Tessl Registry

Before building anything from scratch, search for existing tiles that might already solve the user's problem.

### 2a: Formulate Search Queries

Based on the user's answers, identify key search terms. Think about:

- The library or framework name (e.g. `drizzle`, `react`, `tailwind`)
- The specific pattern or concept (e.g. `migrations`, `auth`, `error handling`)
- The tool or API involved (e.g. `zod`, `trpc`, `prisma`)

Run **multiple searches** using the `tessl search` MCP tool to cast a wide net. For example, if the user is having trouble with Drizzle migrations, search for `drizzle`, `drizzle migrations`, and `database migrations`.

### 2b: Evaluate Results

For each search result, consider:

- Does the tile's summary indicate it addresses the user's specific problem?
- Is it a docs tile for the right library/version?
- Does it include steering rules or skills relevant to the problem area?

### 2c: Present Findings to the User

Present any promising tiles to the user with:

- The tile name and summary
- Why you think it might be relevant
- The install command

If **no relevant tiles are found**, tell the user and move on to Phase 3.

If **relevant tiles are found**, ask the user:
- Would they like to install any of these existing tiles?
- Do they feel the existing tile fully covers their problem, or do they also need a custom tile?

### 2d: Install Existing Tiles (if chosen)

If the user wants to install an existing tile, use the `tessl install` MCP tool:

```
tessl install <workspace>/<tile-name>@<version>
```

After installing, run `tessl status` to confirm it's active. If the user is satisfied that the existing tile fully addresses their problem, you're done — skip to Phase 4 (Verify).

If the user wants a custom tile in addition to (or instead of) the existing ones, proceed to Phase 3.

## Phase 3: Create a New Tile

If no existing tile solves the problem, or the user needs a custom tile for their specific codebase:

### 3a: Install the Tile Creator

Install the `tessleng/tile-creator` tile which provides a dedicated skill for authoring new tiles:

```
tessl install tessleng/tile-creator
```

### 3b: Invoke the Tile Creator Skill

Once installed, invoke the `tile-creator` skill. It will guide you through the full process of:

- Investigating the codebase for patterns and examples
- Checking existing tiles and rules for overlap
- Designing the tile structure (rules, docs, skills)
- Creating the tile files
- Registering and installing the tile

Pass along all the context you gathered in Phase 1 (the user's answers, specific examples, scope, etc.) so the tile creator has everything it needs.

**Important:** Do not manually create tile files yourself. The `tessleng/tile-creator` skill is purpose-built for this and will produce higher-quality, correctly-structured tiles.

## Phase 4: Verify

1. Run `tessl status` to confirm the tile is recognized and installed
2. Check the relevant `.tessl/RULES.md` to confirm steering rules appear (if applicable)
3. Tell the user the tile is ready and summarize what it contains

## Important Notes

- **Always search the registry first** — don't reinvent the wheel if a well-maintained tile already exists
- When searching, try **multiple query variations** — different phrasings may surface different results
- If an existing tile partially covers the problem, consider installing it **and** creating a supplementary custom tile for the project-specific parts
- Always use **real code examples** from the codebase when creating custom tiles, not generic examples
- Keep steering rules **concise** — they're loaded into every agent session and consume context
- The tile should be **self-contained** — an agent reading it should understand the rules without needing to ask follow-up questions
