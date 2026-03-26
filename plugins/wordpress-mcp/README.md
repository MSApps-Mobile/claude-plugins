# WordPress MCP Plugin

Manage WordPress sites directly from Claude using the [WordPress MCP Adapter](https://developer.wordpress.org/news/2026/02/from-abilities-to-ai-agents-introducing-the-wordpress-mcp-adapter/).

## What it does

Connect Claude to any WordPress 6.9+ site and manage content, users, settings, and WooCommerce — all through conversation.

### Skills

| Skill | What it does |
|-------|-------------|
| **wp-content** | Create, edit, and publish posts, pages, and media. Manage categories and tags. |
| **wp-admin** | Site administration — users, plugins, themes, comments, settings, and site health. |
| **wp-woocommerce** | Store management — products, orders, customers, coupons, and sales reporting. |

## Setup

### 1. Install the WordPress MCP Adapter

Install the [WordPress MCP Adapter](https://github.com/developer-wordpress-org/wp-mcp-adapter) plugin on your WordPress site from the GitHub releases page.

### 2. Enable abilities

Add the `meta.mcp.public` flag to the abilities you want to expose. You can use the `wp_register_ability_args` filter or enable core abilities in the adapter settings.

### 3. Configure environment variables

Set these environment variables before using the plugin:

| Variable | Description | Example |
|----------|-------------|---------|
| `WP_MCP_URL` | Your site's MCP Adapter HTTP endpoint | `https://yoursite.com/wp-json/mcp/v1` |
| `WP_MCP_AUTH` | Base64-encoded `username:password` or application password | `bWljaGFsOnhXXk5...` |

### Generating an Application Password

1. Go to WordPress Admin > Users > Your Profile
2. Scroll to "Application Passwords"
3. Enter a name (e.g., "Claude MCP") and click "Add New"
4. Base64-encode `username:application_password` for `WP_MCP_AUTH`

## Usage

Once connected, just ask Claude naturally:

- "List my recent blog posts"
- "Create a draft post about our new product launch"
- "How many pending orders do we have?"
- "Check which plugins need updates"
- "Show me low-stock products"
- "Update the About page content"

## Requirements

- WordPress 6.9+ with Abilities API
- WordPress MCP Adapter plugin installed and configured
- User account with appropriate permissions (Administrator recommended)
- WooCommerce plugin (only needed for store management features)

## Built by

[MSApps](https://msapps.mobi/en/) — Mobile & Web App Development
