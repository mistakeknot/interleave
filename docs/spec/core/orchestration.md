# Placeholder Filling Lifecycle

**Spec section:** Core
**Status:** Required for all conformance levels

---

## Overview

After the template script produces a document with `<!-- LLM:NAME -->` placeholders, the orchestrator fills them. This document specifies the scanning, extraction, dispatch, replacement, and error handling phases.

## Phase 1: Scan

Read the templated document and identify all placeholder opening tags matching the pattern:

```
<!-- LLM:NAME
```

where `NAME` is `[A-Z][A-Z0-9_]*` (uppercase letters, digits, and underscores).

Collect the list of placeholder names. Verify uniqueness — duplicate names are a template error.

## Phase 2: Extract Context

For each placeholder, extract the content between the opening tag line and the `END LLM:NAME -->` closing tag line.

Parse the structured fields:
- **Task** (required): The line starting with `Task:` — imperative instruction for the LLM
- **Format** (required): The line starting with `Format:` — expected output structure description
- **Context block**: All remaining content between Format and the closing tag — embedded data (JSON arrays, file lists, raw text)

If Task or Format is missing, log a warning and skip the placeholder.

## Phase 3: Select Model Tier

Determine the appropriate model tier for each island based on the Task description and island type. See [model-routing.md](../contracts/model-routing.md) for guidelines.

Implementations at the Core conformance level MAY use a single model tier for all islands. Core + Routing implementations MUST implement tier selection.

## Phase 4: Dispatch

For each placeholder, dispatch a subagent with:
- The extracted Task as the primary instruction
- The Format description as output guidance
- The Context block as input data

**Key constraint:** The subagent receives only its placeholder's context — not the full document. This is what makes islands independent and parallelizable.

Independent islands (no data dependencies between them) SHOULD be dispatched concurrently. Islands with dependencies (one island's output feeds another) MUST be dispatched sequentially.

In practice, most documents have fully independent islands. The roadmap reference implementation dispatches all 3 islands concurrently.

## Phase 5: Replace

For each filled placeholder, replace the entire block from `<!-- LLM:NAME` through `END LLM:NAME -->` with the subagent's output.

The replacement text is **raw markdown** — not wrapped in HTML comments. The placeholder was invisible (HTML comment); the replacement is visible content.

After replacement, verify:
- No `<!-- LLM:` tags remain (all placeholders filled)
- No `END LLM:` tags remain (no orphaned closing tags)
- The document is valid markdown

## Error Handling

### Unfilled Placeholder

If a subagent fails or returns empty output, do not silently drop the placeholder. Replace it with a warning marker:

```markdown
<!-- WARNING: LLM:SECTION_NAME unfilled — subagent returned no output -->
```

This preserves visibility — the document reader sees the warning, and a subsequent run can attempt to fill it.

### Template Script Failure

If the template script fails (missing dependencies like `jq`, broken data source, runtime error), the orchestrator SHOULD fall back to full LLM generation of the entire document.

The template script MUST emit diagnostic errors to stderr so the orchestrator can log the failure reason.

### Partial Fills

If some placeholders are filled and others fail, the orchestrator SHOULD write the document with the successful fills and warning markers for the failures. Do not discard successful fills because of partial failure.

### Malformed Placeholders

If a placeholder is missing the closing `END LLM:NAME -->` tag:
- Log a warning identifying the unclosed placeholder
- Skip the placeholder (do not attempt to fill it)
- Leave the malformed comment in the document

## Idempotency

Running the orchestrator twice on a document that has already been filled produces the same result — the fill step finds no `<!-- LLM:` tags and returns immediately.

Running the template script again overwrites the filled document with fresh deterministic content and new placeholders, ready for a new fill cycle. This is the intended regeneration workflow: template → fill → (time passes) → template → fill.
