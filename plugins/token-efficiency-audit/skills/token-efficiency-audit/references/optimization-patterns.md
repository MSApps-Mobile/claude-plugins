# Token Optimization Patterns Catalog

## Overview
This catalog describes 10 standard token optimization patterns (organized as O6a-O6e categories) for Claude usage. Each pattern includes description, typical use cases, implementation complexity, estimated token savings, and code examples.

## O6a: Prompt Compression and Summarization

### Pattern O6a-1: Template Consolidation
**Description**: Combine multiple prompt fragments into single unified template with placeholders.
**Use Case**: Repeated instructions with variable inputs (e.g., classification, extraction tasks)
**Token Savings**: 20-40% (depends on instruction repetition factor)
**Implementation Effort**: Low (1-2 hours)
**Risk Level**: Low

Example savings: 500 token instructions → 300 tokens with templates

### Pattern O6a-2: Structured Format Optimization
**Description**: Use JSON/YAML instead of prose descriptions; use short codes instead of full descriptions.
**Use Case**: Data processing, configuration, examples with repetitive structure
**Token Savings**: 15-30%
**Implementation Effort**: Medium (2-4 hours)
**Risk Level**: Low

Example: "Please classify this as positive, negative, or neutral sentiment" → "Classify: [pos|neg|neutral]"

### Pattern O6a-3: Example Curation
**Description**: Use minimal sufficient examples (3-5) instead of comprehensive example sets.
**Use Case**: Few-shot learning, demonstration-based guidance
**Token Savings**: 25-50% (depends on example count)
**Implementation Effort**: Medium (3-5 hours for quality validation)
**Risk Level**: Medium (must maintain quality)

## O6b: Context Window Optimization

### Pattern O6b-1: Sliding Window Summarization
**Description**: Maintain running summary of conversation history, replacing older messages with digest.
**Use Case**: Long-running conversations, iterative refinement sessions
**Token Savings**: 30-60% (cumulative over conversation length)
**Implementation Effort**: Medium (3-4 hours)
**Risk Level**: Medium (context loss risk)

Example: After 10 exchanges, replace first 5 with 200-token summary

### Pattern O6b-2: Hierarchical Context
**Description**: Structure long documents with progressive disclosure—provide overview, let user request details.
**Use Case**: Documentation, research papers, legal documents, policy manuals
**Token Savings**: 40-70% (only relevant sections included per query)
**Implementation Effort**: Medium-High (4-6 hours planning)
**Risk Level**: Low

Example: Provide 1-page executive summary + section index vs. 50-page document upfront

### Pattern O6b-3: Background Information Caching
**Description**: Use prompt caching for stable background (system context, company policies, standards).
**Use Case**: Recurring task frameworks, knowledge bases, standard references
**Token Savings**: 50-90% (cache hits amortize overhead)
**Implementation Effort**: Medium (2-3 hours setup)
**Risk Level**: Low

## O6c: Batch Processing and Request Consolidation

### Pattern O6c-1: Bulk Classification
**Description**: Process 10-50 items in single request instead of separate requests.
**Use Case**: Content moderation, tagging, categorization, data labeling
**Token Savings**: 20-35% (per-request overhead reduction)
**Implementation Effort**: Low-Medium (1-3 hours)
**Risk Level**: Low

Example: Classify 20 items vs. 20 separate calls → 1 call with structured output

### Pattern O6c-2: Aggregated Batch Summarization
**Description**: Summarize multiple documents/sections in single pass instead of individual summaries.
**Use Case**: Report generation, content aggregation, intelligence synthesis
**Token Savings**: 25-40%
**Implementation Effort**: Low-Medium (2-3 hours)
**Risk Level**: Low-Medium

### Pattern O6c-3: Streaming Results
**Description**: Request partial results in streaming mode where applicable; accumulate in client.
**Use Case**: Long-form generation, interactive refinement, client-side aggregation
**Token Savings**: 10-20% (network efficiency, can stop early)
**Implementation Effort**: Medium-High (3-5 hours client integration)
**Risk Level**: Low

## O6d: Cache Strategy Optimization

### Pattern O6d-1: Prompt Cache Configuration
**Description**: Identify stable prompt components (system prompts, reference materials, examples).
**Use Case**: All recurring task types, multi-turn conversations, knowledge-intensive tasks
**Token Savings**: 50-90% (cache hits reduce input tokens to ~10% for cached portion)
**Implementation Effort**: Low-Medium (2-3 hours configuration)
**Risk Level**: Low

Example: System prompt (500 tokens) cached → 50 tokens effective cost per use (10x reduction)

### Pattern O6d-2: Segmented Caching
**Description**: Cache different components at different layers (system, company context, task context).
**Use Case**: Complex multi-layer prompts with varying stability
**Token Savings**: 60-80%
**Implementation Effort**: Medium-High (4-6 hours design)
**Risk Level**: Medium (cache invalidation complexity)

### Pattern O6d-3: Temporal Cache Invalidation
**Description**: Periodically refresh cached components; track cache freshness.
**Use Case**: System prompts with periodic updates, evolving knowledge bases
**Token Savings**: 40-70% (cache benefits minus refresh overhead)
**Implementation Effort**: Medium (3-4 hours)
**Risk Level**: Low-Medium

## O6e: Model Selection and Routing

### Pattern O6e-1: Task-Based Model Selection
**Description**: Use smaller/faster models (Claude 3 Haiku) for simple tasks, larger models for complex tasks.
**Use Case**: Multi-type workloads (classification, generation, reasoning)
**Token Savings**: 20-60% (mixed model approach)
**Implementation Effort**: Medium (2-4 hours classification logic)
**Risk Level**: Medium (must maintain quality)

Example: Use Haiku for moderation checks, Opus for nuanced reasoning

### Pattern O6e-2: Progressive Complexity Routing
**Description**: Try simple approach first, escalate only if needed.
**Use Case**: Customer support, content analysis, problem-solving
**Token Savings**: 30-50% (avoid expensive model for 70% of requests)
**Implementation Effort**: Medium (3-5 hours)
**Risk Level**: Medium (requires fallback logic)

### Pattern O6e-3: Batch Model Matching
**Description**: Analyze batch requirements before routing; select optimal model for batch parameters.
**Use Case**: Bulk processing, ETL pipelines, batch analytics
**Token Savings**: 25-45%
**Implementation Effort**: Low-Medium (2-3 hours)
**Risk Level**: Low

## Quick Wins (Implement First)
1. **O6a-1**: Prompt consolidation (20-40% savings, low effort)
2. **O6c-1**: Bulk classification (20-35% savings, low effort)
3. **O6d-1**: Prompt caching (50-90% on cached portions, low effort)

## Strategic Optimizations (Plan Next)
1. **O6b-1**: Sliding window summarization (30-60% over time)
2. **O6e-1**: Task-based model selection (20-60% mixed model)
3. **O6b-2**: Hierarchical context (40-70% on-demand)

## Implementation Sequence
1. **Week 1**: Deploy quick wins (O6a-1, O6c-1, O6d-1)
2. **Week 2-3**: Add strategic optimizations
3. **Month 2+**: Advanced patterns (O6b-1, O6e-2)
4. **Ongoing**: Monitor cache effectiveness, validate quality