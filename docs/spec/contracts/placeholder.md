# Placeholder Format Specification

**Spec section:** Contracts
**Status:** Required for all conformance levels

---

## Format

```
<!-- LLM:SECTION_NAME
Task: [imperative instruction for the LLM]
Format: [expected output format description]

[embedded context data — JSON arrays, file lists, raw text, etc.]

END LLM:SECTION_NAME -->
```

## Rules

### Opening Tag

The opening tag is `<!-- LLM:` followed by an uppercase identifier:

```
<!-- LLM:NAME
```

- `NAME` matches `[A-Z][A-Z0-9_]*` — uppercase letters, digits, and underscores
- The `<!--` and `LLM:` are separated by a single space
- The opening tag occupies its own line
- Nothing follows `NAME` on the opening tag line (field lines start on subsequent lines)

### Closing Tag

The closing tag is `END LLM:` followed by the same `NAME`, then ` -->`:

```
END LLM:SECTION_NAME -->
```

- The `NAME` in the closing tag MUST match the opening tag exactly
- The closing tag occupies its own line

### Required Fields

**Task** (required): An imperative instruction for the LLM, on a line starting with `Task:`.

```
Task: Group these P2 items under 5-10 thematic headings.
```

**Format** (required): A description of the expected output structure, on a line starting with `Format:`.

```
Format: **Bold Heading** followed by bullet items.
```

### Context Block

Everything between the Format line and the closing tag is the **context block** — arbitrary data the LLM needs to complete the task. This can include:

- JSON arrays or objects
- File listings
- Raw text
- Multiple data sources separated by labels

The context block has no required structure — it is opaque to the orchestrator and passed directly to the subagent.

### Uniqueness

Placeholder names MUST be unique within a document. Duplicate names are a template error and SHOULD cause the orchestrator to log a warning and skip the duplicates.

### Visibility

The entire placeholder block is an HTML comment (`<!-- ... -->`). In standard markdown renderers, it is invisible to the reader. This means:

- The templated output is readable as-is (deterministic sections are visible, placeholders are hidden)
- Unfilled documents can be published without visual noise
- The orchestrator operates on the comment structure, not visible content

### Multi-line Fields

Task and Format fields are single-line. If additional instruction is needed, include it in the context block:

```
<!-- LLM:EXAMPLE
Task: Summarize these items.
Format: Bullet list with bold titles.

Additional instructions:
- Keep each bullet under 20 words
- Group by theme if patterns emerge

Data:
[{"id": "1", "title": "First item"}, {"id": "2", "title": "Second item"}]

END LLM:EXAMPLE -->
```
