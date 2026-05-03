---
name: token-efficiency-audit
description: Run a comprehensive token-efficiency audit on Claude usage patterns — identify input/output token waste, context-window inefficiency, low cache-hit rates, and surface 11 standard optimization patterns (O6a-O6e). Use when the user wants to audit token spend, profile prompt cost, or align with SOSA Level 3+ token-economy requirements.
---

# Token Efficiency Audit Skill

## Overview
This skill performs a comprehensive token efficiency audit on Claude usage patterns, identifying optimization opportunities and generating actionable recommendations aligned with SOSA Level 3+ requirements.

## Metadata
- **Skill ID**: token-efficiency-audit
- **Version**: 1.0.0
- **SOSA Level**: 3 (Secured + Supervised)
- **Audit Coverage**: Input tokens, output tokens, context window efficiency, cache hit rates
- **Optimization Patterns**: 11 standard patterns (O6a-O6e categories, including O6c-4 Redundant Context Detection)

## Execution Model: Plan → Act → Verify

### Phase 1: Plan
Analyze audit scope and establish baseline metrics:

1. **Define Audit Boundaries**
   - Time period (last 30 days, last quarter, custom range)
   - User/team scope (individual, department, organization)
   - Model coverage (Claude 3 family, multimodal, specific versions)
   - Environment (production, staging, development)

2. **Establish Baselines**
   - Current token consumption (daily, weekly, monthly averages)
   - Cost per 1M tokens (input, output, cache read/write)
   - Context window utilization rate
   - Cache effectiveness metrics

3. **Define Success Metrics**
   - Target reduction percentage (typically 15-30%)
   - Cost ceiling per operation
   - Latency targets
   - Quality thresholds (accuracy/helpfulness maintenance)

### Phase 2: Act
Execute optimization analysis against 10 standard patterns:

1. **Pattern Categories**
   - **O6a**: Prompt compression and summarization
   - **O6b**: Context window optimization
   - **O6c**: Batch processing and request consolidation
   - **O6d**: Cache strategy optimization
   - **O6e**: Model selection and routing

2. **Analysis Steps**
   - Extract top 20% highest-cost interactions (80/20 analysis)
   - Apply each pattern category to high-cost interactions
   - Calculate theoretical token savings
   - Identify implementation complexity and risk
   - Apply O6c-4 (Redundant Context Detection): check marketplace plugins against built-in features and user commands for duplicates; classify MCP connectors as filterable (`.mcp.json`) vs non-filterable (`mcp__claude_ai_*`)

3. **Output Generation**
   - Pattern match report (which patterns apply to which usage)
   - Per-interaction optimization scores
   - Implementation priority matrix
   - Risk assessment per recommendation

### Phase 3: Verify
Validate recommendations and measure impact:

1. **Validation Checks**
   - Ensure recommended changes maintain output quality
   - Verify SOSA compliance (security, audit, supervision)
   - Confirm implementation feasibility
   - Cross-reference with compliance checklist

2. **Impact Measurement**
   - Projected token savings (conservative, realistic, optimistic)
   - Cost impact (absolute $ and % reduction)
   - Latency impact (positive/negative/neutral)
   - Implementation effort (hours, complexity)

3. **Recommendations Ranking**
   - Quick wins (high savings, low effort)
   - Strategic optimizations (medium savings, medium effort)
   - Long-term improvements (lower immediate impact, architectural)

## Key Metrics

### Token Efficiency Score
```
Score = (Baseline Tokens - Recommended Tokens) / Baseline Tokens × 100
Range: 0-100%
Target: 20-35% for mature systems
```

### Implementation Priority
```
Priority = (Projected Savings × Feasibility) / (Effort × Risk)
Sort descending for execution order
```

## Optimization Patterns Reference
See `references/optimization-patterns.md` for detailed pattern descriptions, implementation examples, and per-pattern token savings estimates.

## Integration Points
- **Supervised**: All recommendations require human review before implementation
- **Orchestrated**: Integrates with SOSA compliance checker for security review
- **Secured**: Prompt injection scanning on all extracted text samples
- **Agents**: Supports multi-turn analysis with refinement iterations

## Audit Report Structure
```json
{
  "audit_id": "aud-2026-0329-001",
  "created_at": "2026-03-29T12:00:00Z",
  "scope": {},
  "baseline_metrics": {},
  "pattern_analysis": {},
  "recommendations": [],
  "compliance_status": "APPROVED",
  "next_review": "2026-06-29"
}
```

## Success Criteria
- All recommendations achieve at least 10% token reduction
- Compliance checks pass 100% (no security/audit failures)
- Implementation priority matrix clearly ranked
- Report includes both quick wins and strategic optimizations
- Baseline metrics captured for post-implementation measurement
