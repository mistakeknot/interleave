#!/usr/bin/env bash
# shellcheck disable=SC2155
# template-roadmap-md.sh — Generate docs/interverse-roadmap.md from roadmap.json + beads data
# Deterministic sections are rendered directly; 3 LLM placeholder markers are emitted
# for sections requiring semantic judgment (NEXT_GROUPINGS, MODULE_HIGHLIGHTS, RESEARCH_AGENDA).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ROADMAP_JSON="${1:-$ROOT_DIR/docs/roadmap.json}"
OUTPUT="$ROOT_DIR/docs/interverse-roadmap.md"

# ── Validation ───────────────────────────────────────────────────────────────
command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

if [ ! -f "$ROADMAP_JSON" ]; then
    echo "error: $ROADMAP_JSON not found. Run sync-roadmap-json.sh first." >&2
    exit 1
fi

jq -e '.kind == "interverse-monorepo-roadmap"' "$ROADMAP_JSON" >/dev/null 2>&1 || {
    echo "error: $ROADMAP_JSON is not a valid monorepo roadmap (missing/wrong .kind)" >&2
    exit 1
}

# ── Beads availability ───────────────────────────────────────────────────────
BD_AVAILABLE=1
if ! command -v bd >/dev/null 2>&1; then
    BD_AVAILABLE=0
    echo "warning: bd not available; beads sections will use roadmap.json counts only" >&2
fi

# ── Helper: extract [module] tag from bead title ─────────────────────────────
extract_module_tag() {
    echo "$1" | sed -n 's/^\[([^]]*)\].*/\1/p' 2>/dev/null || \
    echo "$1" | sed -n 's/^\[\([^]]*\)\].*/\1/p'
}

strip_module_tag() {
    echo "$1" | sed 's/^\[[^]]*\][[:space:]]*//'
}

# ── Collect beads data ───────────────────────────────────────────────────────
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [ "$BD_AVAILABLE" -eq 1 ]; then
    bd --json stats 2>/dev/null >"$TMP_DIR/stats.json" || echo '{}' >"$TMP_DIR/stats.json"
    bd --json list --status=open --priority=0 -n 0 2>/dev/null >"$TMP_DIR/p0.json" || echo '[]' >"$TMP_DIR/p0.json"
    bd --json list --status=open --priority=1 -n 0 2>/dev/null >"$TMP_DIR/p1.json" || echo '[]' >"$TMP_DIR/p1.json"
    bd --json list --status=open --priority=2 -n 0 2>/dev/null >"$TMP_DIR/p2.json" || echo '[]' >"$TMP_DIR/p2.json"
    bd --json list --status=open --priority=3 -n 0 2>/dev/null >"$TMP_DIR/p3.json" || echo '[]' >"$TMP_DIR/p3.json"
    bd --json list --status=open --priority=4 -n 0 2>/dev/null >"$TMP_DIR/p4.json" || echo '[]' >"$TMP_DIR/p4.json"
    bd --json list --status=closed -n 20 --sort updated 2>/dev/null >"$TMP_DIR/closed.json" || echo '[]' >"$TMP_DIR/closed.json"
    bd --json blocked 2>/dev/null >"$TMP_DIR/blocked.json" || echo '[]' >"$TMP_DIR/blocked.json"
else
    for f in stats p0 p1 p2 p3 p4 closed blocked; do
        echo '[]' >"$TMP_DIR/$f.json"
    done
    echo '{}' >"$TMP_DIR/stats.json"
fi

# Merge P0+P1 into "now" items, excluding blocked
jq -s 'add // []' "$TMP_DIR/p0.json" "$TMP_DIR/p1.json" >"$TMP_DIR/now.json"

# Merge P3+P4 into "later" items (limit 20)
jq -s '(add // [])[:20]' "$TMP_DIR/p3.json" "$TMP_DIR/p4.json" >"$TMP_DIR/later.json"

# ── Counts ───────────────────────────────────────────────────────────────────
MODULE_COUNT="$(jq -r '.module_count' "$ROADMAP_JSON")"
if [ "$BD_AVAILABLE" -eq 1 ]; then
    OPEN_BEADS="$(jq -r '.summary.open_issues // 0' "$TMP_DIR/stats.json")"
    BLOCKED_COUNT="$(jq -r '.summary.blocked_issues // 0' "$TMP_DIR/stats.json")"
else
    OPEN_BEADS="$(jq -r '.open_beads' "$ROADMAP_JSON")"
    BLOCKED_COUNT="$(jq -r '.blocked' "$ROADMAP_JSON")"
fi
TODAY="$(date +%Y-%m-%d)"

# ── Format a single bead item as markdown bullet ─────────────────────────────
format_bead_item() {
    local json="$1"
    local id title module display_title dep_note

    id="$(jq -r '.id' <<<"$json")"
    title="$(jq -r '.title' <<<"$json")"

    # Extract [module] tag
    module="$(echo "$title" | sed -n 's/^\[\([^]]*\)\].*/\1/p')"
    if [ -n "$module" ]; then
        display_title="$(echo "$title" | sed 's/^\[[^]]*\][[:space:]]*//')"
    else
        module="interverse"
        display_title="$title"
    fi

    # Build dependency annotation
    dep_note=""
    local blocked_by
    blocked_by="$(jq -r '
        if .dependencies then
            [.dependencies[] | select(.type == "blocks") | .depends_on_id] | join(", ")
        elif .blocked_by then
            if type == "array" then .blocked_by | join(", ")
            else ""
            end
        else ""
        end
    ' <<<"$json" 2>/dev/null || echo "")"

    if [ -n "$blocked_by" ] && [ "$blocked_by" != "null" ] && [ "$blocked_by" != "" ]; then
        dep_note=" (blocked by $blocked_by)"
    fi

    # Check if this item blocks others
    local blocks
    blocks="$(jq -r '
        if .dependencies then
            [.dependencies[] | select(.type != "blocks") | .depends_on_id] | join(", ")
        else ""
        end
    ' <<<"$json" 2>/dev/null || echo "")"

    if [ -n "$blocks" ] && [ "$blocks" != "null" ] && [ "$blocks" != "" ]; then
        if [ -n "$dep_note" ]; then
            dep_note="$dep_note, blocks $blocks"
        else
            dep_note=" (blocks $blocks)"
        fi
    fi

    echo "- [$module] **$id** $display_title$dep_note"
}

# ── Begin output ─────────────────────────────────────────────────────────────
{

# ── Header ───────────────────────────────────────────────────────────────────
cat <<HEADER
# Interverse Roadmap

**Modules:** $MODULE_COUNT | **Open beads (root tracker):** $OPEN_BEADS | **Blocked (root tracker):** $BLOCKED_COUNT | **Last updated:** $TODAY
**Structure:** [\`CLAUDE.md\`](../CLAUDE.md)
**Machine output:** [\`docs/roadmap.json\`](roadmap.json)

---

HEADER

# ── Ecosystem Snapshot ───────────────────────────────────────────────────────
cat <<'TABLE_HEADER'
## Ecosystem Snapshot

| Module | Location | Version | Status | Roadmap | Open Beads (context) |
|--------|----------|---------|--------|---------|----------------------|
TABLE_HEADER

jq -r '.modules | sort_by(.module) | .[] |
    "| " + .module + " | " + .location + " | " + .version + " | " + .status +
    " | " + (if .has_roadmap then "yes" else "no" end) +
    " | " + (if .open_beads > 0 then (.open_beads | tostring) else "n/a" end) +
    " |"
' "$ROADMAP_JSON"

cat <<'LEGEND'

**Legend:** active = recent commits or active tracker items; early = manifest exists but roadmap maturity is limited. `n/a` means there is no module-local `.beads` database.

---

LEGEND

# ── Roadmap ──────────────────────────────────────────────────────────────────
echo "## Roadmap"
echo ""

# ── Now (P0-P1) ─────────────────────────────────────────────────────────────
echo "### Now (P0-P1)"
echo ""

NOW_COUNT="$(jq 'length' "$TMP_DIR/now.json")"
if [ "$NOW_COUNT" -eq 0 ]; then
    echo "No P0-P1 items."
else
    while IFS= read -r item; do
        format_bead_item "$item"
    done < <(jq -c '.[]' "$TMP_DIR/now.json")
fi
echo ""

# ── Recently Completed ───────────────────────────────────────────────────────
CLOSED_LINE="$(jq -r '[.[:20][] | .id + " (" + (.title | sub("^\\[[^]]+\\]\\s*"; "")) + ")"] | join(", ")' "$TMP_DIR/closed.json" 2>/dev/null || echo "")"
if [ -n "$CLOSED_LINE" ] && [ "$CLOSED_LINE" != "" ]; then
    echo "**Recently completed:** $CLOSED_LINE"
    echo ""
fi

# ── Next (P2) — LLM PLACEHOLDER ─────────────────────────────────────────────
echo "### Next (P2)"
echo ""

P2_COUNT="$(jq 'length' "$TMP_DIR/p2.json")"
if [ "$P2_COUNT" -eq 0 ]; then
    echo "No P2 items."
else
    echo "<!-- LLM:NEXT_GROUPINGS"
    echo "Task: Group these P2 items under 5-10 thematic headings."
    echo "Format: **Bold Heading** followed by bullet items."
    echo "Heuristic: items sharing a [module] tag or dependency chain likely belong together."
    echo ""
    echo "Raw P2 items JSON:"
    jq -c '[.[] | {id, title, priority, dependencies}]' "$TMP_DIR/p2.json"
    echo ""
    echo "END LLM:NEXT_GROUPINGS -->"
fi
echo ""

# ── Later (P3+) ─────────────────────────────────────────────────────────────
echo "### Later (P3)"
echo ""

LATER_COUNT="$(jq 'length' "$TMP_DIR/later.json")"
if [ "$LATER_COUNT" -eq 0 ]; then
    echo "No P3+ items."
else
    while IFS= read -r item; do
        format_bead_item "$item"
    done < <(jq -c '.[]' "$TMP_DIR/later.json")
fi

cat <<'SEP'

---

SEP

# ── Module Highlights — HYBRID ───────────────────────────────────────────────
echo "## Module Highlights"
echo ""

NEEDS_LLM_HIGHLIGHTS=""
while IFS= read -r entry; do
    mod="$(jq -r '.module' <<<"$entry")"
    loc="$(jq -r '.location' <<<"$entry")"
    summary="$(jq -r '.summary' <<<"$entry")"
    summary_len="${#summary}"

    if [ "$summary_len" -gt 40 ]; then
        echo "### $mod ($loc)"
        echo "$summary"
        echo ""
    else
        NEEDS_LLM_HIGHLIGHTS="${NEEDS_LLM_HIGHLIGHTS}${mod}|${loc}\n"
    fi
done < <(jq -c '.module_highlights | sort_by(.module) | .[]' "$ROADMAP_JSON")

if [ -n "$NEEDS_LLM_HIGHLIGHTS" ]; then
    echo "<!-- LLM:MODULE_HIGHLIGHTS"
    echo "Task: Write 2-3 sentence summaries for these modules."
    echo "Format: ### module (location)"
    echo "vX.Y.Z. Summary text."
    echo ""
    echo "Modules needing highlights:"
    echo -e "$NEEDS_LLM_HIGHLIGHTS"
    echo "END LLM:MODULE_HIGHLIGHTS -->"
    echo ""
fi

cat <<'SEP'
---

SEP

# ── Research Agenda — LLM PLACEHOLDER ────────────────────────────────────────
echo "## Research Agenda"
echo ""

# Gather inputs for the LLM
BRAINSTORM_TITLES=""
if [ -d "$ROOT_DIR/docs/brainstorms" ]; then
    BRAINSTORM_TITLES="$(ls -1 "$ROOT_DIR/docs/brainstorms/"*.md 2>/dev/null | xargs -I{} basename {} .md | sort || true)"
fi

PLAN_TITLES=""
if [ -d "$ROOT_DIR/docs/plans" ]; then
    PLAN_TITLES="$(ls -1 "$ROOT_DIR/docs/plans/"*.md 2>/dev/null | xargs -I{} basename {} .md | sort || true)"
fi

EXISTING_RESEARCH="$(jq -r '.research_agenda[]? | .item // empty' "$ROADMAP_JSON" 2>/dev/null || true)"

echo "<!-- LLM:RESEARCH_AGENDA"
echo "Task: Synthesize into 10-15 thematic research bullets."
echo "Format: - **Topic** — 1-line summary"
echo ""
if [ -n "$BRAINSTORM_TITLES" ]; then
    echo "Brainstorm files:"
    echo "$BRAINSTORM_TITLES"
    echo ""
fi
if [ -n "$PLAN_TITLES" ]; then
    echo "Plan files:"
    echo "$PLAN_TITLES"
    echo ""
fi
if [ -n "$EXISTING_RESEARCH" ]; then
    echo "Existing research agenda items:"
    echo "$EXISTING_RESEARCH"
    echo ""
fi
echo "END LLM:RESEARCH_AGENDA -->"
echo ""

cat <<'SEP'
---

SEP

# ── Cross-Module Dependencies ────────────────────────────────────────────────
echo "## Cross-Module Dependencies"
echo ""
echo "Major dependency chains spanning multiple modules:"
echo ""

if [ "$BD_AVAILABLE" -eq 1 ]; then
    # Build cross-module dep chains from blocked beads
    BLOCKED_COUNT_ITEMS="$(jq 'length' "$TMP_DIR/blocked.json")"
    CROSS_DEPS_FOUND=0

    if [ "$BLOCKED_COUNT_ITEMS" -gt 0 ]; then
        # For each blocked item, check if it crosses module boundaries
        declare -A CHAIN_ENTRIES=()
        while IFS= read -r item; do
            item_id="$(jq -r '.id' <<<"$item")"
            item_title="$(jq -r '.title' <<<"$item")"
            item_mod="$(echo "$item_title" | sed -n 's/^\[\([^]]*\)\].*/\1/p')"
            [ -z "$item_mod" ] && item_mod="interverse"

            while IFS= read -r dep_id; do
                [ -z "$dep_id" ] && continue
                # Look up the dep's module from all open beads
                dep_title="$(jq -r --arg did "$dep_id" '.[] | select(.id == $did) | .title' "$TMP_DIR/now.json" "$TMP_DIR/p2.json" "$TMP_DIR/later.json" 2>/dev/null | head -1)"
                [ -z "$dep_title" ] && continue
                dep_mod="$(echo "$dep_title" | sed -n 's/^\[\([^]]*\)\].*/\1/p')"
                [ -z "$dep_mod" ] && dep_mod="interverse"

                if [ "$item_mod" != "$dep_mod" ]; then
                    entry="- **$item_id** ($item_mod) blocked by **$dep_id** ($dep_mod)"
                    key="${item_id}|${dep_id}"
                    if [ -z "${CHAIN_ENTRIES[$key]:-}" ]; then
                        CHAIN_ENTRIES["$key"]=1
                        echo "$entry"
                        CROSS_DEPS_FOUND=1
                    fi
                fi
            done < <(jq -r '.blocked_by[]? // empty' <<<"$item")
        done < <(jq -c '.[]' "$TMP_DIR/blocked.json")
    fi

    if [ "$CROSS_DEPS_FOUND" -eq 0 ]; then
        # Fall back to roadmap.json cross_module_dependencies
        CROSS_JSON_COUNT="$(jq '.cross_module_dependencies | length' "$ROADMAP_JSON")"
        if [ "$CROSS_JSON_COUNT" -gt 0 ]; then
            jq -r '.cross_module_dependencies[] | .raw // ("- " + (.item_id // "?") + " blocked by " + (.depends_on_id // "?"))' "$ROADMAP_JSON"
        else
            echo "No cross-module blockers identified."
        fi
    fi
else
    # No bd — use roadmap.json cross deps
    CROSS_JSON_COUNT="$(jq '.cross_module_dependencies | length' "$ROADMAP_JSON")"
    if [ "$CROSS_JSON_COUNT" -gt 0 ]; then
        jq -r '.cross_module_dependencies[] | .raw // ("- " + (.item_id // "?") + " blocked by " + (.depends_on_id // "?"))' "$ROADMAP_JSON"
    else
        echo "No cross-module blockers identified."
    fi
fi

cat <<'SEP'

---

SEP

# ── Modules Without Roadmaps ────────────────────────────────────────────────
echo "## Modules Without Roadmaps"
echo ""

NO_ROADMAP_COUNT="$(jq '.modules_without_roadmaps | length' "$ROADMAP_JSON")"
if [ "$NO_ROADMAP_COUNT" -eq 0 ]; then
    echo "All modules have roadmaps."
else
    jq -r '.modules_without_roadmaps[] | "- `" + .location + "`"' "$ROADMAP_JSON"
fi

cat <<'SEP'

---

SEP

# ── Keeping Current ──────────────────────────────────────────────────────────
cat <<'KEEPING'
## Keeping Current

```
# Regenerate this roadmap JSON from current repo state
scripts/sync-roadmap-json.sh docs/roadmap.json

# Regenerate via interpath command flow (Claude Code)
/interpath:roadmap    (from Interverse root)

# Propagate items to subrepo roadmaps
/interpath:propagate  (from Interverse root)
```
KEEPING

} > "$OUTPUT"

echo "Wrote $OUTPUT ($(wc -l < "$OUTPUT") lines)"

# Report placeholder count
PLACEHOLDER_COUNT="$(grep -c '<!-- LLM:' "$OUTPUT" || true)"
echo "LLM placeholders: $PLACEHOLDER_COUNT"
