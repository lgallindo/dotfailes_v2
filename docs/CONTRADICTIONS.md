# Git Flow Contradictions

Below are the identified contradictions between the original English and Portuguese versions, along with structural redundancies.

| ID         | Topic               | English Version                         | Portuguese Version                      | State      | Initial Proposal                                                                                                       | Final Resolution                                                                 |
| :--------- | :------------------ | :-------------------------------------- | :-------------------------------------- | :--------- | :--------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------- |
| **GIT-C01**| Branch Prefixes     | Lists `feat/`, `docs/`, etc.            | Lists `feat/`, `fix/`, etc.             | **Resolved**| **dotfailes_v2**: engineering types. <br> **lean_papers**: Mathlib style + research types.                             | Strategic differentiation and alphabetical order applied to all documents.       |
| **GIT-C02**| Staging Policy      | No mention of `git add` restrictions.   | Strictly forbids `git add .`.           | **Resolved**| Explicitly prohibit `git add .` and `git add -A`, requiring explicit file listing.                                     | Documented in `GIT_FLOW.md` and `COMMIT_MESSAGES.md`.                            |
| **GIT-C03**| Claim Lifecycle     | No mention of status updates.           | Forbids deletion, requires status.      | **Resolved**| Force strict mode: prohibition of deletion and mandatory status updates.                                               | Implemented in the Agent Coordination section.                                   |
| **GIT-C04**| Push Order          | No detail on push order.                | Topic push BEFORE develop push.         | **Resolved**| Force strict mode: Topic push always precedes develop push.                                                         | Reflected in the "Standard Workflow" section.                                    |
| **GIT-C05**| Remote Evaluation   | No mention of remote build check.       | Requires explicit integrity evaluation. | **Resolved**| Force strict mode: Mandatory explicit remote integrity evaluation.                                                     | Integrated as a mandatory step before pushing.                                   |
| **GIT-C06**| Doc Redundancy      | N/A                                     | Policies spread across root and `docs/`.| **Resolved**| Move all policy and maintenance documents from root to `docs/`, centralizing technical truth.                          | Documents moved to `docs/` in origin repo and references updated.                |

---

### Global Antigravity Rules (ADR-001)

The following global rules have been implemented in both repositories via [ADR-001](ADRs/ADR-001-Global-Dev-Standards.md):

1. **Rule A (Types)**: Strict use of Conventional Commits. Exceptions must be justified in an ADR.
2. **Rule B (Scopes)**: Scopes must have rigid boundaries and formal definitions.

Commit messages now follow the full format:
```text
<type>(<scope>): <subject>

<body>

<footer>
```

---

### Observation on the "Root Policy"
The English version is now the primary documentation for `dotfailes_v2` to maintain consistency with the "all English" rule.
