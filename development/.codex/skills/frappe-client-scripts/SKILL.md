---
name: frappe-client-scripts
description: "Guidelines for writing Frappe client scripts (JavaScript) for Forms, Lists, and Reports."
argument-hint: "Describe the client script or UI behavior to implement"
user-invocable: true
---

# Frappe Client Scripts

Use this skill when implementing JavaScript client-side behavior in Frappe and ERPNext.

## Guidelines
- **Use Form API:** Use `frappe.ui.form.on("DocType", ...)` to bind form events.
- **Trigger Events:** Utilize standard trigger points such as `onload`, `refresh`, `validate`, `before_save`, `after_save`, and field-specific changes.
- **Promises over Callbacks:** When calling server-side methods with `frappe.call`, wrap logic cleanly using promises where applicable, or keep the `callback` neat.
- **Frappe Dialogs:** Use `frappe.ui.Dialog`, `frappe.msgprint`, `frappe.confirm`, and `frappe.prompt` for user interactions instead of native browser popups.
- **Avoid Direct DOM Manipulation:** Use `frm.set_value()`, `frm.set_df_property()`, `frm.toggle_display()` and other Frappe Form APIs instead of raw jQuery or `document.getElementById` whenever possible.
- **Child Tables:** Iterate over child tables using `frm.doc.child_table_fieldname.forEach(row => { ... })` and use `frappe.model.set_value(row.doctype, row.name, ...)` to update row fields safely.

