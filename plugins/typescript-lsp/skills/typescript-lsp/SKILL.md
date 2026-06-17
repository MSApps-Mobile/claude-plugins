---
name: typescript-lsp
description: |
  Use this skill whenever Claude needs semantic intelligence on TypeScript or
  JavaScript source — type errors, import resolution, go-to-definition,
  find-references, or hover type information. Trigger on: "TypeScript LSP",
  "tsserver", "typescript-language-server", "type error", "find references",
  "who calls this function", "where is X defined", "why does this import fail",
  ".ts diagnostics", "missing @types", "tsconfig", "checkJs",
  "reportMissingImports", "TSError", "TS2345", "JSX not recognised", or any
  question about .ts/.tsx/.js/.jsx files that requires real symbol resolution
  rather than textual search. Also trigger when the AI Code Reviewer's Phase 3
  dependency graph needs TypeScript `find-references` across a touched file.
---

# typescript-lsp — TypeScript/JavaScript code intelligence via tsserver

Part of the MSApps LSP plugin series. Wraps **typescript-language-server**
(tsserver) as a read-only, SOSA Level 1 intelligence source.

## Workflow Process

### Plan
1. Confirm the user's question actually needs semantic info (type diagnostics,
   references, definitions, hover) vs a plain grep/glob.
2. Verify `typescript-language-server --version` works. If missing, run
   `npm install -g typescript typescript-language-server`.
3. Confirm the repo has a `tsconfig.json` (TS) or `jsconfig.json` (JS) at the
   root, or at least a `package.json` that `tsc` can discover.

### Act
4. Resolve the file path the user is asking about.
5. Use LSP via the plugin's `.lsp.json` wiring:
   - `textDocument/publishDiagnostics` → type/import errors
   - `textDocument/definition` → jump to definition
   - `textDocument/references` → all call sites
   - `textDocument/hover` → inferred type / JSDoc
   - `workspace/symbol` → fuzzy symbol search
6. For cross-file impact (the AI Code Reviewer's use case), iterate
   `find-references` over every exported symbol in the touched file.
7. Treat tsserver answers as authoritative over heuristic search. If tsserver
   returns empty references, *say so* — don't invent them.

### Verify
8. Cross-check one reported reference by opening the referenced file. If the
   symbol isn't really there, the tsserver project may have out-of-date
   `node_modules` — report that, don't silently retry.
9. If diagnostics include `Cannot find module` for installed packages,
   `node_modules` hasn't been populated (`npm install`). Note this before
   trusting import counts.

## tsserver startup notes

- **Project loading:** tsserver uses `tsconfig.json` to determine the project
  boundary. With `composite: true` / project references, tsserver loads each
  sub-project separately — navigate to the root `tsconfig.json` for full
  cross-project references.
- **JavaScript support:** tsserver provides basic intelligence for `.js` even
  without types. Enable full checking with `"checkJs": true` in `jsconfig.json`.
- **Monorepos:** in a workspace (pnpm/yarn/npm workspaces), point tsserver at
  the root `tsconfig.json` that has `references` to all packages.

## Example `tsconfig.json` (strict React/Node project)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "jsx": "react-jsx",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## Common Issues (FAQ)

**"Cannot find module 'X' or its corresponding type declarations."**
Two causes:
1. `node_modules` not populated — run `npm install` (or `pnpm install`).
2. `@types/<package>` missing — `npm install --save-dev @types/<package>`.

**"find-references returns only hits in the current file."**
The symbol is probably not exported. tsserver only traces references to
symbols accessible at the project boundary. If the function is local-only,
references within the file are the complete set.

**"JSX element type 'X' does not have any construct or call signatures."**
`tsconfig.json` is missing `"jsx": "react-jsx"` or the wrong version of
`@types/react` is installed. Check both.

**"tsserver is slow on a large monorepo."**
Add `"skipLibCheck": true` and ensure `node_modules` are excluded. For
project references, each sub-package tsconfig should `composite: true` so
tsserver can use incremental builds.

**"Type errors in `.js` files I didn't opt into."**
Set `"checkJs": false` in your `jsconfig.json` / `tsconfig.json`. tsserver
respects this flag.

**"Deno project — imports resolve to URLs, not paths."**
tsserver doesn't understand Deno's URL imports natively. Use the
`deno-language-server` instead; this plugin targets Node/browser TypeScript.

## Out of scope

- Running tests or executing JavaScript. Pure static analysis only.
- Auto-fixing type errors. tsserver surfaces them; Claude can suggest fixes.
- Bundler integration (Vite, Webpack, esbuild). Bundler transforms happen
  outside tsserver's scope — if bundled output works but tsserver errors,
  check path aliases in `tsconfig.json` `paths`.
