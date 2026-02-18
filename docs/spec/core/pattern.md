# The Interleave Pattern

**Spec section:** Core
**Status:** Required for all conformance levels

---

## Problem

LLM-driven document generation regenerates entire documents from scratch, even when 60-80% of the content is a deterministic function of structured data. A roadmap's module table, bead item lists, dependency chains, and counts are all computable from JSON and database queries — yet a full LLM pass spends tokens re-deriving this content every time.

This wastes tokens (cost), introduces inconsistencies (the LLM may hallucinate counts or reformat tables), and prevents caching (the entire document is non-deterministic).

## Solution

**Separate deterministic content from semantic content at the document level.**

1. A **template script** (bash, Python, or any language) reads structured data sources and renders all deterministic sections directly.
2. Sections requiring LLM judgment are emitted as **placeholder markers** — HTML comments containing embedded context for the LLM.
3. An **orchestrator** scans the templated output, extracts each placeholder's context, and dispatches independent subagents to fill them.
4. Each subagent receives only its placeholder's embedded context — not the full document.
5. The orchestrator replaces each placeholder block with the subagent's output.

The result: the LLM processes only the semantic islands (~20-40% of the document), while deterministic sections are byte-exact and cacheable.

## The 5-Step Lifecycle

### Step 1: Generate Structured Data

Collect all source data into a structured format (JSON, database rows, file listings). This is the **single source of truth** for deterministic sections.

Examples: `roadmap.json` from repo scanning, `bd --json stats` from beads, `package.json` metadata.

### Step 2: Template the Skeleton

Run the template script against the structured data. The script outputs a complete document where:
- Deterministic sections are fully rendered (tables, lists, counts, dates)
- Semantic sections are `<!-- LLM:NAME -->` placeholder blocks containing Task, Format, and embedded context

### Step 3: Read the Templated Output

The orchestrator (skill, script, or agent) reads the templated document and scans for all `<!-- LLM:` opening tags.

### Step 4: Fill Placeholders

For each placeholder:
1. Extract the Task, Format, and embedded context from the comment block
2. Select a model tier based on the island type (see [model-routing.md](../contracts/model-routing.md))
3. Dispatch a subagent with only the extracted context
4. Receive the subagent's output

Independent islands can be filled concurrently.

### Step 5: Write Final Document

Replace each `<!-- LLM:NAME ... END LLM:NAME -->` block with the subagent's output. Write the final document.

## When to Use

Use the interleave pattern when:

- **≥50% deterministic content** — the document has a majority of sections derivable from structured data
- **Structured data sources exist** — JSON files, database queries, file listings, git history
- **Document is ≥50 lines** — the overhead of the pattern (template script + orchestration) is justified
- **Repeated generation** — the document will be regenerated multiple times (roadmap refreshes, status reports)
- **Consistency matters** — deterministic sections must match source data exactly (counts, versions, dates)

## When Not to Use

Do not use the interleave pattern when:

- **Fully creative documents** — vision docs, brainstorms, design explorations where everything needs LLM judgment
- **No structured data sources** — the document doesn't derive from queryable sources
- **Documents under 50 lines** — the pattern overhead exceeds the savings
- **One-shot generation** — the document will be generated once and never refreshed
- **<30% deterministic content** — the template script handles too little to justify its maintenance

## Token Savings Model

```
savings_ratio = deterministic_tokens / total_tokens
```

Aim for a savings ratio >0.60 to justify the pattern overhead. Below 0.40, the template script's maintenance cost likely exceeds the per-generation savings.

**Worked example (Interverse roadmap):**

| Component | Tokens | Notes |
|-----------|--------|-------|
| Full LLM generation | ~15,000 | Entire document regenerated |
| Template script output | ~10,000 | Deterministic (free, no LLM cost) |
| LLM island inputs | ~3,000 | 3 placeholders with embedded context |
| LLM island outputs | ~2,000 | Subagent responses |
| **Total with interleave** | **~5,000** | Island inputs + outputs only |
| **Savings** | **~10,000** | 67% reduction |

## Prior Art

The interleave pattern draws from three established ideas:

- **Microsoft Guidance** — interleaved generation where deterministic text and LLM generations alternate within a single output stream. Interleave extends this to document-scale sections rather than token-level interleaving. ([github.com/microsoft/guidance](https://github.com/microsoft/guidance))

- **Skeleton-of-Thought** (Ning et al., ICLR 2024) — parallel decoding where an LLM first generates a skeleton outline, then fills each point concurrently. Interleave inverts this: the skeleton is deterministic (no LLM needed), and only the fill step uses LLMs. ([arxiv.org/abs/2307.15337](https://arxiv.org/abs/2307.15337))

- **Islands Architecture** (Astro.js) — static HTML pages with interactive "islands" of JavaScript. Interleave applies the same principle to documents: static deterministic content with semantic "islands" of LLM generation. ([docs.astro.build/en/concepts/islands](https://docs.astro.build/en/concepts/islands/))
