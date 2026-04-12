# swift-lsp

Real-time Swift code intelligence for Claude via Apple's SourceKit-LSP.

## What it does

Gives Claude instant diagnostics, go-to-definition, find-references, and type information for `.swift` files — no build step required.

## Setup

1. **Install SourceKit-LSP** (ships with Xcode):
   ```bash
   xcode-select --install
   ```
   Or install the [Swift toolchain](https://swift.org/install) on Linux.

2. **Verify** it works:
   ```bash
   sourcekit-lsp --help
   ```

3. **Install the plugin**:
   ```
   claude plugin install swift-lsp@msapps-plugins
   ```

## SOSA Compliance

| Pillar       | Level |
|-------------|-------|
| Supervised  | Fully autonomous — read-only code analysis |
| Orchestrated | LSP protocol, automatic on file changes |
| Secured     | No credentials, no network, no file writes |
| Agents      | R=swift-code-intelligence, T=sourcekit-lsp |

**Impact:** Low | **SOSA Level:** 1

## License

MIT
