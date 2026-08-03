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
- After conflict resolution, verify the resulting commit diff includes only the intended cherry-picked delta and no unrelated local changes.
- When the user asks for a commit message, format it as a title line followed by `-` prefixed points.
- Commit-message points must describe the actual changes since the last commit, not the conversational back-and-forth, retries, or discarded attempts.