---
name: java-lsp
description: |
  Use this skill whenever Claude needs semantic intelligence on Java source —
  compile errors, type info, go-to-definition, find-references, or call-graph
  context. Trigger on: "Java LSP", "jdtls", "Eclipse JDT", "find references",
  "who calls this method", "where is X defined", "why does this class fail to
  compile", ".java diagnostics", "method signature", "Java type error", "Maven
  build error", "Gradle compile error", "Android Gradle", "classpath issue",
  "Javadoc for", "decompile", or any question about .java files that requires
  real symbol resolution rather than textual search. Also trigger when the AI
  Code Reviewer's Phase 3 dependency graph needs Java `find-references` across
  a touched file.
---

# java-lsp — Java code intelligence via jdtls

Part of the MSApps LSP plugin series. Wraps **Eclipse JDT Language Server**
(`jdtls`) as a read-only, SOSA Level 1 intelligence source.

## Workflow Process

### Plan
1. Confirm the user's question actually needs semantic info (diagnostics,
   references, definitions, hover) vs a plain grep/glob.
2. Verify `jdtls --help` works and Java 17+ is on PATH (`java -version`).
3. Confirm the repo has a recognizable root: `pom.xml`, `build.gradle[.kts]`,
   `settings.gradle[.kts]`, `.project`, or a `.git` directory.

### Act
4. Resolve the file path the user is asking about.
5. Use LSP via the plugin's `.lsp.json` wiring:
   - `textDocument/publishDiagnostics` → compile errors
   - `textDocument/definition` → jump
   - `textDocument/references` → call sites
   - `textDocument/hover` → type / Javadoc
   - `workspace/symbol` → fuzzy class search
6. For cross-file impact (the AI Code Reviewer's use case), iterate
   `find-references` over every public/protected symbol in the touched file.
7. Treat jdtls answers as authoritative over heuristic search. If jdtls returns
   empty, *say so* — don't invent references.

### Verify
8. Cross-check one reported reference by opening the referenced file. If the
   symbol isn't really there, the jdtls index is stale — report that, don't
   silently retry.
9. If diagnostics include `incompleteClasspath`, the project isn't fully loaded
   yet — wait for the initial build (can take 10–60 s on first open) before
   trusting reference counts.

## `jdtls` startup notes (non-obvious)

- **First-run latency:** the initial workspace build for a large Maven/Gradle
  project can take 30–90 s. The LSP wrapper's `startupTimeoutMs: 45000` covers
  small projects; big monorepos may need bumping in a fork.
- **Workspace folder:** jdtls writes build artifacts to
  `~/.cache/jdtls/workspace/<hash>/`. Safe to delete to force reindex.
- **JDK version:** jdtls **runs** on Java 17+. The *target* source can be any
  JDK (`--source 1.8` through latest) as long as a matching JDK is on the
  runtime classpath. Configure via `org.eclipse.jdt.ls.core.vmargs` or
  `JAVA_HOME` pointing at the runtime JDK.

## Example `settings.json` (consumer-side, optional)

```json
{
  "java.configuration.runtimes": [
    { "name": "JavaSE-17", "path": "/opt/homebrew/opt/openjdk@17", "default": true },
    { "name": "JavaSE-21", "path": "/opt/homebrew/opt/openjdk@21" }
  ],
  "java.import.gradle.enabled": true,
  "java.import.maven.enabled": true,
  "java.autobuild.enabled": true
}
```

## Common Issues (FAQ)

**"jdtls hangs on startup."**
Usually the initial Maven/Gradle resolve. Tail `~/.cache/jdtls/*/.metadata/.log`
to confirm it's still progressing. Rule out VPN-blocked Maven Central.

**"find-references returns only 2 hits but I know there are more."**
Two common causes:
1. Index not built yet (see `incompleteClasspath` warning).
2. Callers live in a *different* Gradle subproject that isn't imported into the
   same workspace. Open the repo root, not a subproject.

**"Diagnostics show `The type XXX cannot be resolved`."**
Classpath is broken. Check:
- `pom.xml` / `build.gradle` is valid
- Dependencies have been downloaded (`./mvnw dependency:resolve` /
  `./gradlew dependencies`)
- The runtime JDK matches the project's source level

**"Android Gradle project — jdtls doesn't see AAR dependencies."**
jdtls doesn't run the full Android Gradle Plugin classloader. Open the project
first in Android Studio / IntelliJ to let AGP generate `R.java` and unpack
AARs, then point jdtls at the generated sources. For pure JVM modules (no
`com.android.*`), jdtls works directly.

**"Kotlin interop — my Java file calls into Kotlin code, refs not found."**
That's expected — jdtls doesn't parse `.kt`. Pair this plugin with
`kotlin-lsp`; the AI Code Reviewer already knows how to combine them.

**"Javadoc shows as raw HTML tags."**
jdtls returns Markdown-rendered Javadoc when the client advertises
`hover.markdown`. The plugin does that by default; if you're seeing raw HTML
you're probably on a very old jdtls build — upgrade.

**"Groovy / Scala / Clojure?"**
Out of scope. They'd be sibling plugins (`groovy-lsp`, `metals`,
`clojure-lsp`). Open an issue if there's MSApps demand.

## Out of scope

- Refactor *execution* (rename, extract method, change signature). jdtls can
  plan them; we only surface the plan. Applying edits violates Level-1 SOSA.
- Running tests or the JVM. Pure static analysis.
- Maven / Gradle task execution. If a user wants `./gradlew build`, that's a
  separate Bash tool concern.
