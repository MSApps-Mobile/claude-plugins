# WordPress Roles and Capabilities

## Default Roles

| Role | Description | Key Capabilities |
|------|-------------|-----------------|
| Administrator | Full site access | All capabilities including settings, plugins, themes, users |
| Editor | Manage all content | Edit/delete/publish all posts, moderate comments, manage categories |
| Author | Publish own posts | Write and publish own posts, upload files |
| Contributor | Submit for review | Write own posts but cannot publish (pending review) |
| Subscriber | Read only | Read content, manage own profile |

## Key Capabilities

### Content
- `edit_posts` — create and edit own posts
- `publish_posts` — publish posts (not just draft)
- `edit_others_posts` — edit posts by other users
- `delete_posts` — delete own posts
- `edit_pages` — create and edit pages
- `publish_pages` — publish pages

### Moderation
- `moderate_comments` — approve, spam, delete comments
- `manage_categories` — create, edit, delete categories and tags

### Administration
- `manage_options` — change site settings
- `activate_plugins` — activate/deactivate plugins
- `edit_themes` — edit theme files
- `switch_themes` — change active theme
- `create_users` — add new users
- `edit_users` — modify other users
- `delete_users` — remove users
- `install_plugins` — install new plugins
- `update_plugins` — update existing plugins

## Custom Roles

Sites with plugins like WooCommerce may have additional roles:
- `shop_manager` — manage products, orders, coupons
- `customer` — view own account and orders

## Permission Checks

The MCP Adapter respects WordPress permissions. If an ability returns a permission error, the authenticated user's role doesn't have the required capability. Suggest:
1. Check which user is authenticated in the MCP connection
2. Verify the user has the appropriate role
3. Consider using an administrator account for full access
