# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`grass-tracker` is a CLI tool that displays your GitHub daily commit streak by fetching data from the GitHub GraphQL API.

## Running

```bash
chmod +x grass-tracker.sh
./grass-tracker.sh <github_username> [weeks]   # weeks defaults to 12
```

**Requirements:** `gh` (GitHub CLI, must be authenticated via `gh auth login`) and `python3` must be in PATH.

## Architecture

The entire tool lives in a single file: `grass-tracker.sh`.

**Two-layer design:**
1. **Bash layer** — validates input, checks dependencies, runs `gh api graphql` with a spinner in the background, and captures the JSON response into `$INPUT`.
2. **Python layer (embedded heredoc)** — invoked as `python3 - "$INPUT" "$USER_ID" "$WEEKS" << 'EOF'`. The `-` tells Python to read the script from stdin (the heredoc); the JSON, username, and week count arrive as `sys.argv[1–3]`, not stdin.

**Data flow:** `./grass-tracker.sh username [weeks]` → `gh api graphql` (authenticated) → `$INPUT` → Python `sys.argv[1]` → formatted terminal output.

**Streak calculation:** walks backward from today (or yesterday if no commit today), counting consecutive days with `contributionCount > 0`.

**Streak badge tiers:** 😴 0 days, 🌱 1–6, 🌿 7–29, 🌳 30–99, 🔥 100–364, 👑 365+.

**Heatmap color levels** (5-shade green scale): 0 commits = dark grey, 1–2 = dark green, 3–5 = medium green, 6–9 = bright green, 10+ = vivid green.

**Terminal hygiene:** both the Bash and Python layers hide the cursor during animations (`\033[?25l`) and always restore it on exit via `trap cleanup EXIT INT TERM` (Bash) and `atexit` + `SIGINT` handler (Python).
