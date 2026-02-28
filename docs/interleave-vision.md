# interleave — Vision and Philosophy

**Version:** 0.1.0
**Last updated:** 2026-02-28

## What interleave Is

interleave implements the Deterministic Skeleton with LLM Islands pattern — a token-efficient approach to document generation where a template script renders all computable sections directly and marks semantic sections with `<!-- LLM:NAME -->` placeholder comments. An orchestrating skill then dispatches independent subagents to fill each placeholder in parallel, replacing the comment block with generated content.

The defining constraint: LLMs only process what structured data cannot express. Tables, counts, dates, module lists, dependency chains — all derivable from JSON or database queries — are rendered by the template script at zero token cost. Only semantic judgment (groupings, summaries, research agendas) is delegated to LLMs. The result is documents that are 60-70% cheaper to generate, byte-exact in their deterministic sections, and fully reproducible on repeated runs against the same data.

## Why This Exists

Full-document LLM generation is wasteful and inconsistent. A roadmap's module table is a deterministic function of `roadmap.json`; re-deriving it through an LLM each time costs tokens, introduces hallucination risk for counts and versions, and prevents caching. interleave was created to enforce a hard separation: scripts own what is computable, LLMs own what requires judgment. This separation is both a cost optimization and a correctness guarantee.

## Design Principles

1. **Deterministic sections are mechanism; island content is policy.** The skeleton is fixed by the template script and the data. Island content varies by model, prompt, and context. The two must never be entangled.

2. **Structured data is the ground truth.** Template scripts read from authoritative sources (JSON files, beads, git history). LLMs fill only what those sources cannot express. If a section can be computed, it must be computed — not generated.

3. **Each island is independent.** Placeholder context is self-contained: Task, Format, and embedded context travel together. Subagents receive only their island's context, not the full document. This enables parallel dispatch and limits blast radius when a subagent fails.

4. **Token savings ratio gates usage.** The pattern adds overhead (template maintenance, orchestration). Only apply it when ≥50% of document content is deterministic and the document exceeds 50 lines. Below that threshold, direct LLM generation is cheaper.

5. **Templates are overridable defaults.** The placeholder spec is the contract; the template script is a default implementation. Any script that reads structured data and emits conforming placeholder blocks is a valid interleave template.

## Scope

**Does:**
- Define the placeholder format (`<!-- LLM:NAME ... END LLM:NAME -->`) and 5-step lifecycle
- Provide a skill that scans, routes, dispatches, and fills placeholders in any conforming document
- Provide `template-roadmap-md.sh` as the reference implementation for roadmap generation
- Route subagents by task keyword to model tier (opus/sonnet/haiku)

**Does not:**
- Handle fully creative documents (vision docs, brainstorms — no deterministic skeleton exists)
- Replace general-purpose document generation for one-shot or short documents
- Own the structured data sources themselves (those are owned by the modules that generate them)

## Direction

- Expand the template library beyond roadmaps: status reports, release notes, module READMEs
- Formalize the conformance spec so third-party template scripts can be validated automatically
- Track token savings per generation as a measurable output, feeding back into routing calibration
