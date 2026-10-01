# Frappe Framework Docs Guide

Start with the official documentation root:
- `https://docs.frappe.io/framework/`

## Focus Areas to Review Before Coding
- Framework overview and architecture
  - Understand Frappe's metadata-driven model, Desk UI, permissions, and built-in REST capabilities.
- Document and DocType behavior
  - Confirm where validation, defaults, child tables, and document lifecycle hooks should live.
- Database and query APIs
  - Prefer Frappe Query Builder and standard framework query helpers over raw SQL unless there is a justified need.
- API and integration patterns
  - Check how document resources, whitelisted methods, request data, and permission checks are expected to work.
- Client-side customization
  - Review established patterns for form scripts, dialogs, list views, and other Desk interactions.
- Files, permissions, and sharing
  - Verify whether the framework already provides supported APIs for attachments, sharing, or access control.
- Testing, patches, and migrations
  - Use the framework's testing and patch patterns when the change affects data model or upgrade behavior.
- Code quality and maintainability
  - Keep logic cohesive, readable, and easy to validate.

## Practical Questions to Answer
- Does Frappe already provide a built-in hook, API, helper, or query abstraction for this task?
- Should this logic live in a DocType controller, whitelisted method, client script, patch, hook, or report module?
- Can Frappe Query Builder express this query cleanly before using normal SQL?
- What permission checks should be preserved?
- Is there an existing implementation in `apps/frappe`, `apps/erpnext`, `apps/hrms`, or a sibling custom app that should be matched?
- What targeted test or validation proves the change is correct?

## Working Rules
- Prefer `frappe.get_doc`, `frappe.new_doc`, `frappe.db`, `frappe.qb`, `frappe.call`, and other standard framework APIs when they fit.
- Use Frappe Query Builder for joins, filters, aggregations, and report queries when practical.
- Avoid normal raw SQL unless Query Builder or framework helpers are insufficient and the reason is clear.
- Match HTTP methods and permission checks to existing framework behavior.
- Favor metadata and standard framework extension points over hardcoded workarounds.
- Keep functions small, names clear, and responsibilities separated.
- Validate against nearby code patterns in the workspace after reading the docs.
