# 🌿 grass-tracker

A CLI tool that shows your **GitHub daily commit streak** — fetched directly via the GitHub GraphQL API.

```
──────────────────────────────────────────────────
  🌱  GitHub Daily Commit Streak  —  @liks79
──────────────────────────────────────────────────

  📅 Started  : 2026-03-11
  📅 Last day : 2026-03-15

  🔥 Current streak : 5 day(s) and counting!

··················································
  A streak is sprouting!

  5 day(s) in a row — you're building a great habit! 💪
  Little by little, it all adds up. Keep going! 🔥

──────────────────────────────────────────────────
```

## Requirements

- [GitHub CLI (`gh`)](https://cli.github.com/) — authenticated with `gh auth login`
- `python3`

## Usage

```bash
./grass-tracker.sh <github_user_id> [weeks]
```

- `github_user_id` — GitHub username to look up (required)
- `weeks` — number of weeks to display in the heatmap (optional, default: `12`)

**Examples:**

```bash
./grass-tracker.sh liks79          # show last 12 weeks (default)
./grass-tracker.sh liks79 6        # show last 6 weeks
./grass-tracker.sh torvalds 24     # show last 24 weeks
```

## Installation

```bash
git clone https://github.com/liks79/grass-tracker.git
cd grass-tracker
chmod +x grass-tracker.sh
./grass-tracker.sh <your_github_id>           # default 12-week heatmap
./grass-tracker.sh <your_github_id> [weeks]   # custom week range
```

## Streak badges

| Streak | Badge | Message |
|--------|-------|---------|
| 0 days | 😴 | No commits yet / gap shown |
| 1–6 days | 🌱 | A streak is sprouting! |
| 7–29 days | 🌿 | Growing developer! |
| 30–99 days | 🌳 | One month and counting! |
| 100–364 days | 🔥 | True commit warrior! |
| 365+ days | 👑 | 365+ days — you're a legend! |

## License

[MIT](LICENSE)
