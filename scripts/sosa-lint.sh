#!/bin/bash
# SOSA Compliance Linter for MSApps Skills & Plugins
# Checks all plugins and skills against the SOSA four-pillar checklist
# Exit code 0 = all pass, 1 = failures found

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
CHECKED=0

log_pass() { echo -e "  ${GREEN}✓${NC} $1"; }
log_fail() { echo -e "  ${RED}✗${NC} $1"; ((++ERRORS)); }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((++WARNINGS)); }

check_plugin() {
  local dir="$1"
  local name=$(basename "$dir")
  ((++CHECKED))
  echo ""
  echo "━━━ Plugin: $name ━━━"

  # === PILLAR 1: SUPERVISED ===
  # Check for SKILL.md with role spec
  local has_skill=false
  while IFS= read -r skill_file; do
    has_skill=true
    # Check role specification exists
    if grep -qi "trigger\|when to use\|use this skill\|description" "$skill_file" 2>/dev/null; then
      log_pass "Supervised: Role spec found in $(basename $(dirname "$skill_file"))/SKILL.md"
    else
      log_fail "Supervised: SKILL.md missing role specification (triggers/when to use)"
    fi
  done < <(find "$dir" -name "SKILL.md" 2>/dev/null)

  if [ "$has_skill" = false ]; then
    log_fail "Supervised: No SKILL.md found — every plugin must define its role"
  fi

  # === PILLAR 2: ORCHESTRATED ===
  # Check for dependency declarations
  if [ -f "$dir/.mcp.json" ]; then
    log_pass "Orchestrated: MCP dependency manifest (.mcp.json) exists"
  elif [ -f "$dir/.claude-plugin/plugin.json" ]; then
    log_pass "Orchestrated: Plugin manifest exists"
  else
    log_warn "Orchestrated: No dependency manifest (.mcp.json or plugin.json)"
  fi

  # Check SKILL.md is lean (token efficiency)
  while IFS= read -r skill_file; do
    local wc=$(wc -w < "$skill_file" | tr -d ' ')
    if [ "$wc" -gt 2000 ]; then
      log_warn "Orchestrated: $(basename $(dirname "$skill_file"))/SKILL.md is $wc words — consider trimming for token efficiency (target <2000)"
    else
      log_pass "Orchestrated: SKILL.md is lean ($wc words)"
    fi
  done < <(find "$dir" -name "SKILL.md" 2>/dev/null)

  # === PILLAR 3: SECURED ===
  # Check no hardcoded secrets
  local secrets_found=false
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      secrets_found=true
      log_fail "Secured: Potential hardcoded secret in $line"
    fi
  done < <(grep -rn "api_key\s*=\s*['\"].\+['\"]\\|apiKey\s*[:=]\s*['\"].\{20,\}['\"]\\|password\s*=\s*['\"].\+['\"]\\|token\s*=\s*['\"].\{20,\}['\"]" "$dir" --include="*.md" --include="*.json" --include="*.ts" --include="*.js" --include="*.py" 2>/dev/null || true)

  if [ "$secrets_found" = false ]; then
    log_pass "Secured: No hardcoded secrets detected"
  fi

  # Check for .env files committed.
  # NOTE: .env.example / .env.sample / .env.template are TEMPLATES, not
  # secrets — they document required env vars and ship deliberately. Only
  # flag concrete .env files (and weird variants like .env.local that
  # could leak per-developer state).
  if find "$dir" \
       \( -name ".env" -o -name ".env.local" -o -name ".env.production" -o -name ".env.staging" -o -name ".env.development" \) \
       2>/dev/null | grep -q .; then
    log_fail "Secured: .env file found in plugin — credentials must not be committed"
  else
    log_pass "Secured: No .env files committed"
  fi

  # === PILLAR 4: AGENTS (RTMP tuple) ===
  # Check CLAUDE.md or README exists (broader role spec)
  if [ -f "$dir/CLAUDE.md" ] || [ -f "$dir/README.md" ]; then
    log_pass "Agents: Plugin documentation (CLAUDE.md/README.md) exists"
  else
    log_warn "Agents: No CLAUDE.md or README.md — consider adding plugin documentation"
  fi
}

check_skill() {
  local dir="$1"
  local name=$(basename "$dir")
  ((++CHECKED))
  echo ""
  echo "━━━ Skill: $name ━━━"

  if [ -f "$dir/SKILL.md" ]; then
    log_pass "Has SKILL.md"

    # Role spec check
    if grep -qi "trigger\|when to use\|use this skill\|description" "$dir/SKILL.md" 2>/dev/null; then
      log_pass "Supervised: Role spec defined"
    else
      log_fail "Supervised: SKILL.md missing role specification"
    fi

    # Token efficiency
    local wc=$(wc -w < "$dir/SKILL.md" | tr -d ' ')
    if [ "$wc" -gt 2000 ]; then
      log_warn "Orchestrated: SKILL.md is $wc words (target <2000)"
    else
      log_pass "Orchestrated: Lean skill ($wc words)"
    fi
  else
    log_fail "Missing SKILL.md"
  fi

  # Secret check
  if grep -rn "api_key\s*=\|apiKey.*:.*['\"].\{20,\}" "$dir" --include="*.md" 2>/dev/null | grep -q .; then
    log_fail "Secured: Potential hardcoded secret"
  else
    log_pass "Secured: Clean"
  fi
}

check_scheduled_task() {
  local dir="$1"
  local name=$(basename "$dir")
  ((++CHECKED))
  echo ""
  echo "━━━ Task: $name ━━━"

  if [ -f "$dir/SKILL.md" ]; then
    log_pass "Has SKILL.md"
  else
    log_fail "Missing SKILL.md — all scheduled tasks need a skill definition"
  fi
}

echo "╔══════════════════════════════════════════╗"
echo "║   SOSA™ Compliance Lint — MSApps Repo    ║"
echo "╚══════════════════════════════════════════╝"

REPO_ROOT="${1:-.}"

# Check plugins
echo ""
echo "🔌 PLUGINS"
echo "=========="
for plugin_dir in "$REPO_ROOT"/plugins/*/; do
  [ -d "$plugin_dir" ] && check_plugin "$plugin_dir"
done

# Check skills
echo ""
echo "🧠 SKILLS"
echo "========="
for skill_dir in plugins/*/; do
  [ -d "$skill_dir" ] && [ "$(basename "$skill_dir")" != "standalone" ] && check_skill "$skill_dir"
done

# Check scheduled tasks
echo ""
echo "⏰ SCHEDULED TASKS"
echo "=================="
for task_dir in "$REPO_ROOT"/scheduled-tasks/*/; do
  [ -d "$task_dir" ] && check_scheduled_task "$task_dir"
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Checked: $CHECKED items"
echo -e "Passed:  ${GREEN}$((CHECKED * 4 - ERRORS - WARNINGS))${NC}"
echo -e "Errors:  ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}SOSA lint FAILED — fix errors before merging${NC}"
  exit 1
else
  echo -e "${GREEN}SOSA lint PASSED${NC}"
  exit 0
fi
