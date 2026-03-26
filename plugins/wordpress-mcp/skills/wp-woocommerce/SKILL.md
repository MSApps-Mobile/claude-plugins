---
name: wp-woocommerce
description: >
  WooCommerce store management through the WordPress MCP Adapter. Use when the user
  asks about "orders", "products", "customers", "sales", "inventory", "coupons",
  "WooCommerce", "store", "ecommerce", "shipping", "revenue", "order status",
  "product stock", "add a product", "check orders", "sales report", or any request
  related to online store operations. Also trigger on: "הזמנות", "מוצרים",
  "לקוחות", "חנות", "מכירות", "קופונים".
---

# WooCommerce Store Management

Manage products, orders, customers, coupons, and store settings through the WordPress MCP Adapter on sites with WooCommerce installed.

## Prerequisites

WooCommerce abilities are only available if:
1. WooCommerce plugin is installed and active on the WordPress site
2. WooCommerce abilities are registered with the MCP Adapter
3. The abilities are flagged as `meta.mcp.public`

Always discover abilities first. WooCommerce abilities typically have a `woocommerce/` namespace prefix.

## Product Management

### Listing Products
- Discover and execute `woocommerce/list-products`
- Filter by: status (publish, draft), type (simple, variable, grouped), category, stock status
- Present as a clean table: name, price, stock, status

### Creating Products
Execute `woocommerce/create-product` with:
- `name` — product title
- `type` — `simple`, `variable`, `grouped`, `external`
- `regular_price` — price as string (e.g., "29.99")
- `description` — full HTML description
- `short_description` — excerpt
- `categories` — array of category objects
- `images` — array of image objects with `src` URL
- `manage_stock` — boolean
- `stock_quantity` — integer if managing stock

Default to draft status. Let the user review before publishing.

### Updating Products
- Fetch current product first with `woocommerce/get-product`
- Only send changed fields in the update
- For price changes, confirm with the user — this affects live pricing

### Inventory
- Check stock with `woocommerce/list-products` filtered by `stock_status`
- Update stock quantities via `woocommerce/update-product`
- Report low-stock items (typically < 5 units)

## Order Management

### Viewing Orders
- `woocommerce/list-orders` with filters for status, date range, customer
- Order statuses: `pending`, `processing`, `on-hold`, `completed`, `cancelled`, `refunded`, `failed`
- Present orders with: ID, customer name, total, status, date

### Order Details
- `woocommerce/get-order` with order ID for full details
- Show: line items, shipping address, billing address, payment method, order notes

### Updating Orders
- Change order status via `woocommerce/update-order`
- Common flows: `processing` -> `completed`, `pending` -> `on-hold`
- Add order notes for tracking communication
- Never delete orders — suggest cancellation or refund instead

## Customer Management

- `woocommerce/list-customers` for customer directory
- `woocommerce/get-customer` for individual customer details
- View order history per customer
- Present: name, email, total orders, total spent

## Coupons

- `woocommerce/list-coupons` to see active promotions
- Create coupons with: code, discount type (percent, fixed_cart, fixed_product), amount, usage limits
- Check coupon usage and expiry dates

## Sales Reporting

When asked for sales data:

1. Fetch recent orders with `woocommerce/list-orders` (status: completed, processing)
2. Calculate totals by summing order amounts
3. Present: total revenue, order count, average order value
4. Break down by period if date range is specified

For more detailed analytics, suggest the user check WooCommerce Analytics in the WordPress admin.

## Safety Guidelines

- Never process refunds without explicit user confirmation
- Price changes should always be confirmed — they affect live customers
- Stock quantity changes need verification
- Customer data (emails, addresses) is sensitive — don't expose unnecessarily
- Order status changes trigger customer email notifications — warn the user
