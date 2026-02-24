# Interleave Pattern Specification

**Version:** 0.1.0
**Status:** Initial Specification
**Reference Implementation:** [interleave](https://github.com/mistakeknot/interleave) (Claude Code plugin)

---

## What this Is

Interleave is a **token-efficient document generation pattern** that separates deterministic content (renderable from structured data) from semantic content (requiring LLM judgment). A template script renders the deterministic skeleton and emits `<!-- LLM:NAME -->` placeholder markers for sections needing intelligence. An orchestrator then fills each placeholder independently, dispatching subagents with only the embedded context: not the full document.

## Audience

This spec serves two audiences:

- **AI tool developers** building document generators where most content derives from structured data (JSON, databases, file listings). The pattern is framework-agnostic; the interleave plugin provides a Claude Code reference implementation, but the placeholder format and lifecycle work in any system.

- **Interverse contributors** building new artifact templates (PRDs, changelogs, status reports). The spec codifies the pattern proven by `template-roadmap-md.sh` so future templates follow consistent conventions.

## Documents

### Core (Required)

| Document | Description |
|----------|-------------|
| [core/pattern.md](core/pattern.md) | The pattern definition: problem, solution, 5-step lifecycle, when to use, token savings model, prior art. |
| [core/analysis.md](core/analysis.md) | How to classify document sections as deterministic, semantic, or hybrid. Decision flowchart and worked examples. |
| [core/orchestration.md](core/orchestration.md) | Placeholder filling lifecycle: scanning, context extraction, model selection, dispatch, replacement, error handling. |

### Contracts (Required)

| Document | Description |
|----------|-------------|
| [contracts/placeholder.md](contracts/placeholder.md) | The `<!-- LLM:NAME -->` format specification: opening/closing tags, required fields, uniqueness rules. |
| [contracts/model-routing.md](contracts/model-routing.md) | Model tier selection guidelines per island type, with cost estimation formulas. |

## Conformance levels

An implementation can claim conformance at three levels:

### interleave-spec 0.1 Core

Implements:
- `<!-- LLM:NAME -->` placeholder format per [contracts/placeholder.md](contracts/placeholder.md)
- 5-step filling lifecycle per [core/orchestration.md](core/orchestration.md)
- Error handling: unfilled placeholders marked with `<!-- WARNING: LLM:NAME unfilled -->`
- Graceful degradation: template failure falls back to full LLM generation

### interleave-spec 0.1 Core + Routing

Additionally implements:
- Model tier selection per island type per [contracts/model-routing.md](contracts/model-routing.md)
- Cost estimation: `island_cost` vs. `full_regen_cost` comparison

### interleave-spec 0.1 Core + Analysis

Additionally implements:
- Section classification heuristics per [core/analysis.md](core/analysis.md)
- Deterministic/semantic/hybrid taxonomy
- Decision flowchart for new document types

## Versioning

This spec uses [Semantic Versioning](https://semver.org/):

- **Major** (1.0, 2.0): Breaking changes to placeholder format or lifecycle
- **Minor** (0.2, 0.3): New contracts, non-breaking additions to core
- **Patch** (0.1.1, 0.1.2): Clarifications, typo fixes, example additions

The spec version is independent of the interleave plugin version.

## Reading order

For newcomers:

1. **This README**: understand what the pattern is and conformance levels
2. **[core/pattern.md](core/pattern.md)**: the pattern definition (the big picture)
3. **[contracts/placeholder.md](contracts/placeholder.md)**: the placeholder format (the interface)
4. **[core/analysis.md](core/analysis.md)**: how to classify sections
5. **[contracts/model-routing.md](contracts/model-routing.md)**: which model for which island
6. **[core/orchestration.md](core/orchestration.md)**: the filling lifecycle

## Directory structure

```
docs/spec/
├── README.md                          # This file
├── core/
│   ├── pattern.md                     # Pattern definition + lifecycle
│   ├── analysis.md                    # Section classification
│   └── orchestration.md               # Placeholder filling lifecycle
└── contracts/
    ├── placeholder.md                 # Placeholder format spec
    └── model-routing.md               # Model tier selection
```
