---
name: frappe-server-hooks
description: "Guidelines for writing Frappe server-side DocType hooks and Python controller logic."
argument-hint: "Describe the server-side logic or document lifecycle behavior to implement"
user-invocable: true
---

# Frappe Server Hooks

Use this skill when implementing Python server-side logic, controller hooks, or document lifecycle methods in Frappe.

## Guidelines
- **Controller Hooks:** Implement logic within standard controller hooks such as `before_insert`, `validate`, `on_update`, `before_save`, `on_trash`, and `after_insert`.
- **Avoid Hardcoding:** Use `frappe.db.get_single_value()` for fetching settings, and avoid hardcoding statuses or configuration keys.
- **Validation:** Raise appropriate exceptions for validation failures using `frappe.throw()` or specific exceptions like `frappe.ValidationError` instead of generic Python `Exception`.
- **Translations:** Wrap all user-facing strings in `_("Your string")` to ensure the application remains translatable.
- **Permissions:** Rely on standard Frappe permission structures. Use `frappe.has_permission()` if explicit checks are necessary, and respect the `ignore_permissions=False` flag by default.
- **Context:** Remember that inside controller methods, `self` refers to the current Document instance. Use `self.get("child_table")` or `self.set()` to safely manipulate document state.

