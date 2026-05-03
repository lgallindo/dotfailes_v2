# Auditable Git Flow

This repository uses an auditable variant of Git Flow to preserve technical decisions, adversarial reviews, and parallel work by devtime agents.

## Branch Policy

- `develop` is the daily integration branch.
- `main` is the stable handoff branch and receives explicit merge commits from `develop`.
- Topic work happens on named branches such as `chore/<name>`, `docs/<name>`, `feat/<name>`, `fix/<name>`, `perf/<name>`, `refactor/<name>`, `scripts/<name>`, or `test/<name>`.
- Topic branches are merged into `develop` with explicit merge commits: `git merge --no-ff <branch>`.
- `develop` is integrated into `main` with explicit merge commits when a stable checkpoint is reached.
- Squash merges are not used.
- Fast-forward merges are avoided for topic integration to preserve the reviewable boundary in the graph.
- Integrated branches are not deleted.
- Shared history is not rewritten.

## Staging & Commit Policy (GIT-C02)

- Commits must be topical, specific, and reviewable.
- Use the format documented in [COMMIT_MESSAGES.md](COMMIT_MESSAGES.md).
- **Strict Staging**: It is strictly forbidden to use `git add .` or `git add -A`.
- List all files explicitly in the stage: `git add -- <file-1> <file-2>`.
- A commit should include only the minimum coherent subset for the topic.

## Worktree Policy

- Each active branch must have a dedicated local worktree when there is more than one devtime agent or active line of work.
- Worktrees are created from `develop` unless a different base is documented in the branch claim.
- Recommended local layout:
  - `/mnt/d/code/dotfailes_v2`: primary checkout.
  - `/mnt/d/code/dotfailes_v2-worktrees/develop`: integration worktree.
  - `/mnt/d/code/dotfailes_v2-worktrees/<branch-slug>`: one worktree per active branch.
- Before editing a worktree, verify ownership and status: `git worktree list`, `git branch -vv`, `git status --short --branch`.
- Do not reuse a dirty worktree from another agent.
- Removing a completed worktree only removes the local checkout; it does not remove the branch.

## Agent Coordination

- Devtime agents coordinate through Git, dedicated worktrees, explicit commits, and versioned claims in `docs/coordination/claims/`.
- Each active branch must have a claim file: `docs/coordination/claims/<branch-slug>.md`.
- The claim records owner, machine, timestamp, worktree, scope, expected files, excluded files, validation, and handoff.
- `docs/coordination/claims/TEMPLATE.md` is a template, not an active claim.
- **Lifecycle (GIT-C03)**: Claims must not be deleted as cleanup; update the status to `integrated`, `superseded`, or `abandoned` when applicable.

## Standard Workflow

1. Update `develop`.
2. Create or enter the dedicated branch worktree.
3. Create or update the branch claim in `docs/coordination/claims/`.
4. Make small, topical, and traceable commits.
5. Run the appropriate validation for the scope.
6. **Remote Evaluation (GIT-C05)**: Explicitly evaluate if the push will preserve remote integrity.
7. **Topic Push (GIT-C04)**: Push the topic branch BEFORE integration.
8. Integrate into `develop` with `git merge --no-ff <branch>`.
9. **Develop Push**: Push `develop` after topic integration.
10. Do not delete the topic branch.
