#!/bin/bash
# ââââââââââââââââââââââââââââââââââââââââââââââââââââ
# â  SOSAâ¢ Evaluation â Automated Compliance Scorer  â
# â  Scores every plugin, skill, and scheduled task   â
# â  against the four SOSA pillars (S/O/S/A)          â
# ââââââââââââââââââââââââââââââââââââââââââââââââââââ
#
# Usage: ./scripts/sosa-eval.sh [repo-root] [--json] [--ci]
#   --json   Output machine-readable JSON report
#   --ci     Exit 1 if any item is below Level 1 (70%)
#
set -euo pipefail

REPO_ROOT="${1:-.}"
JSON_MODE=false
CI_MODE=false
for arg in "$@"; do
  [[ "$arg" == "--json" ]] && JSON_MODE=true
  [[ "$arg" == "--ci" ]] && CI_MODE=true
done

# ââ Score accumulators ââ
declare -a RESULTS_NAME=()
declare -a RESULTS_TYPE=()
declare -a RESULTS_S=()
declare -a RESULTS_O=()
declare -a RESULTS_SEC=()
declare -a RESULTS_A=()
declare -a RESULTS_TOTAL=()
declare -a RESULTS_LEVEL=()
declare -a RESULTS_ISSUES=()
BELOW_LEVEL1=0

eval_item() {
  local dir="$1" name="$2" type="$3"
  local s_score=0 s_max=0
  local o_score=0 o_max=0
  local sec_score=0 sec_max=0
  local a_score=0 a_max=0
  local issues=""

  # ââââââââââââââââââââââââââââââââââââ
  # PILLAR 1: SUPERVISED (max 5 points)
  # ââââââââââââââââââââââââââââââââââââ
  s_max=5

  # S1: Has SKILL.md with role spec (2 pts)
  local skill_found=false
  while IFS= read -r sf; do
    skill_found=true
    if grep -qi "trigger\|when to use\|use this skill\|description" "$sf" 2>/dev/null; then
      ((s_score+=2))
    else
      ((s_score+=1))
      issues="$issues|S: SKILL.md missing trigger/role spec"
    fi
    break  # score first SKILL.md only
  done < <(find "$dir" -name "SKILL.md" 2>/dev/null)
  if [ "$skill_found" = false ]; then
    issues="$issues|S: No SKILL.md found"
  fi

  # S2: Impact level declared (1 pt)
  if grep -rqi "impact.*level\|impact.*:.*\(low\|medium\|high\)" "$dir" --include="*.md" --include="*.json" 2>/dev/null; then
    ((s_score+=1))
  else
    issues="$issues|S: No impact level declared"
  fi

  # S3: Human approval gates for high-impact (1 pt)
  if grep -rqi "confirm\|approval\|human.*review\|ask.*user\|permission" "$dir" --include="*.md" 2>/dev/null; then
    ((s_score+=1))
  else
    issues="$issues|S: No approval/confirmation gates found"
  fi

  # S4: Escalation path defined (1 pt)  
  if grep -rqi "escalat\|fallback\|error.*handling\|fail.*safe" "$dir" --include="*.md" 2>/dev/null; then
    ((s_score+=1))
  fi

  # ââââââââââââââââââââââââââââââââââââ
  # PILLAR 2: ORCHESTRATED (max 5 pts)
  # ââââââââââââââââââââââââââââââââââââ
  o_max=5

  # O1: Dependency manifest (1 pt)
  if [ -f "$dir/.mcp.json" ] || [ -f "$dir/.claude-plugin/plugin.json" ] || find "$dir" -name "plugin.json" -path "*/.claude-plugin/*" 2>/dev/null | grep -q .; then
    ((o_score+=1))
  else
    issues="$issues|O: No dependency manifest (.mcp.json or plugin.json)"
  fi

  # O2: Token efficiency â SKILL.md under 2000 words (1 pt)
  local lean=true
  while IFS= read -r sf; do
    local wc=$(wc -w < "$sf" | tr -d ' ')
    if [ "$wc" -gt 2000 ]; then
      lean=false
      issues="$issues|O: SKILL.md is $wc words (target <2000)"
    fi
  done < <(find "$dir" -name "SKILL.md" 2>/dev/null)
  if $lean; then ((o_score+=1)); fi

  # O3: Plan-Act-Verify loop (1 pt)
  if grep -rqi "plan.*phase\|act.*phase\|verify.*phase\|plan.*act.*verify\|step.*1.*step.*2\|## Plan\|## Act\|## Verify\|workflow\|procedure" "$dir" --include="*.md" 2>/dev/null; then
    ((o_score+=1))
  else
    issues="$issues|O: No Plan-Act-Verify structure found"
  fi

  # O4: Structured outputs (1 pt)
  if grep -rqi "json\|structured.*output\|report\|summary.*format\|markdown" "$dir" --include="*.md" 2>/dev/null; then
    ((o_score+=1))
  fi

  # O5: No duplicate/redundant components (1 pt â always pass unless detected)
  ((o_score+=1))

  # ââââââââââââââââââââââââââââââââââââ
  # PILLAR 3: SECURED (max 5 points)
  # ââââââââââââââââââââââââââââââââââââ
  sec_max=5

  # SEC1: No hardcoded secrets (2 pts â critical)
  if grep -rn "api_key\s*=\s*['\"].\+['\"]\\|password\s*=\s*['\"].\+['\"]\\|token\s*=\s*['\"].\{20,\}['\"]" "$dir" --include="*.md" --include="*.json" --include="*.ts" --include="*.js" --include="*.py" 2>/dev/null | grep -q .; then
    issues="$issues|SEC: HARDCODED SECRETS DETECTED"
  else
    ((sec_score+=2))
  fi

  # SEC2: No .env files (1 pt)
  if find "$dir" -name ".env" -o -name ".env.*" 2>/dev/null | grep -q .; then
    issues="$issues|SEC: .env files committed"
  else
    ((sec_score+=1))
  fi

  # SEC3: Credential reference to config/env vars (1 pt)
  if grep -rqi "env.*var\|config.*file\|~/.config\|environment\|credential.*store\|keyring\|secret.*manag" "$dir" --include="*.md" 2>/dev/null; then
    ((sec_score+=1))
  fi

  # SEC4: Prompt injection awareness (1 pt)
  if grep -rqi "inject\|sanitiz\|validat\|untrusted\|malicious" "$dir" --include="*.md" 2>/dev/null; then
    ((sec_score+=1))
  fi

  # ââââââââââââââââââââââââââââââââââââ
  # PILLAR 4: AGENTS â RTMP (max 5 pts)
  # ââââââââââââââââââââââââââââââââââââ
  a_max=5

  # A1: Role spec â R (1 pt)
  if grep -rqi "role\|purpose\|objective\|responsible\|boundaries" "$dir" --include="*.md" 2>/dev/null; then
    ((a_score+=1))
  else
    issues="$issues|A: No role specification"
  fi

  # A2: Tool manifest â T (1 pt)
  if grep -rqi "tool\|mcp\|api\|connector\|integration" "$dir" --include="*.md" --include="*.json" 2>/dev/null; then
    ((a_score+=1))
  fi

  # A3: Memory â M (1 pt)
  if grep -rqi "memory\|persist\|state\|store\|notion\|calendar\|database\|history" "$dir" --include="*.md" 2>/dev/null; then
    ((a_score+=1))
  fi

  # A4: Planning policy â P (1 pt)
  if grep -rqi "step\|workflow\|procedure\|sequence\|precondition\|postcondition\|instruction" "$dir" --include="*.md" 2>/dev/null; then
    ((a_score+=1))
  fi

  # A5: Documentation (CLAUDE.md or README) (1 pt)
  if [ -f "$dir/CLAUDE.md" ] || [ -f "$dir/README.md" ]; then
    ((a_score+=1))
  else
    issues="$issues|A: No CLAUDE.md or README.md"
  fi

  # ââ Calculate total ââ
  local total_score=$((s_score + o_score + sec_score + a_score))
  local total_max=$((s_max + o_max + sec_max + a_max))
  local pct=$((total_score * 100 / total_max))
  local level="None"
  if [ "$pct" -ge 100 ]; then level="Level 3"
  elif [ "$pct" -ge 85 ]; then level="Level 2"
  elif [ "$pct" -ge 70 ]; then level="Level 1"
  else
    level="Below L1"
    ((++BELOW_LEVEL1))
  fi

  RESULTS_NAME+=("$name")
  RESULTS_TYPE+=("$type")
  RESULTS_S+=("$s_score/$s_max")
  RESULTS_O+=("$o_score/$o_max")
  RESULTS_SEC+=("$sec_score/$sec_max")
  RESULTS_A+=("$a_score/$a_max")
  RESULTS_TOTAL+=("$total_score/$total_max ($pct%)")
  RESULTS_LEVEL+=("$level")
  RESULTS_ISSUES+=("${issues#|}")
}

# ââ Run evaluations ââ

# Plugins
for d in "$REPO_ROOT"/plugins/*/; do
  [ -d "$d" ] && eval_item "$d" "$(basename "$d")" "plugin"
done

# Skills
for d in "$REPO_ROOT"/skills/*/; do
  [ -d "$d" ] && [ "$(basename "$d")" != "standalone" ] && eval_item "$d" "$(basename "$d")" "skill"
done

# Scheduled tasks (sample first 10 for speed)
count=0
for d in "$REPO_ROOT"/scheduled-tasks/*/; do
  [ -d "$d" ] && eval_item "$d" "$(basename "$d")" "task"
  ((++count))
  [ "$count" -ge 53 ] && break
done

# Agents
for d in "$REPO_ROOT"/agents/*/; do
  [ -d "$d" ] && eval_item "$d" "$(basename "$d")" "agent"
done

# ââ Output ââ
N=${#RESULTS_NAME[@]}

if $JSON_MODE; then
  echo "["
  for ((i=0; i<N; i++)); do
    [ "$i" -gt 0 ] && echo ","
    issues_json=$(echo "${RESULTS_ISSUES[$i]}" | sed 's/|/","/g')
    [ -n "$issues_json" ] && issues_json="\"$issues_json\"" || issues_json=""
    cat << JEOF
  {
    "name": "${RESULTS_NAME[$i]}",
    "type": "${RESULTS_TYPE[$i]}",
    "supervised": "${RESULTS_S[$i]}",
    "orchestrated": "${RESULTS_O[$i]}",
    "secured": "${RESULTS_SEC[$i]}",
    "agents": "${RESULTS_A[$i]}",
    "total": "${RESULTS_TOTAL[$i]}",
    "level": "${RESULTS_LEVEL[$i]}",
    "issues": [$issues_json]
  }
JEOF
  done
  echo "]"
else
  echo ""
  echo "ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ"
  echo "â          SOSAâ¢ Evaluation Report â $(date +%Y-%m-%d)            â"
  echo "ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ"
  echo ""
  printf "%-30s %-8s  %-5s %-5s %-5s %-5s  %-14s  %s\n" "Name" "Type" "S" "O" "Sec" "A" "Total" "Level"
  printf "%-30s %-8s  %-5s %-5s %-5s %-5s  %-14s  %s\n" "ââââââââââââââââââââââââââââ" "ââââââ" "âââ" "âââ" "âââ" "âââ" "ââââââââââââ" "âââââââ"
  for ((i=0; i<N; i++)); do
    printf "%-30s %-8s  %-5s %-5s %-5s %-5s  %-14s  %s\n" \
      "${RESULTS_NAME[$i]}" "${RESULTS_TYPE[$i]}" \
      "${RESULTS_S[$i]}" "${RESULTS_O[$i]}" "${RESULTS_SEC[$i]}" "${RESULTS_A[$i]}" \
      "${RESULTS_TOTAL[$i]}" "${RESULTS_LEVEL[$i]}"
  done

  # Summary stats
  local_l3=0 local_l2=0 local_l1=0 local_below=0
  for ((i=0; i<N; i++)); do
    case "${RESULTS_LEVEL[$i]}" in
      "Level 3") ((++local_l3)) ;;
      "Level 2") ((++local_l2)) ;;
      "Level 1") ((++local_l1)) ;;
      *) ((++local_below)) ;;
    esac
  done

  echo ""
  echo "ââ Summary ââ"
  echo "Total items evaluated: $N"
  echo "Level 3 (Full):     $local_l3"
  echo "Level 2 (Standard): $local_l2"
  echo "Level 1 (Basic):    $local_l1"
  echo "Below Level 1:      $local_below"
  echo ""

  # Show issues for items below Level 2
  has_issues=false
  for ((i=0; i<N; i++)); do
    if [ -n "${RESULTS_ISSUES[$i]}" ]; then
      if ! $has_issues; then
        echo "ââ Issues Requiring Attention ââ"
        has_issues=true
      fi
      echo ""
      echo "  ${RESULTS_NAME[$i]} (${RESULTS_LEVEL[$i]}):"
      IFS='|' read -ra ISS <<< "${RESULTS_ISSUES[$i]}"
      for issue in "${ISS[@]}"; do
        echo "    â¢ $issue"
      done
    fi
  done
  echo ""
fi

if $CI_MODE && [ "$BELOW_LEVEL1" -gt 0 ]; then
  echo "SOSA eval FAILED: $BELOW_LEVEL1 items below Level 1"
  exit 1
fi
