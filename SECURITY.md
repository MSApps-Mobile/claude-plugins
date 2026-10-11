# Security Policy

This repository is a public marketplace of Claude Code plugins maintained by MSApps / OpsAgents AI,
built around the SOSA™ (Supervised, Orchestrated, Secured Agents) methodology.

This page states only what is actually in place. If something is not listed here, do not assume it exists.

## Reporting a vulnerability

Please report vulnerabilities **privately** through GitHub:
**[Report a vulnerability](https://github.com/MSApps-Mobile/claude-plugins/security/advisories/new)**
(the repository's *Security* tab → *Report a vulnerability*).

Please include:
- the affected plugin and version (or commit),
- steps to reproduce,
- the impact you observed or expect.

Do not open a public issue for a security problem, and please give us a chance to fix it before you
disclose it publicly.

We acknowledge reports on a best-effort basis, normally within a few business days, and we will tell you
whether we accept the report and what we plan to do about it. We are a small team: there is no 24/7
on-call rotation, and we do not run a bug bounty.

This address is for vulnerabilities in **this repository's plugins**. Issues in Claude, Claude Code or
other Anthropic products should go to Anthropic through its own disclosure channels, not to us.

## How these plugins run — read before installing

- A plugin runs **inside Claude Code on your machine, with your permissions**. Its skills, commands, hooks
  and MCP servers can do what Claude Code is allowed to do in your session. We do not sandbox plugins
  from each other or from your system.
- Review a plugin's files before you install it — especially `hooks/`, any MCP server definitions, and any
  script a skill tells Claude to run.
- Plugins that talk to external services expect you to provide your own credentials. Keep them in your own
  secret store or environment; never commit them to a plugin.

## What we do today

- **Review before merge.** Changes reach `main` through pull requests, which are reviewed before they merge.
- **Automated checks on every PR** (`.github/workflows/`):
  - `validate-pr.yml` — runs `claude plugin validate` on changed plugins and checks that the marketplace
    manifest covers every plugin directory;
  - `sosa-lint.yml` — the SOSA™ four-pillar lint and evaluation scores for each plugin;
  - both workflows include a pattern scan that fails the build on hardcoded API keys, passwords and tokens.
- **GitHub secret scanning** with push protection is enabled on this repository.
- **Releases** are tagged per plugin by `release.yml` when a plugin changes on `main`. Releases are not
  cryptographically signed.
- **Secrets.** No plugin in this repository should contain a credential. If you find one, report it as a
  vulnerability (above).

## What we do not have

To be explicit: we do not hold a SOC 2, ISO 27001 or similar certification, we have not commissioned a
third-party penetration test of this repository, and we do not operate a SIEM or a dedicated incident
response team. If that changes, this page will say so with a date.

## Supported versions

Only the latest release of each plugin is supported. Fixes are released as new plugin versions; update
by reinstalling or updating the plugin from the marketplace.
