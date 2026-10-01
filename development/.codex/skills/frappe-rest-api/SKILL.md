---
name: frappe-rest-api
description: "Guidelines for building whitelisted methods and REST APIs in Frappe."
argument-hint: "Describe the API endpoint or webhook to implement"
user-invocable: true
---

# Frappe REST API and Whitelisted Methods

Use this skill when exposing server-side Python methods to the client-side UI or external consumers via API.

## Guidelines
- **Whitelisting:** Expose methods by decorating them with `@frappe.whitelist()`. Ensure these methods are placed logically at the bottom of the file or in a dedicated API module.
- **Authentication Check:** `whitelist` allows authenticated access by default. If the endpoint needs to be public, use `@frappe.whitelist(allow_guest=True)` with extreme caution and explicit security checks.
- **Response Format:** Let Frappe handle the JSON serialization. Return Python dictionaries or lists directly, or populate `frappe.response['message'] = ...` when returning complex payloads.
- **HTTP Methods:** Be mindful of side effects. If a whitelisted method modifies data, it should ideally be restricted to POST requests (though Frappe supports GET by default unless strictly typed).
- **Input Validation:** Always validate arguments passed into the whitelisted method. Do not trust client inputs implicitly.
- **Documentation:** Provide clear docstrings explaining the required parameters, the expected response, and any error conditions that may be thrown.

