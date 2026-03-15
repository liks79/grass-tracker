#!/bin/bash
# GitHub Daily Commit Streak Tracker
# Usage: ./streak.sh <github_user_id>

# ── Usage check ───────────────────────────────────────────
if [[ -z "$1" ]]; then
    echo ""
    echo "  Usage: $0 <github_user_id>"
    echo "  Example: $0 torvalds"
    echo ""
    exit 1
fi

USER_ID="$1"

# ── Check if gh is installed ──────────────────────────────
if ! command -v gh &> /dev/null; then
    echo ""
    echo "  ❌  'gh' (GitHub CLI) is not installed."
    echo ""
    exit 1
fi

# ── Fetch contribution data via GitHub GraphQL API ────────
echo ""
echo "  📡  Fetching contribution data for @${USER_ID}..."

QUERY='query($login: String!) {
  user(login: $login) {
    contributionsCollection {
      contributionCalendar {
        weeks {
          contributionDays {
            date
            contributionCount
          }
        }
      }
    }
  }
}'

INPUT="$(gh api graphql -f query="$QUERY" -f login="$USER_ID" 2>&1)"

if [[ $? -ne 0 ]]; then
    echo ""
    echo "  ❌  Failed to fetch data."
    echo "  Error: $INPUT"
    echo ""
    exit 1
fi

# ── Analyze and display (Python) ──────────────────────────
python3 - "$INPUT" "$USER_ID" << 'EOF'
import sys
import json
from datetime import date, timedelta

BOLD    = "\033[1m"
RESET   = "\033[0m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
CYAN    = "\033[36m"
MAGENTA = "\033[35m"
RED     = "\033[31m"

data    = sys.argv[1] if len(sys.argv) > 1 else ""
user_id = sys.argv[2] if len(sys.argv) > 2 else ""

contributions = {}
try:
    parsed = json.loads(data)
    weeks = parsed["data"]["user"]["contributionsCollection"]["contributionCalendar"]["weeks"]
    for week in weeks:
        for day in week["contributionDays"]:
            d     = date.fromisoformat(day["date"])
            count = day["contributionCount"]
            contributions[d] = count
except (json.JSONDecodeError, KeyError, TypeError):
    pass

WIDTH = 50
def bar(char="─"): return char * WIDTH

if not contributions:
    print()
    print(f"{CYAN}{bar()}{RESET}")
    print(f"{BOLD}  ❓  GitHub Daily Commit Streak{RESET}")
    print(f"{CYAN}{bar()}{RESET}")
    print()
    print(f"  ⚠️  Could not parse contribution data.")
    print(f"  Please check the output of 'gh contribs -u {user_id}'.")
    print()
    print(f"{CYAN}{bar()}{RESET}")
    print()
    sys.exit(1)

today = date.today()

# ── Calculate current streak ──────────────────────────────
current    = today if contributions.get(today, 0) > 0 else today - timedelta(days=1)
streak     = 0
start_date = current

while contributions.get(current, 0) > 0:
    streak    += 1
    start_date = current
    current   -= timedelta(days=1)

end_date = start_date + timedelta(days=streak - 1) if streak > 0 else today

# ── Calculate gap (days without a commit) ─────────────────
gap_days = 0
if streak == 0:
    # Count days back from today until the last commit
    check    = today
    min_date = min(contributions.keys())
    while check >= min_date:
        if contributions.get(check, 0) > 0:
            break
        gap_days += 1
        check -= timedelta(days=1)

# ── Select badge and message based on streak ──────────────
if streak == 0:
    badge = "😴"
    title = "Not started yet" if gap_days == 0 else f"No commits for {gap_days} day(s)..."
    messages = [
        "  Today is the perfect day to start! Make your first commit. 🌱",
        "  A single step begins a great journey. Do it now! 🚀",
    ]
elif streak < 7:
    badge = "🌱"
    title = "A streak is sprouting!"
    messages = [
        f"  {streak} day(s) in a row — you're building a great habit! 💪",
        "  Little by little, it all adds up. Keep going! 🔥",
    ]
elif streak < 30:
    badge = "🌿"
    title = "Growing developer!"
    messages = [
        f"  {streak} consecutive days! You already have a top developer's habit. ✨",
        "  One month is just around the corner. Don't stop now! 🎯",
    ]
elif streak < 100:
    badge = "🌳"
    title = "One month and counting!"
    messages = [
        f"  An incredible {streak} days! What an impressive streak! 🏆",
        "  Your contribution graph is turning beautifully green. 🌈",
    ]
elif streak < 365:
    badge = "🔥"
    title = "True commit warrior!"
    messages = [
        f"  {streak} days straight! Crossing 100 days makes you legendary. 🌟",
        "  A full year is in sight. Too good to quit now! 💎",
    ]
else:
    badge = "👑"
    title = "365+ days — you're a legend!"
    messages = [
        f"  {streak} days ({streak // 365}+ year(s))! You are truly legendary. 👑",
        "  Your GitHub garden is completely green. Absolutely inspiring! 🌏",
    ]

# ── Print output ──────────────────────────────────────────
print()
print(f"{CYAN}{bar()}{RESET}")
print(f"{BOLD}  {badge}  GitHub Daily Commit Streak  —  @{user_id}{RESET}")
print(f"{CYAN}{bar()}{RESET}")
print()

if streak > 0:
    print(f"  📅 Started  : {YELLOW}{start_date}{RESET}")
    print(f"  📅 Last day : {YELLOW}{end_date}{RESET}")
    print()
    print(f"  {BOLD}{GREEN}🔥 Current streak : {streak} day(s) and counting!{RESET}")
else:
    if gap_days > 0:
        print(f"  {BOLD}{RED}💤 Commit gap : {gap_days} day(s) without a commit{RESET}")
    else:
        print(f"  {BOLD}No commit streak on record.{RESET}")

print()
print(f"{MAGENTA}{bar('·')}{RESET}")
print(f"  {BOLD}{title}{RESET}")
print()
for msg in messages:
    print(msg)
print()
print(f"{CYAN}{bar()}{RESET}")
print()
EOF
