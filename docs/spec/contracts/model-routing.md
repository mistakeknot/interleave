# Model Routing

**Spec section:** Contracts
**Status:** Required for Core + Routing conformance

---

## Overview

Different island types have different quality requirements. Routing each island to the appropriate model tier optimizes cost without sacrificing quality where it matters.

## Tier Guidelines

| Island Type | Recommended Tier | Rationale |
|---|---|---|
| Thematic grouping / clustering | Sonnet-class | Semantic judgment needed for coherent, non-overlapping groups |
| Factual summarization | Haiku-class | Extractive task — cheap, fast, sufficient quality |
| Synthesis from titles/keywords | Haiku-class | Pattern matching from explicit inputs, not deep reasoning |
| Creative writing / vision | Opus-class | Quality and voice matter more than cost |
| Classification / tagging | Haiku-class | Simple categorical judgment from clear criteria |
| Cross-referencing / deduplication | Haiku-class | Mechanical comparison with light judgment |
| Multi-source analysis | Sonnet-class | Needs to weigh and integrate diverse inputs coherently |

## Heuristic Selection

When the orchestrator cannot determine island type from metadata alone, apply keyword heuristics to the Task field:

| Task Keywords | Inferred Tier |
|---|---|
| "group", "cluster", "categorize", "organize" | Sonnet-class |
| "summarize", "describe", "list", "extract" | Haiku-class |
| "synthesize", "analyze", "compare", "evaluate" | Sonnet-class |
| "write", "compose", "draft", "envision" | Opus-class |
| Default (no keyword match) | Haiku-class |

Implementations MAY override heuristics with explicit model hints in the placeholder context block.

## Cost Estimation

To evaluate whether the interleave pattern saves tokens for a given document:

**Full regeneration cost:**
```
full_regen_cost = total_doc_tokens × orchestrator_model_rate
```

**Interleave cost:**
```
island_cost = Σ (island_input_tokens + island_output_tokens) × island_model_rate
```

The pattern is cost-effective when `island_cost < full_regen_cost`. Given that island inputs are a subset of the full document, and cheaper models handle most islands, the ratio typically favors interleave by 3-5x for documents with ≥60% deterministic content.

## Reference: Roadmap Islands

| Island | Tier | Input Tokens | Output Tokens | Rationale |
|--------|------|-------------|--------------|-----------|
| NEXT_GROUPINGS | Sonnet | ~800 | ~600 | Thematic grouping of 30-60 P2 items |
| MODULE_HIGHLIGHTS | Haiku | ~400 | ~300 | Factual summaries from item titles |
| RESEARCH_AGENDA | Haiku | ~300 | ~400 | Synthesis from file title lists |

Total island cost: ~2,800 tokens across 3 subagents, vs. ~15,000 tokens for full LLM regeneration.
