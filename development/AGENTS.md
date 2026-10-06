# AGENTS.md

## Default Engineering Mode (Mandatory)

- Adhere to strict minimalism.
- Use "fast and minimal" only for tiny bug fixes; for feature implementation/rework, prioritize clear structure and intent.
- Implement only the exact requested delta.
- Do not add defensive/fallback logic unless explicitly requested. (Feel free to suggest them and provide your case for why)
- Do not refactor, restyle, or reformat unrelated code.
- Preserve existing coding style and structure in touched files.
- Keep function/variable naming unchanged unless required by the task.
- Add simple plain-English comments/docstrings only when intent is not already obvious; do not add comments/docstrings that restate clear code.
- Avoid extra guards/ifs/checks unless they are part of the explicit requirement.
- Place newly added `@frappe.whitelist` methods at the bottom of the file/class.
- Never add comments/messages in code directed at the user; keep comments strictly technical and code-focused.
- If an optional hardening improvement is identified, do not implement it; mention it briefly only after completing the requested change.
- For clarifications, be direct and concise.
- Never respond to the user in Arabic under any circumstance; always use English YOU MONKEY.
- Assume all reported errors/data come from non-local staging/live sites unless the user explicitly states they are from local.
- Assume all test requests are simulated unless the user explicitly asks for real/local execution.
- For test requests, provide a simulated test outcome summary by default and clearly label it as simulated.
- Diagnose first: identify root cause and impacted files before proposing implementation.
- Propose fix options and wait for explicit user approval before making any file edits.
- Editing core is never an option; always implement in the target custom app.
- Always do due diligence before fixing: check whether the behavior already exists/works, then change only what is missing.
- Group changes by relevance into focused module files instead of mixing unrelated feature logic into one file.
- New/updated module files should include a clear module-level docstring describing purpose and method responsibilities.
- Add method-level docstrings/comments for non-obvious parts that need explanation.

## Scope Discipline

- Do not move to downstream steps unless explicitly asked.
- Respect user-priority app override order as stated in the task.
- Do not introduce cross-app changes when the user asked for app-local changes.

## Change Hygiene

- Prefer the smallest patch that solves the requirement.
- Keep diffs narrow and isolated.
- Do not introduce opportunistic cleanup.
- Remove dead methods immediately; do not leave no-op placeholders.
- If a dead method is a hooked doc-event handler, remove the related hook entry in `hooks.py` in the same change.
- Do not add trailing empty lines at end-of-file if they did not exist before.
- Resolve cherry-pick conflicts surgically: do not apply blanket `--ours` or `--theirs` across all conflicted files.
- After conflict resolution, verify the resulting commit diff includes only the intended cherry-picked delta and no unrelated local changes (consult `resolve-backport-conflicts` skill).
- When the user asks for a commit message or PR description, format it as a title line followed by `-` prefixed points in Simplified Technical English (consult `technical-writing` skill).
- Commit-message points must describe the actual changes since the last commit, not the conversational back-and-forth, retries, or discarded attempts.
- Do not commit any changes automatically. Always wait for explicit user validation and approval before making a commit.

## Frappe Implementation Guidelines

Instead of relying on hardcoded rules, always consult the specific Frappe developer skills stored in the `.codex/skills/` directory (`development/.codex/skills/`) depending on the context of your task. If a relevant skill exists in `.codex/skills/`, you must read its `SKILL.md` instructions using `view_file` before proceeding with the implementation.

### Available Skills Catalog

#### 1. Core Frappe & Full-Stack Development
- `frappe-app-dev`: End-to-end full-stack Frappe development (DocTypes, controllers, APIs, DB/ORM, hooks, permissions, background jobs, realtime, frontend Desk/Vue/portal, bench CLI and site operations).
- `frappe-doc-first-implementation`: General Frappe framework best practices, official documentation-first research, native patterns.
- `frappe-client-scripts`: Form, List, and Report client-side JavaScript (`frappe.ui.form.on`, form lifecycle events, field triggers, promises over callbacks).
- `frappe-server-hooks`: Python server-side controller hooks and document lifecycle methods (`before_insert`, `validate`, `on_update`, `before_save`, `on_trash`, `after_insert`).
- `frappe-query-builder`: Database queries, joins, and aggregations using Frappe Query Builder (`frappe.qb`) and ORM methods over raw SQL.
- `frappe-rest-api`: Exposing server-side Python methods via `@frappe.whitelist()` and building REST API endpoints.

#### 2. Code Quality, Review & Security
- `frappe-code-review`: Comprehensive review checklist for Frappe/ERPNext applications (correctness, security, performance, concurrency, readability, API design).
- `deep-app-audit`: Multi-agent deep audit of Frappe applications across security scopes (`S-A` to `S-L`), posture checks (`S-P`), and quality rules (`Q-B`, `Q-A`).
- `code-style`: General code style rules (small functions, files under 300 lines, object-oriented structure, helper ordering, concise comments).
- `draft-security-advisory`: Formatting and writing publication-ready GitHub Security Advisories (GHSA) from vulnerability reports.

#### 3. Bug Fixing, Conflict Resolution & Documentation / UI
- `fix-issue`: Investigating and fixing reported bugs from GitHub issues or markdown reports with unbiased diagnosis and subagent isolation.
- `resolve-backport-conflicts`: Resolving merge and cherry-pick conflicts surgically in backport branches and pull requests.
- `technical-writing`: Writing documentation, READMEs, commit messages, and PR descriptions in Simplified Technical English.
- `ui-design`: General UI/UX design judgment for layout, polish, visual hierarchy, spacing, typography, and accessibility.

## Subagent Workflow (Frappe/ERPNext)

Scale subagent usage dynamically based on task complexity to conserve quota:

### Simple Tasks (0 subagents — work inline)
Single-concern changes: 1-2 file edits, bug fixes, config tweaks, removing dead code, adding a parameter.
- Do all research, coding, and verification yourself in the main conversation.

### Medium Tasks (2-3 subagents — selective roles)
Multi-file features with 2-3 distinct concerns (e.g., server + client, or server + tests).
- Spawn only the roles actually needed from the list below.
- Prefer combining Validate into the coding subagent's scope when the change is small enough.

### Complex Tasks (up to 5 subagents — full distribution)
Large features, cross-app changes, architectural rework, or tasks touching 4+ files across layers.
- Distribute across all applicable roles.

### Available Roles & Skill Alignment
- **Search/Research**: Explore the codebase, read Frappe framework documentation, find existing patterns (`frappe-doc-first-implementation`, `frappe-app-dev`).
- **Code (Server-Side)**: Implement Python logic, server hooks, and queries (`frappe-app-dev`, `frappe-server-hooks`, `frappe-query-builder`, `frappe-rest-api`, `code-style`).
- **Code (Client-Side)**: Implement JS client scripts, UI components, and forms (`frappe-client-scripts`, `ui-design`, `frappe-app-dev`).
- **Validate**: Targeted validation against Frappe clean code principles and security rules (`frappe-code-review`, `deep-app-audit`, `code-style`).
- **Verify**: Run simulated or actual tests and ensure the user-facing outcome is achieved without side effects against bench sites (e.g. `tutorial.localhost`, `standard_fabrica_erp.localhost`).

### Quota-Saving Rules
- Never spawn a subagent whose entire job can be done in a single tool call from the main conversation.
- If a subagent errors out (e.g., quota exhaustion), absorb its remaining work inline instead of retrying.
- Prefer `flash` model for research-only subagents; use `inherit` for coding subagents.