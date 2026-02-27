# Agent School

![Agent School](https://raw.githubusercontent.com/jamesmoss/skills/main/agent-school/assets/agent-school-robot.png)

**Agent School** turns recurring agent mistakes into permanent, project-specific
guidance. When agents keep getting something wrong—a library, a design pattern,
or a convention—you use this skill to investigate the problem and either find an
existing tile in the Tessl registry or create a new one that teaches all future
agents how to handle it correctly.

## Installation

Install via tessl:

```bash
tessl install jamesmoss/agent-school
```

**After you run Agent School:** if a new tile is created, it becomes part of your repo. Run `tessl install` in the project so steering rules are merged into `.tessl/RULES.md` and the new rules, docs, and skills become active.


## What it does

The skill walks you through a structured, four-phase process:

1. **Interview** — Clarify what's going wrong: concrete mistakes, examples, scope, and what "correct" looks like.
2. **Search the Registry** — Search the Tessl registry for existing tiles that already solve the problem. If a relevant tile is found, install it and you're done.
3. **Create a New Tile** — If no existing tile fits, install the `tessleng/tile-creator` skill and invoke it to investigate the codebase, design the tile, and generate all the files.
4. **Verify** — Confirm the tile is installed and that steering rules (if any) appear in `.tessl/RULES.md`.

The output is a **tessl tile** — either from the registry or newly created — installed in your project: steering rules (always loaded), docs (on-demand), and/or skills (when relevant). That tile then steers every future agent session in that project.

## When to use it

Use Agent School when:

- Agents keep making the same mistakes around a library, API, or pattern.
- You want to codify project conventions or standards so agents follow them.
- You need repeatable, multi-step workflows (e.g. "how we add API endpoints") captured as skills.
- You want to check if there's already a community tile that addresses your problem before building from scratch.

