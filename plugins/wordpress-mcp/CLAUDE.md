# WordPress MCP

Manage WordPress sites directly from Claude. Create, edit, and publish content; manage users and plugins; monitor site health and WooCommerce operations.

## Requirements

- WordPress 6.9 or later with Abilities API enabled
- WordPress MCP Adapter plugin installed and activated
- Application password for authentication

## Available Tools/Skills

Organized into three skill categories:

### wp-content
- Manage posts and pages (create, edit, publish, delete, list)
- Upload and manage media
- Create and manage categories and tags
- Search content across the site

### wp-admin
- Manage user accounts and permissions
- Install, update, activate/deactivate plugins
- Install, switch, activate themes
- Moderate and manage comments
- Access site settings and configuration
- Check site health and performance metrics

### wp-woocommerce
- Create and manage products
- View and process orders
- Manage customer accounts
- Create and manage coupons
- Generate sales reports and analytics

## Configuration

1. Install the WordPress MCP Adapter plugin via WordPress Admin
2. Enable Abilities API in plugin settings
3. Generate an Application Password:
   - Go to WordPress Admin > Users > Your Profile
   - Scroll to "Application Passwords"
   - Enter a name (e.g., "Claude") and click "Create Application Password"
   - Copy the generated password

4. Set environment variables:
   ```
   WP_MCP_URL=https://your-site.com
   WP_MCP_AUTH=username:app-password
   ```

## Common Workflows

- **"List recent posts"** - View latest published content
- **"Create draft about product launch"** - Start new post in draft status
- **"Check plugin updates"** - See available plugin updates
- **"Show low-stock products"** - WooCommerce inventory monitoring
- **"Publish scheduled posts"** - Manage content calendar
- **"Generate sales report"** - WooCommerce analytics
- **"Update site settings"** - Configure WordPress options

## Best Practices

- Use drafts for content review before publishing
- Regularly update plugins and themes for security
- Monitor site health for performance issues
- Keep user permissions minimal (principle of least privilege)
- Use categories and tags strategically for organization
- Schedule posts during peak audience times
- Regular backups before major changes
- Test theme changes on staging environment first
