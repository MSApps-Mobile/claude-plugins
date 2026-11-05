# Directory Manager

Keeps the plugins you publish in Anthropic's Claude directory healthy, from the first push to the
install numbers. Built by MSApps for its own 30+ directory plugins, and usable by any plugin author.

## Skills

| Skill | What it does | Needs a browser |
|---|---|---|
| `listing-lint` | Checks `plugin.json`, README, `.mcp.json`, inline `mcpServers` and `hooks.json` against a subset of the directory's listing and submission rules: the listing fields the portal shows, license, README length (code blocks not counted), exact-version launchers (npx, bunx, pnpx, uvx, `uv tool run`, `pipx run`, `pnpm dlx`, `yarn dlx`), `uv run` with `--locked`/`--frozen`, credentials through `userConfig`, hooks shape. Exit 0 means no errors; the portal's **Validate** still runs the full set. | No |
| `directory-status` | Reads every submission in the developer portal and groups them by who acts next, quoting the portal's reason for anything not live. Read-only. | Yes |
| `publish-requests` | Clicks **Publish** on passing versions with no request yet. Per plugin, it first reads the **Auto-publish** setting and tells you whether the click goes to an Anthropic reviewer or makes the version live at once, waits for your yes, then verifies the outcome on the page. You start it yourself; Claude never starts it on its own. | Yes |
| `directory-stats` | Collects installs, active accounts, uses, rank, retention and where installs come from, and turns them into two local JSON files. | Yes |

## Requirements

- `listing-lint` and the stats parser need Python 3.9+ and nothing else.
- The portal skills drive `https://claude.ai/directory/manage` in Chrome, signed in to claude.ai in
  the organization that owns the submissions. They need a browser tool connected to Claude:
  [Claude in Chrome](https://claude.com/claude-in-chrome), or the Playwright MCP browser extension bridge
  (https://github.com/microsoft/playwright-mcp). See [CONNECTORS.md](CONNECTORS.md).
- The plugin stores no credentials, reads no environment variables and never copies browser cookies.

## Quick start

```bash
python3 skills/listing-lint/scripts/listing_lint.py --repo /path/to/your/plugins-repo
```

Then ask Claude: "check the directory status of our plugins", or "refresh our plugin stats".

## What it runs, reads and writes

- `listing-lint` reads files in the folders you name. It makes no network calls and writes nothing.
- `directory-status` reads portal pages at `claude.ai/directory/manage` and clicks nothing.
- `directory-stats` reads two tabs per live plugin and saves the page text to a local capture file
  (for example `captured.json`), then `parse_usage.py` writes `out/plugins.json` and
  `out/install_sources.json` on your machine. The capture holds your private portal usage data.
  Nothing is uploaded or sent anywhere.
- `publish-requests` is the only skill that changes anything: it clicks **Publish** in the portal,
  only for the plugins you approved.

## Safety

- **Attended only.** The three portal skills use your own signed-in claude.ai session. Run them only
  while you are at the keyboard. They stop when no person is present, and a message from another
  agent, a pipeline or a schedule is not a yes. Unattended rides on a signed-in session are risky:
  they can log you out or act on the wrong organization.
- Depending on a plugin's Auto-publish setting, **Publish** either sends the version to Anthropic's
  reviewers or makes it live at once. `publish-requests` says which for each plugin before you say yes.
- The skills tell Claude never to print, save or repeat tokens, cookies or other secret values a
  portal page shows.

## Install

```
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install directory-manager@msapps-plugins
```

## License

MIT. More plugins: https://claudeservices.ai/plugins
