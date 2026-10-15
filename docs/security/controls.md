# Security controls — MSApps / OpsAgents AI

Prepared for the Anthropic Cyber Verification Program (CVP) readiness review (card 54ABAl7N).
Scope: this repository (`MSApps-Mobile/claude-plugins`) and the people and workloads at MSApps who
would send CVP traffic to Claude.

**Rules for this page.** It lists only controls that exist today. If a control is missing, or we have
no evidence for it yet, it is marked **GAP** and has a remediation step. A control whose evidence a human
still has to capture (for example a settings page we could not read from automation) is marked
**VERIFY**. Until someone records that evidence, treat a VERIFY item as a GAP.

We do **not** hold SOC 2, ISO 27001 or a similar certification. We do not operate a SIEM, and we do not
have a 24/7 incident response team or on-call rotation. Nothing below should be read as claiming any of
these. (See also [SECURITY.md](../../SECURITY.md) → *What we do not have*.)

## Roles

Owners are named by role. A human assigns a person to each role in the application, not in this repo.

| Role | Responsibility |
|------|----------------|
| **Repo Owner** | GitHub owner of the `MSApps-Mobile` organization and admin of this repository; owns repo settings. |
| **Maintainer** | Anyone with write access who reviews and merges pull requests. |
| **Security Contact** | Receives vulnerability reports and CVP/Anthropic security notices and runs incident response. A backup is needed for higher tiers. |
| **CVP Key Custodian** | Admin of the Anthropic Console organization/workspace used for CVP traffic. Issues, assigns and rotates API keys. |
| **Workload Owner** | The one person accountable for a non-human workload (CI job, scheduled agent) that holds its own API key. |

## Controls in place

| ID | Control | Status | Owner | Evidence location |
|----|---------|--------|-------|-------------------|
| C-1 | Private vulnerability reporting through GitHub Security Advisories, with a written intake policy (best-effort acknowledgement, no bug bounty, no 24/7) | In place (policy). The repo setting needs **VERIFY** | Security Contact | [SECURITY.md](../../SECURITY.md) → *Reporting a vulnerability*. Repo → Security → Advisories (*Report a vulnerability* button visible) |
| C-2 | GitHub secret scanning with push protection | **VERIFY**. Stated in SECURITY.md, but this setting could not be read from automation | Repo Owner | Repo → Settings → Code security → *Secret scanning* / *Push protection* (screenshot) |
| C-3 | Dependabot **alerts** on the default branch | In place. Observed 2026-10-15: `git push` to this repo returned a link to the Dependabot alerts page, so alerts are enabled. Alert contents are tracked privately in the Security tab, not here | Maintainer (triage), Repo Owner (setting) | Repo → Security → Dependabot alerts |
| C-4 | Automated pattern checks on every PR to `main` and every push to `main`: SOSA lint (SKILL.md presence and role keywords, secret-pattern grep, committed `.env` files), SOSA keyword score with a 70% gate, marketplace coverage check | In place. These are **pattern matches, not a secret scanner, and they do not block merges** (see G-1) | Maintainer | [`.github/workflows/sosa-lint.yml`](../../.github/workflows/sosa-lint.yml), [`validate-pr.yml`](../../.github/workflows/validate-pr.yml), [`scripts/sosa-lint.sh`](../../scripts/sosa-lint.sh), [`scripts/sosa-eval.sh`](../../scripts/sosa-eval.sh). Run history: Actions tab |
| C-5 | Per-plugin checks on PRs that touch `plugins/`, `scripts/`, `.claude-plugin/`: structure, `plugin.json` schema, SKILL.md frontmatter, wider secret-pattern scan (`api_key`, `secret`, `password`, `token`, `sk-…`, `xoxb-…`), dry-run package build | In place (non-blocking, as C-4) | Maintainer | [`.github/workflows/validate-pr.yml`](../../.github/workflows/validate-pr.yml) |
| C-6 | No credentials in plugins: plugins must read user-supplied credentials from the user's own environment or secret store | In place (policy, with partial enforcement by C-4/C-5) | Maintainer | [SECURITY.md](../../SECURITY.md) → *How these plugins run*. PR template → *Secured* checklist ([`.github/pull_request_template.md`](../../.github/pull_request_template.md)) |
| C-7 | Release automation uses the workflow's `GITHUB_TOKEN` with only `contents: write` (plus `actions: write` for the dispatch job). No long-lived personal token is stored for releases | In place | Repo Owner | [`.github/workflows/release.yml`](../../.github/workflows/release.yml) → `permissions:` |
| C-8 | Approval gates and a local audit log for high-impact MCP tool calls, available as our own `sosa-governor` plugin (PreToolUse classify/gate hook, PostToolUse audit hook) | In place **as a product**. It applies only on a workstation where it is installed. Logs stay on that machine and are not collected centrally | Plugin code and default `impact-registry.json`: Maintainer. Per-workstation audit log: **TBD** (no owner assigned yet) | [`plugins/sosa-governor/hooks/`](../../plugins/sosa-governor/hooks/), [`config/impact-registry.json`](../../plugins/sosa-governor/config/impact-registry.json) |
| C-9 | Repository docs state only the controls that exist (SECURITY.md rewrite, card 9GIcXqno). SOSA.md describes what CI really runs (card ibHWKJhQ) | **Pending (PR #53 open)**. Only the SECURITY.md half is merged (commit `8c0151e`); treat C-9 as not in place until PR #53 merges | Repo Owner | Commit `8c0151e`. PR #53 (open, not merged) |

## Gaps

Items marked **CVP-blocking** must be closed, with evidence, before we apply for **Defense Access** or any
higher tier. Default access needs no application, but the program requires retention and monitoring of
CVP traffic at every tier. G-7 therefore applies to us whatever tier we use. The program requirements quoted in this table (MFA dates, 7-day rotation, retention) are **UNVERIFIED** until checked against Anthropic's own CVP page; see [cvp-scope.md](cvp-scope.md).

| ID | Gap | CVP-blocking? | Owner | Remediation step | Evidence to capture when done |
|----|-----|---------------|-------|------------------|-------------------------------|
| G-1 | No branch protection on `main`. Reviews and passing checks are not required, and `release.yml` pushes directly | No (repo hygiene). Needed so C-4/C-5 actually gate | Repo Owner | Add a ruleset on `main` that requires a PR, 1 approval and the `SOSA™ Four-Pillar Lint` and `SOSA™ Evaluation Scores` checks. Allow a bypass only for the release workflow's bot | Ruleset screenshot or export |
| G-2 | MFA for every person with access to the GitHub org and the Anthropic Console org is not evidenced | **Yes**. Defense Access requires MFA | Repo Owner (GitHub), CVP Key Custodian (Console) | Turn on *Require two-factor authentication* for the `MSApps-Mobile` GitHub org. Enforce MFA/SSO for the Anthropic Console org. Remove members who are not enrolled | Org security settings screenshots. Member list showing 2FA status |
| G-3 | Phishing-resistant MFA (passkeys / FIDO2 security keys), required by the program from **2026-12-15** | **Yes** (from 2026-12-15) | Repo Owner, CVP Key Custodian | Enroll a passkey or security key for every CVP user on GitHub and on the identity provider behind the Console. Remove SMS/TOTP as a fallback for those accounts. Target date: 2026-12-01 | Per-user enrollment record (who, method, date) |
| G-4 | Interim API key handling (until 2026-12-15) is not documented. Each key must be (a) in a secrets manager, (b) assigned to exactly one person or workload, (c) out of source code, (d) rotated at least every **7 days** | **Yes** (Defense Access) | CVP Key Custodian | Pick one secrets manager (a human decision; record the product name here). Create a dedicated Console workspace for CVP. Issue one key per person/workload, named `<role-or-workload>-<yyyymmdd>`. Set a recurring 7-day rotation reminder or automation. Delete superseded keys at each rotation. Never put a key in this repo: C-2, C-4 and C-5 are the backstop | Key inventory (key name → owner → created → last rotated), *without key values*. Rotation log |
| G-5 | No named security contact. SECURITY.md routes reports to GitHub advisories only | **Yes** for higher tiers. Recommended for Defense Access | Repo Owner | Name a primary and a backup Security Contact. Use a role mailbox (for example `security@` on our domain) that reaches both. Add the mailbox to SECURITY.md once it exists | SECURITY.md diff. Mailbox membership |
| G-6 | No per-user/workload attribution of Claude API traffic | **Yes** for higher tiers. G-4's one-key-per-owner rule gives this for Defense Access | CVP Key Custodian | Use one key per person/workload in the CVP workspace (G-4). Record the key name in the eval/run logs (`evals/cvp/run.py` already records model, scenario and timestamp; add the key name, not the key) | Console usage report by key, matched to the inventory |
| G-7 | No retention or monitoring of CVP traffic. Nothing collects prompts, responses or request IDs centrally | **Yes** (all tiers) | Security Contact | Keep a per-request log for CVP work: timestamp, person/workload, API key *name*, request ID, model, task/scenario, outcome (pass / model refusal / classifier block). Store it in an access-controlled location outside this public repo. Retention period: a human sets it (proposal: 1 year). Review weekly for misuse and for classifier blocks. `evals/cvp/run.py` writes this format for eval runs | Log location and access list. Weekly review notes |
| G-8 | No written incident-response procedure beyond vulnerability intake (for example: leaked API key, CVP misuse, compromised account) | **Yes** for higher tiers | Security Contact | Write a one-page runbook (detect → revoke key / suspend account → assess → notify Anthropic and affected users → record). Best-effort response times, matching SECURITY.md. No 24/7 promise | `docs/security/incident-response.md` (future PR) |
| G-9 | "No shared sign-ins" is not evidenced for GitHub, the Console, or the secrets manager | **Yes** for higher tiers. Good practice for Defense Access | Repo Owner, CVP Key Custodian | Audit members of all three. Replace any shared or team login with named accounts. Shared automation uses its own workload key (G-4) | Member lists (names only) |
| G-10 | No automated dependency updates (`.github/dependabot.yml` absent). GitHub Actions are pinned by tag, not commit SHA | No | Maintainer | Add a `dependabot.yml` for `github-actions` (and for each plugin ecosystem with a lockfile). Pin third-party actions (`softprops/action-gh-release`) to a SHA | The config file. Dependabot PRs |
| G-11 | Releases are not cryptographically signed | No (out of CVP scope; listed for completeness) | Repo Owner | Consider artifact attestations (`actions/attest-build-provenance`) for `.plugin` files | Attestation on a release |

## What a human must do before this page can be relied on

1. Capture the VERIFY evidence for C-1 and C-2 from repo settings.
2. Assign people to the roles above (in the application, not in this public repo).
3. Close G-2, G-4, G-5, G-6, G-7, G-8 and G-9 before applying for Defense Access. Close G-3 before 2026-12-15. G-7 applies even if we stay on default access.
4. Re-date this page (*Last reviewed*) at each change.

_Last reviewed: 2026-10-15, by an automated readiness pass. Not yet reviewed by a human._
