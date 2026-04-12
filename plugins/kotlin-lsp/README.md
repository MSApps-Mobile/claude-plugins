# kotlin-lsp

Real-time Kotlin code intelligence for Claude via kotlin-language-server.

## What it does

Gives Claude instant diagnostics, go-to-definition, find-references, and type information for `.kt` and `.kts` files — no build step required.

## Setup

1. **Install kotlin-language-server**:
   ```bash
   brew install kotlin-language-server
   ```
   Or via [SDKMAN](https://sdkman.io/) (`sdk install kls`) or [GitHub releases](https://github.com/fwcd/kotlin-language-server/releases).

2. **Verify** it works:
   ```bash
   kotlin-language-server --version
   ```

3. **Install the plugin**:
   ```
   claude plugin install kotlin-lsp@msapps-plugins
   ```

## SOSA Compliance

| Pillar       | Level |
|-------------|-------|
| Supervised  | Fully autonomous — read-only code analysis |
| Orchestrated | LSP protocol, automatic on file changes |
| Secured     | No credentials, no network, no file writes |
| Agents      | R=kotlin-code-intelligence, T=kotlin-language-server |

**Impact:** Low | **SOSA Level:** 1

## License

MIT
