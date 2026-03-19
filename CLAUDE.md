# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`grass-tracker` is a CLI tool that displays your GitHub daily commit streak by fetching data from the GitHub GraphQL API.

## Running

```bash
chmod +x grass-tracker.sh
./grass-tracker.sh <github_username>
```

**Requirements:** `gh` (GitHub CLI, must be authenticated via `gh auth login`) and `python3` must be in PATH.

## Architecture

The entire tool lives in a single file: `grass-tracker.sh`.

**Two-layer design:**
1. **Bash layer** — validates input, checks dependencies, calls the GitHub GraphQL API via `gh api graphql`, and passes the JSON response to Python via stdin.
2. **Python layer (embedded heredoc)** — parses the contribution calendar JSON, calculates the current streak by walking backward from today, picks a badge tier, and renders colorized output.

**Data flow:** `./grass-tracker.sh username` → `gh api graphql` (authenticated) → embedded Python script → formatted terminal output.

**Streak badge tiers** (defined in the Python section): 😴 0 days, 🌱 1–6, 🌿 7–29, 🌳 30–99, 🔥 100–364, 👑 365+.
