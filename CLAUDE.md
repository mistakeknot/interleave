# interleave

> See `docs/spec/README.md` for the full pattern specification.

## Overview

Deterministic Skeleton with LLM Islands — spec + library plugin. 1 skill, 0 agents, 0 hooks, 0 MCP servers. Defines a token-efficient document generation pattern where deterministic sections are rendered by scripts and semantic sections are left as `<!-- LLM:NAME -->` placeholders for subagent filling.

## Quick Commands

```bash
# Test locally
claude --plugin-dir /root/projects/Interverse/plugins/interleave

# Validate structure
python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"  # Manifest check
ls skills/*/SKILL.md | wc -l          # Should be 1
bash -n scripts/template-roadmap-md.sh # Syntax check
find docs/spec -name '*.md' | wc -l   # Should be 6
```

## Reference Implementation

`scripts/template-roadmap-md.sh` — generates `docs/roadmap.md` from `roadmap.json` + beads data. Renders all deterministic sections directly; emits 3 LLM placeholder markers (NEXT_GROUPINGS, MODULE_HIGHLIGHTS, RESEARCH_AGENDA).

## Design Decisions (Do Not Re-Ask)

- Spec + library plugin — no MCP server, pattern-first approach
- `template-roadmap-md.sh` is the reference implementation (moved from interpath)
- Placeholder format: `<!-- LLM:UPPER_SNAKE_CASE ... END LLM:NAME -->` (HTML comments, invisible in markdown)
- Spec is versioned independently from plugin version (semver)
- Prior art: Microsoft Guidance, Skeleton-of-Thought (ICLR 2024), Islands Architecture (Astro.js)
