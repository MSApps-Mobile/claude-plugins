---
name: python-lsp
description: |
  Use this skill whenever Claude needs semantic intelligence on Python source —
  type errors, import resolution, go-to-definition, find-references, or hover
  type information. Trigger on: "Python LSP", "pyright", "type error", "find
  references", "who calls this function", "where is X defined", "why does this
  import fail", ".py diagnostics", "missing type stub", "pyrightconfig",
  "type checking mode", "reportMissingImports", or any question about .py/.pyi
  files that requires real symbol resolution rather than textual search. Also
  trigger when the AI Code Reviewer's Phase 3 dependency graph needs Python
  `find-references` across a touched file.
---

# python-lsp — Python code intelligence via Pyright

Part of the MSApps LSP plugin series. Wraps **Pyright** (`pyright-langserver`)
as a read-only, SOSA Level 1 intelligence source.

## Workflow Process

### Plan
1. Confirm the user's question actually needs semantic info (type diagnostics,
   references, definitions, hover) vs a plain grep/glob.
2. Verify `pyright-langserver --version` works. If missing, run
   `npm install -g pyright` or `pip install pyright`.
3. Confirm the repo has a recognizable Python root: `pyrightconfig.json`,
   `pyproject.toml`, `setup.py`, `setup.cfg`, or a `.git` directory.

### Act
4. Resolve the file path the user is asking about.
5. Use LSP via the plugin's `.lsp.json` wiring:
   - `textDocument/publishDiagnostics` → type/import errors
   - `textDocument/definition` → jump to definition
   - `textDocument/references` → all call sites
   - `textDocument/hover` → inferred type / docstring
   - `workspace/symbol` → fuzzy symbol search
6. For cross-file impact (the AI Code Reviewer's use case), iterate
   `find-references` over every public symbol in the touched file.
7. Treat Pyright answers as authoritative over heuristic search. If Pyright
   returns empty references, *say so* — don't invent them.

### Verify
8. Cross-check one reported reference by opening the referenced file. If the
   symbol isn't really there, the Pyright index may be stale — report that.
9. If diagnostics include `reportMissingImports` for installed packages, the
   virtual environment isn't configured — check `pyrightconfig.json`
   `venvPath`/`venv` settings before trusting import counts.

## Pyright startup notes

- **Incremental cache:** Pyright writes `.pyright/` to the workspace root.
  Safe to delete to force a full reindex. Subsequent runs are fast.
- **Virtual environments:** Set `venvPath` + `venv` in `pyrightconfig.json`
  (or `pythonPath` for a specific interpreter) so Pyright resolves installed
  packages correctly.
- **Type checking modes:** `off` → `basic` → `standard` → `strict`. The plugin
  defaults to `basic`; upgrade to `standard` or `strict` for well-typed
  codebases where you want exhaustive checking.

## Example `pyrightconfig.json`

```json
{
  "typeCheckingMode": "basic",
  "pythonVersion": "3.11",
  "venvPath": ".",
  "venv": ".venv",
  "reportMissingImports": true,
  "reportMissingTypeStubs": false,
  "exclude": ["**/node_modules", "**/__pycache__"]
}
```

## Common Issues (FAQ)

**"reportMissingImports fires on every import."**
Your venv isn't configured. Add `venvPath`/`venv` to `pyrightconfig.json` or
set `pythonPath` to the interpreter that has your dependencies installed.

**"find-references returns fewer hits than I expect."**
Two common causes:
1. Dynamic attribute access (`getattr`, `__dict__`) — Pyright can't statically
   resolve these; note them as dynamic in your output.
2. Code in a subpackage that isn't imported into the workspace root — open the
   repo root, not a subdirectory.

**"Type stubs missing for a third-party library."**
Install `types-<package>` from PyPI (e.g. `pip install types-requests`) or
add `reportMissingTypeStubs: false` to `pyrightconfig.json` to silence it.

**"Pyright is slow on first open."**
Expected — Pyright indexes the full workspace. Subsequent runs use the
`.pyright/` cache and are much faster. For very large monorepos, add
`"exclude"` patterns to limit the scope.

**"`.pyi` stub files not picked up."**
Set `stubPath` in `pyrightconfig.json` to the directory containing your stubs.
Pyright looks in `typings/` by default.

**"Django / SQLAlchemy dynamic attributes flagged as errors."**
These frameworks use heavy runtime metaprogramming. Install the appropriate
type stubs (`django-stubs`, `sqlalchemy-stubs`) or switch to `"basic"` mode
to suppress dynamic-attribute false positives.

## Out of scope

- Running tests or executing Python code. Pure static analysis only.
- Auto-fixing type errors. Pyright surfaces them; Claude can suggest fixes.
- Refactor execution (rename, extract). Applying edits violates Level-1 SOSA.
