# Interleave (compact)

Fill `<!-- LLM:NAME -->` placeholders in templated markdown documents with subagent-generated content.

## When to Invoke

Use when a markdown file contains `<!-- LLM:` placeholder markers, typically after running a template script from the interleave pattern.

## Core Workflow

1. **Scan** -- Read target file, extract all `<!-- LLM:UPPER_SNAKE_CASE -->` section names. Report count and names. Stop if none found.

2. **Extract context** -- For each placeholder, extract Task (required), Format (required), and Context (between Format line and `END LLM:NAME -->`). Skip if Task/Format missing.

3. **Route models** -- Select tier by Task keywords:
   - "group/cluster/categorize/organize" -> sonnet
   - "summarize/describe/list/extract/synthesize" -> haiku
   - "write/compose/draft/envision" -> opus
   - Default -> haiku

4. **Dispatch** -- Send all placeholders to subagents in parallel (`general-purpose` type, routed model tier). Include Task, Format, and Context in each prompt.

5. **Replace** -- Swap each `<!-- LLM:NAME ... END LLM:NAME -->` block with subagent output. Failed/empty results become `<!-- WARNING: LLM:NAME unfilled -->`.

6. **Report** -- Write file back, report N/M filled with model and token counts per placeholder.

## Error Handling

- No file: ask user for path
- No placeholders: report "fully rendered", stop
- Malformed placeholder (missing closing tag): warn, skip
- Subagent failure: insert warning marker, continue others

---
*For full format details and examples, read SKILL.md.*
