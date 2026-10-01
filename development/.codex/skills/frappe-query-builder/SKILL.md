---
name: frappe-query-builder
description: "Guidelines for querying the database in Frappe using the Frappe Query Builder and ORM."
argument-hint: "Describe the query or data retrieval needed"
user-invocable: true
---

# Frappe Query Builder

Use this skill when reading, writing, or joining data in Frappe applications.

## Guidelines
- **Prefer ORM for Simple Queries:** For fetching single fields or simple lists, prefer `frappe.db.get_value()`, `frappe.get_all()`, and `frappe.get_list()`.
- **Use Query Builder over Raw SQL:** When doing complex aggregations, joins, or dynamic query construction, use the Frappe Query Builder (`frappe.qb`) rather than writing raw `frappe.db.sql` queries.
- **Security:** Query Builder automatically protects against SQL injection. If you must use raw SQL, always use parameterized queries (`%s`) and never concatenate strings into SQL queries.
- **Readability:** Query Builder allows building queries methodically. Name your tables clearly (e.g., `sales_invoice = frappe.qb.DocType("Sales Invoice")`) and separate complex conditions into distinct variables before assembling the final query.
- **Execution:** End Query Builder statements with `.run(as_dict=True)` to execute and fetch results in a standard Frappe-compatible dictionary format.

