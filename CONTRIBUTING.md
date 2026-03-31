# Contributing to Claude Plugins Marketplace

Thank you for your interest in contributing! This project is the largest open-source plugin marketplace for Claude, and we welcome contributions from the community.

## Ways to Contribute

### Report Bugs
- Open an [issue](https://github.com/MSApps-Mobile/claude-plugins/issues) with a clear description
- Include steps to reproduce, expected behavior, and actual behavior
- Add relevant logs or screenshots if possible

### Suggest New Plugins
- Open an issue with the title "Plugin Request: [Service Name]"
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

Each plugin should follow this structure:

```
plugins/your-plugin-name/
├── src/
│   └── index.ts          # Main MCP server entry point
├── package.json          # Dependencies and metadata
├── tsconfig.json         # TypeScript configuration
├── README.md             # Plugin-specific documentation
└── config.example.json   # Example configuration (if needed)
```

## Development Guidelines

### Code Standards
- Write in TypeScript
- Follow existing code style and patterns
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

Be respectful, constructive, and collaborative. We're building this together.

## Questions?

Open an issue or reach out — we're happy to help you get started.