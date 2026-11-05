# Connectors

## Required

- None for `listing-lint` and the stats parser: they are local Python scripts with no network calls
  and no credentials.

## Required for the portal skills (`directory-status`, `publish-requests`, `directory-stats`)

- **A browser tool connected to Claude**, with Chrome signed in to claude.ai in the organization that
  owns the submissions:
  - [Claude in Chrome](https://claude.com/chrome) (preferred), or
  - the Playwright MCP browser extension bridge (https://github.com/microsoft/playwright-mcp).
- Host driven: `https://claude.ai/directory/manage` only.
- Credentials: none stored. The skills use the browser's own session and never copy its cookies.
  Run them attended only (see the README's Safety section).

## Never

- Never uploads or sends the captured portal data anywhere; the output stays in local files.
- Never clicks Delist, Withdraw, Remove or Rotate.
