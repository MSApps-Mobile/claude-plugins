---
name: wp-admin
description: >
  WordPress site administration through the MCP Adapter. Use when the user asks to
  "check site status", "manage users", "update settings", "check plugins",
  "review site health", "manage comments", "check WordPress version",
  "list users", "change site settings", "manage menus", "check SEO settings",
  or any request about WordPress administration, configuration, users, or site health.
  Also trigger on: "תבדוק את האתר", "סטטוס האתר", "ניהול משתמשים".
---

# WordPress Site Administration

Administer WordPress sites — users, settings, plugins, themes, comments, menus, and site health.

## Discovery-First Approach

The WordPress MCP Adapter exposes only abilities explicitly flagged as public. Always discover available abilities before attempting operations. Not all sites expose admin-level abilities.

1. Run **discover abilities** to get the full list
2. Filter for admin-related abilities (users, settings, plugins, themes, options)
3. If an expected ability is missing, inform the user it may need to be enabled in the MCP Adapter settings

## User Management

### Listing Users
- Execute `core/list-users` to see all site users
- Filter by role: `administrator`, `editor`, `author`, `contributor`, `subscriber`

### User Details
- Use `core/get-user` with user ID for full profile info
- Check roles, email, registration date, post count

### Modifying Users
- Update user roles, display names, or metadata via `core/update-user`
- Never change passwords through the API — instruct the user to do this from the WordPress admin panel

## Site Settings

### Reading Settings
- `core/get-settings` returns site title, tagline, URL, timezone, date/time format, language
- Present settings in a readable table format

### Updating Settings
- Use `core/update-settings` to change site-level options
- Always confirm changes with the user before executing — settings changes affect the entire site
- Critical settings to handle carefully: site URL, permalink structure, reading settings

## Plugin Management

### Listing Plugins
- `core/list-plugins` shows all installed plugins with status (active/inactive)
- Report version numbers and update availability

### Plugin Operations
- Activate/deactivate plugins via `core/update-plugin`
- Never delete plugins without explicit user confirmation
- Warn about deactivating critical plugins (security, SEO, caching)

## Theme Management

- `core/list-themes` shows installed themes
- `core/get-active-theme` shows the current theme
- Theme switching should always be confirmed with the user — it can break the site layout

## Comment Management

- `core/list-comments` with filters for status (approved, pending, spam, trash)
- Bulk moderate: approve, spam, or trash comments
- When reviewing pending comments, present them with author, content preview, and the post they're on

## Site Health

When asked about site status or health:

1. Check WordPress version via site info abilities
2. List plugins and flag any that need updates
3. Check active theme version
4. Report user count by role
5. Note any pending comments that need moderation

## Safety Guidelines

- Always confirm destructive actions (delete users, deactivate plugins, change permalinks)
- Never expose sensitive data like user emails or passwords in responses
- Suggest backups before major changes (theme switches, major plugin changes)
- If the site has a caching plugin, remind the user to clear cache after changes

## Reference

See `references/wp-roles-capabilities.md` for the WordPress role and capability system.
