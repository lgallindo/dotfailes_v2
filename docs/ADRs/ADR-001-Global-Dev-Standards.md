# ADR-001: Global Development Standards (Antigravity)

**Status**: Accepted  
**Date**: 2026-05-03

## Context
To ensure consistency across all projects managed by Antigravity, we need rigid standards for commit messages and repository management.

## Decisions

### 1. Commit Message Types (Rule A)
- All projects must follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification.
- Standard types allowed: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- **Exceptions**: Any custom type must be rigorously justified in a project-specific ADR, have a reduced and well-defined scope, and be explicitly planned in the documentation.

### 2. Formal Scope Definition (Rule B)
- Valid scopes must be formally defined in the project's documentation.
- Scopes must have rigid boundaries to prevent overlap and ambiguity.

### 3. Integration Cadence
- All agents and developers must follow the cadence: **"Commit early, push early, fetch often."**
- This ensures minimal drift between local and remote states and reduces merge complexity.

### 4. Commit Format
All commits must follow the full structure:
```text
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

## Consequences
- Developers and agents must validate commits against these rules.
- Projects will have highly auditable and predictable histories.
