# Commit Messages (dotfailes_v2)

All commit messages must strictly follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification and the global rules defined in [ADR-001](ADRs/ADR-001-Global-Dev-Standards.md).

## Format

```text
<type>(<scope>): <subject>

[body]

[footer(s)]
```

## Allowed Types

- `feat`: New feature (e.g., new command in `dots.sh`).
- `fix`: Bug fix (e.g., config parsing bug).
- `docs`: Documentation changes only.
- `style`: Formatting, semicolons (no logic change).
- `refactor`: Code change that neither fixes a bug nor adds a feature.
- `perf`: Performance improvement.
- `test`: Adding or correcting tests.
- `build`: Changes to the build system or external dependencies.
- `ci`: Changes to CI configuration files and scripts.
- `chore`: General maintenance that doesn't affect source code or tests.
- `revert`: Reverting a previous commit.

## Formal Scope Definition (Rule B)

The following scopes are allowed to ensure rigid boundaries:

| Scope | Boundary / Definition |
| :--- | :--- |
| `bash` | Logic exclusive to the `dots.sh` script. |
| `zsh` | Logic exclusive to the `dots.zsh` script. |
| `pwsh` | Logic exclusive to the `dots.ps1` script. |
| `install` | Logic exclusive to the `install.sh` script. |
| `core` | Shared logic or root directory structures. |
| `config` | Manipulation and validation of the `config.json` file. |
| `docs` | Exclusive changes to Markdown files in the `docs/` folder. |
| `test` | Test infrastructure, `.bats` files, and runners. |

## Additional Rules

1. **Strict Staging**: Use of `git add .` or `git add -A` is prohibited. All files must be listed explicitly.
2. **Imperative**: The `subject` must be in the imperative mood ("add", not "added").
3. **Body**: Use the commit body to explain the "why" of the change, especially for complex refactors.
