---
name: frappe-doc-first-implementation
description: "Implement or modify Frappe, ERPNext, HRMS, and custom app code the Frappe way. Use when adding APIs, DocTypes, client scripts, permissions, tests, reports, or patches. First review official docs at docs.frappe.io/framework, inspect nearby workspace code, prefer Frappe Query Builder over raw SQL, apply clean code principles, then implement and validate."
argument-hint: "Describe the Frappe change to implement or review"
user-invocable: true
---

# Frappe Doc-First Implementation

Use this skill before implementing or changing code in Frappe-based apps so the solution follows standard Frappe framework conventions, prefers framework-native database access, and stays clean and maintainable.

## When to Use
- Implementing or updating code in `frappe`, `erpnext`, `hrms`, or custom Frappe apps
- Adding or changing whitelisted APIs, DocType logic, hooks, permissions, client scripts, reports, tests, or patches
- Reviewing an implementation when you are unsure whether Frappe already provides a standard mechanism
- Comparing a planned change against official framework guidance before editing code
- Refactoring Frappe code to replace raw SQL patterns or unclear business logic

## Workflow
1. Clarify the requested change.
   - Identify the app, module, doctype, endpoint, report, user flow, and whether the change is server-side, client-side, schema, permissions, query, or test related.
2. Read official Frappe docs first.
   - Start at `https://docs.frappe.io/framework/`.
   - Review the section most relevant to the task before editing code.
   - Use [Frappe docs guide](./references/frappe-framework-docs.md) to narrow the topic.
3. Inspect local workspace patterns.
   - Read adjacent files in the same module.
   - Compare with similar implementations in `apps/frappe`, `apps/erpnext`, `apps/hrms`, or sibling custom apps.
   - Prefer existing framework-aligned patterns already used in the workspace.
4. Choose the standard Frappe mechanism.
   - Use DocType controller methods for document lifecycle rules.
   - Use form scripts or client-side code for Desk UI behavior.
   - Use whitelisted methods or documented REST patterns for integrations.
   - Use Frappe Query Builder or standard framework query helpers before considering raw SQL.
   - Use hooks, patches, or custom fields only when they are the right framework mechanism.
   - Use permission and sharing APIs instead of bypassing framework checks.
5. Implement the smallest framework-native clean change.
   - Reuse existing helpers and utilities.
   - Prefer metadata-driven behavior when feasible.
   - Keep functions focused and names intention-revealing.
   - Avoid duplication, hidden side effects, and deeply nested logic when a clearer structure is available.
   - Avoid duplicating features already provided by Frappe.
6. Validate the result.
   - Run targeted tests or verification for the affected flow.
   - Check permissions, side effects, backward compatibility, and query behavior.
   - Re-read the final change and confirm it still matches the documented pattern.

## Decision Points
- If the docs describe a first-class framework feature, use it before creating custom plumbing.
- If data retrieval or reporting logic is needed, prefer Frappe Query Builder first and use raw SQL only when clearly justified.
- If raw SQL seems necessary, confirm why Query Builder or standard ORM helpers are insufficient.
- If the change affects document lifecycle behavior, prefer controller hooks such as `validate`, `before_insert`, `after_insert`, or `on_update` over scattered call sites.
- If the change exposes data externally, verify request parsing, permissions, and HTTP method expectations.
- If the change is UI behavior, follow existing Frappe form, dialog, list, or view patterns.
- If the change touches schema or metadata, decide whether it belongs in DocType fields, Custom Fields, or a patch/migration.
- If the docs are too broad, inspect framework source and nearby examples before inventing a new pattern.

## Clean Code Expectations
- Prefer small functions with a single clear responsibility.
- Use expressive names for methods, variables, and intermediate query parts.
- Separate query construction, business rules, and response formatting when practical.
- Remove dead code, debug prints, and duplicated branches.
- Keep permission checks and validation explicit.
- Prefer readable framework primitives over clever shortcuts.

## Completion Checks
- Official Frappe docs were reviewed before code changes.
- Relevant nearby workspace files were inspected.
- A framework-native pattern was chosen.
- Frappe Query Builder or standard query helpers were considered before raw SQL.
- Permissions and lifecycle hooks were considered.
- Clean code principles were applied to the final implementation.
- Tests or targeted validation were completed.
- The solution does not bypass standard Frappe APIs without a strong reason.

## Inputs to Capture
- App or module name
- Doctype, API, report, or function being changed
- Expected user-facing outcome
- Whether data access or aggregation is involved
- Validation steps or tests to run
