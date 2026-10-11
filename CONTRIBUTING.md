# Contributing to Claude Plugins Marketplace

Thank you for your interest in contributing! This project is the largest open-source plugin marketplace for Claude, and we welcome contributions from the community.

## Ways to Contribute

### Report Bugs
- Open a [bug report](https://github.com/MSApps-Mobile/claude-plugins/issues/new?template=bug_report.md) with a clear description
- Include steps to reproduce, expected behavior, and actual behavior
- Add relevant logs or screenshots if possible

### Suggest New Plugins
- Open a [plugin proposal](https://github.com/MSApps-Mobile/claude-plugins/issues/new?template=new_plugin_proposal.md)
- Describe the integration, what tools it should expose, and the use case
- Bonus: link to the service's API documentation

### Submit a New Plugin
1. Fork the repository
2. Create a feature branch: `git checkout -b plugin/your-plugin-name`
3. Build your plugin following the structure below
4. Ensure it passes SOSA™ compliance checks
5. Submit a pull request
### Improve Documentation
- Fix typos, clarify instructions, or add examples
- Documentation PRs are always welcome and reviewed quickly

## Plugin Structure

Each plugin lives in its own folder under `plugins/` and follows the layout the
existing plugins use (see any folder under [`plugins/`](plugins/) for a worked example):

```
plugins/your-plugin-name/
├── .claude-plugin/
│   └── plugin.json          # name, version, description, author
├── README.md                # what it does, setup, examples
├── CONNECTORS.md            # (if it needs connectors / MCP servers) what and why
└── skills/
    └── your-skill-name/
        ├── SKILL.md         # the skill itself
        └── references/      # (optional) supporting docs the skill loads
```

A plugin that ships an MCP server adds a `.mcp.json` at the plugin root (e.g.
[`plugins/apollo/.mcp.json`](plugins/apollo/.mcp.json)) and documents every server it starts in `CONNECTORS.md`.

### The bar for a new plugin

A new-plugin PR is ready for review when:

1. The folder follows the layout above and `plugin.json` is valid.
2. **The plugin is listed in [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json).**
   A plugin folder that is not in the manifest is not installable from the marketplace;
   CI checks the two agree (`scripts/check-marketplace-coverage.py`).
3. It passes the SOSA™ lint (`scripts/sosa-lint.sh`, run by CI on every PR).
4. Its README says what it needs (accounts, connectors, env vars) and what it will never do.

Not sure a plugin fits? Open a [plugin proposal](https://github.com/MSApps-Mobile/claude-plugins/issues/new?template=new_plugin_proposal.md) first.

## Development Guidelines

### Code Standards
- Follow the existing style of the plugin you are changing (most plugins are skills — Markdown — rather than compiled code)
- Add error handling for all API calls
- Include rate limiting where appropriate
- Never hardcode credentials — use environment variables or config files
### SOSA™ Compliance
All plugins must adhere to the SOSA™ (Supervised, Orchestrated, Secured, Agents) framework:

- **Supervised**: Log all significant actions for auditability
- **Orchestrated**: Follow defined workflow patterns
- **Secured**: Isolate credentials, use granular permissions
- **Agents**: Operate within clearly defined scope boundaries

### Testing
- Test your plugin with both Claude Code CLI and Cowork desktop app
- Verify all tool definitions are correct and well-documented
- Test edge cases: invalid inputs, expired tokens, rate limits

## Pull Request Process

1. Update the README if your plugin adds new functionality
2. Ensure your code follows the existing style
3. Write a clear PR description explaining what your plugin does
4. Reference any related issues
5. A maintainer will review your PR — expect feedback within a few days

## Good First Issues

Look for issues tagged [`good first issue`](https://github.com/MSApps-Mobile/claude-plugins/labels/good%20first%20issue) — these are great starting points for new contributors.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By taking part you agree to uphold it; report unacceptable behavior to michal@msapps.mobi.

## Questions?

Open an issue or reach out — we're happy to help you get started.