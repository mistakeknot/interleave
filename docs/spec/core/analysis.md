# Section Classification

**Spec section:** Core
**Status:** Required for Core + Analysis conformance

---

## Overview

Before writing a template script, classify each section of the target document as **deterministic**, **semantic**, or **hybrid**. This classification determines what the script renders directly vs. what becomes an LLM placeholder.

## Taxonomy

### Deterministic

A section is deterministic if it is a **pure function of structured data** — given the same input, the output is byte-identical every time.

Indicators:
- Tables with columns mapping to JSON fields
- Lists derived from database queries
- Counts, sums, dates, version numbers
- Static text that never changes (headers, legends, instructions)
- Dependency graphs derived from machine-readable relationships

### Semantic

A section is semantic if it requires **judgment, synthesis, or creative framing** that cannot be reduced to data transformation.

Indicators:
- Thematic grouping of items (choosing categories)
- Summarization of multiple sources into prose
- Prioritization or recommendation
- Creative writing, vision statements
- Analysis that weighs qualitative factors

### Hybrid

A section is hybrid when it contains **deterministic data with conditional LLM arrangement**. Some instances can be rendered directly; others need LLM input.

Indicators:
- Module highlights where some modules have existing summaries (render directly) and others need new summaries (LLM placeholder)
- Lists where most items are formatted from data but some need classification
- Sections with a deterministic frame but variable-length semantic content

For hybrid sections, the template script renders what it can and emits a placeholder only for the missing parts.

## Decision Flowchart

For each section in the target document:

```
1. Can this section be rendered entirely by a script
   given structured data inputs?
   ├── YES → Deterministic. Render in template.
   └── NO →
       2. Does it need grouping, summarization,
          classification, or creative framing?
          ├── YES →
          │   3. Can some instances be rendered from data
          │      while others need LLM input?
          │      ├── YES → Hybrid. Render what you can,
          │      │         placeholder for the rest.
          │      └── NO  → Semantic. Full placeholder.
          └── NO →
              4. Is the content static text that never
                 changes between generations?
                 ├── YES → Deterministic. Hardcode in template.
                 └── NO  → Re-examine. You may be missing
                           a data source.
```

## Worked Example: Interverse Roadmap

| Section | Classification | Rationale |
|---------|---------------|-----------|
| Header (counts, date) | Deterministic | Pure function of roadmap.json and today's date |
| Ecosystem Snapshot table | Deterministic | Column-for-column mapping from modules array |
| Now (P0-P1) items | Deterministic | Formatted list from beads query |
| Next (P2) groupings | Semantic | Requires thematic clustering judgment |
| Later (P3+) items | Deterministic | Formatted list from beads query |
| Recently completed | Deterministic | Comma-joined list from beads closed query |
| Module Highlights | Hybrid | Existing summaries render directly; missing ones need LLM |
| Research Agenda | Semantic | Synthesis from brainstorm/plan titles + existing items |
| Cross-Module Dependencies | Deterministic | Derived from beads dependency data |
| Modules Without Roadmaps | Deterministic | List from roadmap.json |
| Keeping Current | Deterministic | Static instructions text |

**Result:** 7 deterministic, 2 semantic, 1 hybrid → ~70% deterministic → pattern is justified.

## Guidelines for New Documents

When classifying sections for a new document type:

1. **Start with the data sources.** What structured data is available? JSON files, database tables, git log, file listings, API responses?
2. **Map each section to its data source.** If a section maps cleanly to a query, it's deterministic.
3. **Identify the judgment calls.** Sections that need "which items go together" or "summarize this in 2 sentences" are semantic.
4. **Look for hybrid patterns.** "Render existing, generate missing" is a common hybrid that saves tokens on the common case.
5. **Aim for ≥60% deterministic.** If the document is mostly semantic, the interleave pattern adds overhead without proportionate savings. Consider whether you can restructure the document to include more data-driven sections.
