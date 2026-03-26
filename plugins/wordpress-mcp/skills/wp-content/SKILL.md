---
name: wp-content
description: >
  Manage WordPress content through the MCP Adapter. Use when the user asks to
  "create a post", "edit a page", "publish content", "update my WordPress site",
  "draft a blog post", "manage media", "list my pages", "check recent posts",
  or any request involving WordPress posts, pages, media, categories, or tags.
  Also trigger on Hebrew: "תעדכן את האתר", "תכתוב פוסט", "תערוך עמוד".
---

# WordPress Content Management

Manage posts, pages, media, categories, and tags on a WordPress site via the WordPress MCP Adapter.

## How the MCP Adapter Works

The WordPress MCP Adapter exposes three core tools:

1. **Discover abilities** — list all registered WordPress abilities available on the site
2. **Get ability info** — get details about a specific ability (input schema, description)
3. **Execute ability** — run an ability with parameters

Always start by discovering available abilities if unsure what the site supports.

## Content Workflows

### Creating a Post

1. Discover abilities — look for `core/create-post` or similar
2. Get ability info to check required parameters (title, content, status, categories)
3. Execute the ability with the user's content

Default to `status: draft` unless the user explicitly says to publish.

### Editing Existing Content

1. First find the content — use `core/list-posts` or `core/get-post` with the post ID or slug
2. Show the user what currently exists
3. Execute `core/update-post` with the changes

### Managing Pages

Pages work like posts but use `core/create-page`, `core/update-page`, etc.
When editing pages built with Elementor or other page builders, warn the user that REST API changes may not reflect in the visual builder.

### Media Management

1. Use `core/list-media` to browse existing uploads
2. Use `core/upload-media` to add new images/files (if available)
3. When creating posts, reference media by ID for featured images

### Categories and Tags

- Use `core/list-categories` and `core/list-tags` to see existing taxonomy terms
- Create new terms with `core/create-category` or `core/create-tag`
- Assign to posts by passing category/tag IDs during creation or update

## Content Best Practices

- Always draft first, let the user review before publishing
- Preserve existing content when making partial edits — fetch first, then update only changed fields
- When the user provides content in Hebrew, set the content direction to RTL
- Include SEO-friendly slugs when creating content
- Suggest categories and tags based on content if the user doesn't specify them

## Error Handling

If an ability is not found, re-discover abilities — the site may have different ability names depending on installed plugins. Suggest the user check that the WordPress MCP Adapter plugin is active and the ability is flagged as `meta.mcp.public`.

## Reference

See `references/wp-content-types.md` for detailed WordPress content type schemas and field descriptions.
