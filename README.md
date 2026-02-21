# interleave

Deterministic Skeleton with LLM Islands — token-efficient document generation.

## What This Does

Most AI-generated documents waste tokens on parts that are entirely predictable. If you're generating a roadmap, the table of completed items, the version header, and the status counts are all deterministic — they come from data, not creativity. The creative parts (grouping analysis, highlight commentary, research agenda) are the only sections that actually need an LLM.

interleave formalizes this split. A template script renders all the deterministic sections and emits `<!-- LLM:NAME -->` placeholder markers for the semantic sections. A subagent then fills only the placeholders. The result is the same document at a fraction of the token cost.

This is a spec + library plugin. It defines the pattern, provides a reference implementation, and includes a skill for applying it. No MCP server, no hooks: just the pattern itself.

## Installation

```bash
/plugin install interleave
```

## Reference Implementation

`scripts/template-roadmap-md.sh` generates a full `docs/interverse-roadmap.md` from `roadmap.json` + beads data (legacy compatibility `docs/roadmap.md` when needed). It renders all deterministic sections directly and emits 3 LLM placeholder markers (NEXT_GROUPINGS, MODULE_HIGHLIGHTS, RESEARCH_AGENDA).

## Placeholder Format

```html
<!-- LLM:SECTION_NAME context="..." -->
(content to be filled by LLM)
<!-- END LLM:SECTION_NAME -->
```

HTML comments, invisible in rendered markdown. The `context` attribute gives the LLM enough information to fill the section without reading the whole document.

## Prior Art & Related Approaches

It's worth knowing where this pattern comes from, because "render the boring parts with a script and only call the LLM for the interesting parts" turns out to be an idea people keep independently reinventing across very different domains. The question is always the same — "what actually needs the expensive thing?" — and the answer is always "less than you think."

### Islands Architecture (the direct ancestor)

The most honest influence is [Astro's Islands Architecture](https://docs.astro.build/en/concepts/islands/). Astro renders pages as static HTML and only hydrates isolated "islands" of JavaScript where interactivity is actually needed. Everything outside an island ships zero JS. Interleave does the same thing but for documents and LLMs instead of pages and JavaScript: deterministic sections are rendered by a bash script (zero token cost), and only the semantic islands get dispatched to subagents.

The key insight worth borrowing is that **the static parts don't need to flow through the expensive runtime at all**. Not "use a cheaper runtime" — *no* runtime. Astro got this; most LLM document generators haven't.

A few related ideas from the same lineage:

- **React Server Components** draw a similar boundary between server-only components (rendered once, no client JS) and client components (hydrated). RSC's nice trick is that server components can pass serialized data *down* to client components — which is basically what interleave's embedded `context` attribute does for each placeholder. The LLM island gets exactly the data it needs, pre-serialized, no fishing.

- **Qwik** takes this further with resumability — instead of hydrating everything, it serializes component state into the HTML and lazily resumes only what the user actually interacts with. Where Astro makes you draw the island boundary by hand, Qwik tries to make it automatic. Interleave's [section classification flowchart](docs/spec/core/analysis.md) is a (much humbler) version of the same instinct: a systematic way to decide what needs LLM "hydration" rather than leaving it to vibes.

- **Marko** does out-of-order streaming — ships the static shell immediately, fills dynamic sections as their data resolves. This is conceptually identical to dispatching islands concurrently; the deterministic skeleton is available instantly and the semantic bits land whenever the subagents finish.

### Structured Generation (the token-level cousins)

[Microsoft Guidance](https://github.com/microsoft/guidance), LMQL, and SGLang all interleave deterministic text with LLM-generated text, but they do it at the *token* level within a single generation call. You write a template with `{{gen}}` blocks (or equivalent), and the framework alternates between emitting fixed tokens and sampling from the model.

Genuinely clever, but interleave operates at a coarser granularity on purpose. The deterministic parts of a roadmap aren't template literals inside a prompt — they're the output of `jq` queries and `bd` commands, rendered by a completely separate process that has nothing to do with an LLM. And the LLM calls are isolated per-section, which means you can route different islands to different model tiers (haiku for factual summaries, opus for creative writing) rather than running everything through one model at one price.

The tradeoff is real, though: you lose Guidance's ability to constrain generation *within* an island. Interleave doesn't care *how* the LLM generates inside a placeholder — it only cares about *which sections* the LLM touches at all.

### Skeleton-of-Thought & Speculative Decoding (the concurrency relatives)

[Skeleton-of-Thought](https://arxiv.org/abs/2307.15337) (Ning et al., ICLR 2024) has the LLM generate an outline first, then fill each point in parallel. Interleave inverts this: the skeleton is **fully deterministic** (no LLM needed for the outline step), so you save both the skeleton-generation tokens and the latency of that first sequential pass. Only the fill step uses LLMs, and those fills are dispatched concurrently.

Speculative decoding is a more distant cousin — small model drafts tokens, large model verifies. The "cheap model does the easy work, expensive model handles the hard parts" principle maps to interleave's [model routing](docs/spec/contracts/model-routing.md), just at section granularity instead of individual tokens.

### Where Interleave Sits

The short version: interleave bets on *document sections* as the right granularity for the deterministic/semantic split. Coarser than Guidance (tokens), coarser than Astro (components), but that coarseness is the point — the entire template layer is a bash script and some HTML comments. No parser, no grammar DSL, no framework dependency. The tradeoff is that sections smaller than ~10 lines aren't worth the placeholder overhead, which is why the spec recommends documents ≥50 lines with ≥50% deterministic content.
