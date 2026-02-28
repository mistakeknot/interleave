---
description: "Placeholder Filling Orchestrator"
---

# Interleave — Placeholder Filling Orchestrator

Fill `<!-- LLM:NAME -->` placeholders in a templated markdown document with subagent-generated content.

## Trigger

Use when a markdown file contains `<!-- LLM:` placeholder markers — typically after running a template script from the interleave pattern.

## Input

A path to a markdown file containing `<!-- LLM:NAME -->` placeholders.

If no path is provided, ask the user which file to process.

## Steps

### Step 1: Scan for Placeholders

Read the target file. Scan for all lines matching `<!-- LLM:` and extract the section names (the UPPER_SNAKE_CASE identifier after `LLM:`).

Report the count and names to the user:
```
Found N placeholders: NAME_1, NAME_2, ...
```

If no placeholders are found, report "No LLM placeholders found — document is fully rendered." and stop.

### Step 2: Extract Context Per Placeholder

For each placeholder, extract:
- **Task**: the line starting with `Task:` (required)
- **Format**: the line starting with `Format:` (required)
- **Context**: everything between the Format line and `END LLM:NAME -->`

If Task or Format is missing, warn the user and skip that placeholder.

### Step 3: Determine Model Tier

For each placeholder, select a model tier based on Task keywords:

| Task Keywords | Model |
|---|---|
| "group", "cluster", "categorize", "organize" | sonnet |
| "summarize", "describe", "list", "extract", "synthesize" | haiku |
| "write", "compose", "draft", "envision" | opus |
| Default | haiku |

Report the routing plan:
```
Routing:
  NAME_1 → sonnet (task: "Group these P2 items...")
  NAME_2 → haiku (task: "Write 2-3 sentence summaries...")
```

### Step 4: Dispatch Subagents

For each placeholder, dispatch a subagent using the Task tool:
- **subagent_type**: `general-purpose`
- **model**: the tier from Step 3
- **prompt**: Include the Task instruction, Format guidance, and full Context block

All placeholders are independent — dispatch them in parallel using multiple Task tool calls in a single message.

### Step 5: Replace Placeholders

For each completed subagent:
1. Take the subagent's output text
2. Find the placeholder block in the document (from `<!-- LLM:NAME` through `END LLM:NAME -->`)
3. Replace the entire block with the subagent's output

If a subagent failed or returned empty output, replace with:
```
<!-- WARNING: LLM:NAME unfilled — subagent returned no output -->
```

### Step 6: Write and Report

Write the final document back to the same path.

Report:
```
Filled N/M placeholders in [path]
  NAME_1: filled (sonnet, ~X tokens)
  NAME_2: filled (haiku, ~Y tokens)
  NAME_3: WARNING — unfilled
```

## Error Handling

- **No file at path**: Ask user for correct path
- **No placeholders found**: Report and stop (document is already complete)
- **Malformed placeholder** (missing closing tag): Warn and skip
- **Subagent failure**: Replace with warning marker, continue with other placeholders
- **All subagents fail**: Write document with warning markers, report errors
