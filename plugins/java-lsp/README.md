# java-lsp

Real-time Java code intelligence for Claude via Eclipse JDT Language Server (jdtls).

## What it does

Gives Claude compile-accurate diagnostics, go-to-definition, find-references, and Javadoc hover for `.java` files — supports Maven, Gradle, and Android Gradle projects.

## Setup

1. **Install jdtls**:
   ```bash
   # macOS (Homebrew)
   brew install jdtls

   # Or download from GitHub releases:
   # https://github.com/eclipse-jdtls/eclipse.jdt.ls/releases
   ```

2. **Ensure Java 17+ is on PATH**:
   ```bash
   java -version  # needs 17+
   jdtls --help
   ```

3. **Install the plugin**:
   ```
   claude plugin install java-lsp@msapps-plugins
   ```

## Requirements

- Java 17+ runtime on `PATH`
- `jdtls` on `PATH`
- A recognizable project root: `pom.xml`, `build.gradle[.kts]`, `settings.gradle[.kts]`, `.project`, or `.git`

## Security — open only projects you trust

Importing a **Gradle** build executes `build.gradle(.kts)` and `settings.gradle`, and a **Maven** import can run plugins the `pom.xml` declares. A repo can put arbitrary code there.

This plugin therefore ships with build-tool import **off**:
- `java.import.gradle.enabled: false`, `java.import.maven.enabled: false`
- `java.autobuild.enabled: false`, `java.configuration.updateBuildConfiguration: "disabled"`

Plain `.java` files still get diagnostics and navigation. For a repo you trust and want full classpath resolution, set the import flags to `true` in `.lsp.json`.

## SOSA Compliance

| Pillar       | Level |
|-------------|-------|
| Supervised  | L1 — read-only, no side effects |
| Orchestrated | L1 — LSP protocol, no manual routing |
| Secured     | L1 — no credentials, localhost socket only, no writes; build-tool import OFF by default (see Security) |
| Agents      | L1 — pure code analysis |

**Level 1** — safe to run autonomously on codebases you trust (see Security above).

## Startup Notes

- **First-run latency:** initial workspace build for large Maven/Gradle projects can take 30–90 s
- **Workspace cache:** `~/.cache/jdtls/workspace/<hash>/` — safe to delete to force reindex
- **Android:** jdtls doesn't run the AGP classloader; open in Android Studio first to generate `R.java`, then point jdtls at generated sources

## Part of the MSApps LSP plugin series

Sibling plugins: `kotlin-lsp`, `swift-lsp`, `python-lsp`, `typescript-lsp`, `csharp-lsp`

All share the same MCP contract so the AI Code Reviewer (LangGraph) can orchestrate them uniformly across multi-language repos.
