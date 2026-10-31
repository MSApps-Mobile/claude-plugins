# Directory Manager

Keeps the plugins you publish in Anthropic's Claude directory healthy, from the first push to the
install numbers. Built by MSApps for its own 30+ directory plugins, and usable by any plugin author.

## Skills

| Skill | What it does | Needs a browser |
|---|---|---|
| `listing-lint` | Checks `plugin.json`, README, `.mcp.json` and `hooks.json` against the directory's listing and submission rules: the listing fields the portal shows, license, README length, pinned npx/uvx launchers, credentials through `userConfig`, hooks shape. Exit 0 means no errors. | No |
| `directory-status` | Reads every submission in the developer portal and groups them by who acts next, quoting the portal's reason for anything not live. Read-only. | Yes |
| `publish-requests` | Clicks **Publish update** on passing versions with no request yet. Asks you first, then verifies each request on the page. | Yes |
| `directory-stats` | Collects installs, active accounts, uses, rank, retention and where installs come from, and turns them into two JSON datasets for a dashboard. | Yes |

## Requirements

- `listing-lint` and the stats parser need Python 3.9+ and nothing else.
- The portal skills need Chrome signed in to claude.ai in the organization that owns the submissions,
  with Claude in Chrome (or the Playwright extension bridge) connected. The plugin stores no
  credentials and never copies browser cookies.

## Quick start

```bash
python3 skills/listing-lint/scripts/listing_lint.py --repo /path/to/your/plugins-repo
```

Then ask Claude: "check the directory status of our plugins", or "refresh our plugin stats".

## Safety

Lint, status and stats only read. Requesting a publish sends a request to Anthropic's reviewers, so
the skill lists the plugins and waits for your yes before clicking anything.

## Install

```
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install directory-manager@msapps-plugins
```

## License

MIT. More plugins: https://claudeservices.ai/plugins
