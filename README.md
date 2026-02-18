# interleave

Deterministic Skeleton with LLM Islands — token-efficient document generation.

## What This Does

Most AI-generated documents waste tokens on parts that are entirely predictable. If you're generating a roadmap, the table of completed items, the version header, and the status counts are all deterministic — they come from data, not creativity. The creative parts (grouping analysis, highlight commentary, research agenda) are the only sections that actually need an LLM.

interleave formalizes this split. A template script renders all the deterministic sections and emits `<!-- LLM:NAME -->` placeholder markers for the semantic sections. A subagent then fills only the placeholders. The result is the same document at a fraction of the token cost.

This is a spec + library plugin. It defines the pattern, provides a reference implementation, and includes a skill for applying it. No MCP server, no hooks — just the pattern itself.

## Installation

```bash
/plugin install interleave
```

## Reference Implementation

`scripts/template-roadmap-md.sh` generates a full `docs/roadmap.md` from `roadmap.json` + beads data. It renders all deterministic sections directly and emits 3 LLM placeholder markers (NEXT_GROUPINGS, MODULE_HIGHLIGHTS, RESEARCH_AGENDA).

## Placeholder Format

```html
<!-- LLM:SECTION_NAME context="..." -->
(content to be filled by LLM)
<!-- END LLM:SECTION_NAME -->
```

HTML comments, invisible in rendered markdown. The `context` attribute gives the LLM enough information to fill the section without reading the whole document.

## Prior Art

- **Skeleton-of-Thought** (ICLR 2024) — generate outline first, fill in parallel
- **Microsoft Guidance** — interleaved deterministic/LLM generation
- **Islands Architecture** (Astro.js) — static shell with interactive islands
