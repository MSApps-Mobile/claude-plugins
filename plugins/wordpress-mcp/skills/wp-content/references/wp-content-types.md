# WordPress Content Types Reference

## Posts

Standard WordPress posts. Key fields:

| Field | Type | Description |
|-------|------|-------------|
| title | string | Post title (rendered or raw) |
| content | string | Post body HTML |
| excerpt | string | Short summary |
| status | string | `draft`, `publish`, `pending`, `private`, `future` |
| slug | string | URL-friendly identifier |
| categories | array[int] | Category term IDs |
| tags | array[int] | Tag term IDs |
| featured_media | int | Attachment ID for featured image |
| date | string | ISO 8601 publish date |
| author | int | User ID |
| format | string | `standard`, `aside`, `gallery`, `image`, `link`, `quote`, `status`, `video`, `audio`, `chat` |
| sticky | boolean | Pin to front page |
| comment_status | string | `open` or `closed` |

## Pages

Similar to posts but hierarchical. Additional fields:

| Field | Type | Description |
|-------|------|-------------|
| parent | int | Parent page ID (0 = top level) |
| menu_order | int | Order in navigation |
| template | string | Page template file |

## Media / Attachments

| Field | Type | Description |
|-------|------|-------------|
| title | string | Media title |
| caption | string | Caption text |
| alt_text | string | Alt text for accessibility |
| description | string | Long description |
| media_type | string | `image`, `file` |
| mime_type | string | e.g. `image/jpeg`, `application/pdf` |
| source_url | string | Direct URL to the file |

## Categories

| Field | Type | Description |
|-------|------|-------------|
| name | string | Category name |
| slug | string | URL slug |
| description | string | Category description |
| parent | int | Parent category ID |

## Tags

| Field | Type | Description |
|-------|------|-------------|
| name | string | Tag name |
| slug | string | URL slug |
| description | string | Tag description |

## Post Statuses

- `publish` — visible to everyone
- `draft` — saved but not visible
- `pending` — awaiting review
- `private` — visible only to admins and editors
- `future` — scheduled for future publication
- `trash` — in the trash

## Common Patterns

### Creating a post with categories
```
Execute core/create-post with:
  title: "My Post"
  content: "<p>Post content here</p>"
  status: "draft"
  categories: [3, 7]  // category IDs
```

### Searching posts
```
Execute core/list-posts with:
  search: "keyword"
  per_page: 10
  status: "publish"
```

### Updating specific fields
```
Execute core/update-post with:
  id: 123
  title: "Updated Title"
  // Only include fields you want to change
```
