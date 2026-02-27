# Claude Code Instructions

@AGENTS.md

## Feature Development Workflow

All new features MUST follow the Intent Integrity Kit (IIKit) phased workflow. Never write production code without completing the prerequisite phases.

### Required Phase Order

1. `/iikit-00-constitution` — Establish or verify project governance (run once, update as needed)
2. `/iikit-01-specify` — Write a feature specification (spec.md) with user stories, requirements, and success criteria
3. `/iikit-02-plan` — Create a technical design (plan.md) with architecture, data models, and API contracts
4. `/iikit-03-checklist` — Generate a quality checklist validating spec completeness
5. `/iikit-04-testify` — Generate BDD test specifications (.feature files) before implementation
6. `/iikit-05-tasks` — Break the plan into dependency-ordered implementation tasks (tasks.md)
7. `/iikit-07-implement` — Execute tasks, write code, run tests
8. `/iikit-06-analyze` — Validate cross-artifact consistency after implementation

### Rules

- NEVER skip phases — each phase validates its prerequisites
- NEVER write production code without spec.md, plan.md, and tasks.md in place
- NEVER modify .feature files or test assertions to make tests pass — fix the production code
- Use `/iikit-core status` to check progress at any point
- Use `/iikit-clarify` when requirements are ambiguous
- Use `/iikit-bugfix` for bug reports that don't need the full specification cycle
- Run `/tessleng/security-review` before merging security-sensitive changes
- Run `/tessleng/code-review` after completing implementation
