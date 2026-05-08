#!/bin/bash
# GitHub Daily Commit Streak Tracker
# Usage: ./grass-tracker.sh <github_user_id> [weeks]

# ── Argument parsing ──────────────────────────────────────
QUICK=0
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --quick|-q) QUICK=1 ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done

USER_ID="${POSITIONAL[0]:-}"
WEEKS="${POSITIONAL[1]:-12}"

if [[ -z "$USER_ID" ]]; then
    echo ""
    echo "  Usage: $0 <github_user_id> [weeks] [--quick|-q]"
    echo "  Example: $0 torvalds"
    echo "  Example: $0 torvalds 6"
    echo "  Example: $0 torvalds --quick"
    echo "  Example: $0 torvalds 6 --quick"
    echo ""
    exit 1
fi

# ── Validate weeks argument ───────────────────────────────
if ! [[ "$WEEKS" =~ ^[1-9][0-9]*$ ]]; then
    echo ""
    echo "  ❌  [weeks] must be a positive integer (got: $WEEKS)"
    echo ""
    exit 1
fi

# ── Check if gh is installed ──────────────────────────────
if ! command -v gh &> /dev/null; then
    echo ""
    echo "  ❌  'gh' (GitHub CLI) is not installed."
    echo ""
    exit 1
fi

# ── Temp files & cleanup ──────────────────────────────────
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
cleanup() {
    rm -f "$TMPOUT" "$TMPERR"
    printf "\033[?25h"   # always restore cursor on exit
}
trap cleanup EXIT INT TERM

# ── Fetch with spinner ────────────────────────────────────
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

echo ""

if [[ $QUICK -eq 1 ]]; then
    gh api graphql -f query="$QUERY" -f login="$USER_ID" > "$TMPOUT" 2> "$TMPERR"
    FETCH_STATUS=$?
    if [[ $FETCH_STATUS -ne 0 ]]; then
        printf "  \033[31m✗\033[0m  Failed to fetch data for @%s.\n\n" "$USER_ID"
        cat "$TMPERR"
        echo ""
        exit 1
    fi
else
    printf "\033[?25l"   # hide cursor while spinner is running

    gh api graphql -f query="$QUERY" -f login="$USER_ID" > "$TMPOUT" 2> "$TMPERR" &
    FETCH_PID=$!

    FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    i=0
    while kill -0 "$FETCH_PID" 2>/dev/null; do
        frame="${FRAMES[$((i % 10))]}"
        printf "\r  \033[36m%s\033[0m  Fetching data for \033[1m@%s\033[0m..." "$frame" "$USER_ID"
        sleep 0.08
        i=$((i + 1))
    done

    wait "$FETCH_PID"
    FETCH_STATUS=$?
    printf "\033[?25h"   # show cursor again

    if [[ $FETCH_STATUS -ne 0 ]]; then
        printf "\r  \033[31m✗\033[0m  Failed to fetch data for @%s.          \n\n" "$USER_ID"
        cat "$TMPERR"
        echo ""
        exit 1
    fi

    printf "\r  \033[32m✓\033[0m  Data fetched for \033[1m@%s\033[0m.              \n" "$USER_ID"
fi

INPUT="$(cat "$TMPOUT")"

# ── Analyze and display (Python) ──────────────────────────
python3 - "$INPUT" "$USER_ID" "$WEEKS" "$QUICK" << 'EOF'
import sys
import json
import time
import signal
import atexit
from datetime import date, timedelta

# ── ANSI codes ─────────────────────────────────────────────
BOLD     = "\033[1m"
DIM      = "\033[2m"
RESET    = "\033[0m"
GREEN    = "\033[32m"
YELLOW   = "\033[33m"
CYAN     = "\033[36m"
MAGENTA  = "\033[35m"
RED      = "\033[31m"
HIDE_CUR = "\033[?25l"
SHOW_CUR = "\033[?25h"

WIDTH = 50

# ── Always restore cursor on exit or Ctrl-C ───────────────
def _restore(*_):
    sys.stdout.write(SHOW_CUR)
    sys.stdout.flush()

atexit.register(_restore)
signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))

# ── Helpers ────────────────────────────────────────────────
def flush(text):
    sys.stdout.write(text)
    sys.stdout.flush()

def print_line(text="", delay=0.035):
    print(text)
    sys.stdout.flush()
    if not quick:
        time.sleep(delay)

def animate_divider(char="─", color=CYAN, speed=0.007):
    if quick:
        print("  " + char * WIDTH)
        return
    flush("  " + color)
    for _ in range(WIDTH):
        flush(char)
        time.sleep(speed)
    flush(RESET + "\n")
    sys.stdout.flush()

def animate_progress(value, maximum, bar_width=38, color=GREEN, label=""):
    """Animate a progress bar filling to value/maximum."""
    if maximum <= 0:
        return
    target = int(bar_width * min(value, maximum) / maximum)
    pct_final = int(100 * min(value, maximum) / maximum)
    if quick:
        bar = "█" * target + "░" * (bar_width - target)
        print(f"  {color}▕{bar}▏{RESET} {pct_final:3d}%  {DIM}{label}{RESET}")
        return
    flush(HIDE_CUR)
    for filled in range(target + 1):
        empty = bar_width - filled
        pct   = pct_final if filled == target else int(100 * filled / bar_width)
        bar   = "█" * filled + "░" * empty
        flush(f"\r  {color}▕{bar}▏{RESET} {pct:3d}%  {DIM}{label}{RESET}  ")
        time.sleep(0.025)
    flush("\n" + SHOW_CUR)
    sys.stdout.flush()

def animate_streak(streak, color=GREEN):
    """Count up to the streak number."""
    if quick:
        print(f"  {BOLD}{color}🔥 Current streak : {streak} day(s)!{RESET}")
        return
    flush(HIDE_CUR)
    steps = 20
    for i in range(steps + 1):
        current = int(streak * i / steps)
        flush(f"\r  {BOLD}{color}🔥 Current streak : {current} day(s)!{RESET}     ")
        time.sleep(0.04)
    flush("\n" + SHOW_CUR)
    sys.stdout.flush()

def render_heatmap(contributions, num_weeks=12):
    """Print the last N weeks as a colour-coded grid, one row at a time."""
    today  = date.today()
    monday = today - timedelta(days=today.weekday())
    start  = monday - timedelta(weeks=num_weeks - 1)

    lvl_colors = [
        "\033[38;5;238m",  # 0 commits : dark grey
        "\033[38;5;22m",   # 1-2       : dark green
        "\033[38;5;28m",   # 3-5       : medium green
        "\033[38;5;34m",   # 6-9       : bright green
        "\033[38;5;46m",   # 10+       : vivid green
    ]
    labels = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    for dow in range(7):
        flush(f"  {DIM}{labels[dow]}{RESET} ")
        d = start + timedelta(days=dow)
        cells = []
        while d <= today:
            count = contributions.get(d, 0)
            if   count == 0: lvl = 0
            elif count <= 2: lvl = 1
            elif count <= 5: lvl = 2
            elif count <= 9: lvl = 3
            else:            lvl = 4
            cells.append(lvl_colors[lvl] + "■" + RESET)
            d += timedelta(weeks=1)
        flush(" ".join(cells) + "\n")
        sys.stdout.flush()
        if not quick:
            time.sleep(0.045)

# ── Parse contribution data ────────────────────────────────
data      = sys.argv[1] if len(sys.argv) > 1 else ""
user_id   = sys.argv[2] if len(sys.argv) > 2 else ""
num_weeks = int(sys.argv[3]) if len(sys.argv) > 3 else 12
quick     = sys.argv[4] == "1" if len(sys.argv) > 4 else False

contributions = {}
try:
    parsed = json.loads(data)
    weeks  = parsed["data"]["user"]["contributionsCollection"]["contributionCalendar"]["weeks"]
    for week in weeks:
        for day in week["contributionDays"]:
            d     = date.fromisoformat(day["date"])
            count = day["contributionCount"]
            contributions[d] = count
except (json.JSONDecodeError, KeyError, TypeError):
    pass

if not contributions:
    print()
    animate_divider()
    print(f"{BOLD}  ❓  GitHub Daily Commit Streak{RESET}")
    animate_divider()
    print()
    print(f"  ⚠️  Could not parse contribution data.")
    print(f"  Please check your gh authentication with: gh auth status")
    print()
    animate_divider()
    print()
    sys.exit(1)

today = date.today()
committed_today = contributions.get(today, 0) > 0

# ── Calculate current streak ───────────────────────────────
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
    check    = today
    min_date = min(contributions.keys())
    while check >= min_date:
        if contributions.get(check, 0) > 0:
            break
        gap_days += 1
        check -= timedelta(days=1)

# ── Badge, title, messages, next milestone ─────────────────
if streak == 0:
    badge, title, streak_color = "😴", ("Not started yet" if gap_days == 0 else f"No commits for {gap_days} day(s)..."), RED
    messages = [
        "  Today is the perfect day to start! Make your first commit. 🌱",
        "  A single step begins a great journey. Do it now! 🚀",
    ]
    next_milestone = None
elif streak < 7:
    badge, title, streak_color = "🌱", "A streak is sprouting!", YELLOW
    messages = [
        f"  {streak} day(s) in a row — you're building a great habit! 💪",
        "  Little by little, it all adds up. Keep going! 🔥",
    ]
    next_milestone = 7
elif streak < 30:
    badge, title, streak_color = "🌿", "Growing developer!", GREEN
    messages = [
        f"  {streak} consecutive days! You already have a top developer's habit. ✨",
        "  One month is just around the corner. Don't stop now! 🎯",
    ]
    next_milestone = 30
elif streak < 100:
    badge, title, streak_color = "🌳", "One month and counting!", GREEN
    messages = [
        f"  An incredible {streak} days! What an impressive streak! 🏆",
        "  Your contribution graph is turning beautifully green. 🌈",
    ]
    next_milestone = 100
elif streak < 365:
    badge, title, streak_color = "🔥", "True commit warrior!", MAGENTA
    messages = [
        f"  {streak} days straight! Crossing 100 days makes you legendary. 🌟",
        "  A full year is in sight. Too good to quit now! 💎",
    ]
    next_milestone = 365
else:
    badge, title, streak_color = "👑", "365+ days — you're a legend!", MAGENTA
    messages = [
        f"  {streak} days ({streak // 365}+ year(s))! You are truly legendary. 👑",
        "  Your GitHub garden is completely green. Absolutely inspiring! 🌏",
    ]
    next_milestone = ((streak // 365) + 1) * 365

# ── Render ─────────────────────────────────────────────────
print()
animate_divider("─", CYAN)
print_line(f"{BOLD}  {badge}  GitHub Daily Commit Streak  —  @{user_id}{RESET}")
animate_divider("─", CYAN)
print()

# Contribution heatmap
print_line(f"  {DIM}Last {num_weeks} weeks{RESET}", delay=0.02)
render_heatmap(contributions, num_weeks)
print()

if streak > 0:
    print_line(f"  📅 Started  : {YELLOW}{start_date}{RESET}")
    print_line(f"  📅 Last day : {YELLOW}{end_date}{RESET}")
    print()
    animate_streak(streak, streak_color)
    print()
    print_line(f"  {DIM}Progress toward {next_milestone}-day milestone:{RESET}", delay=0.01)
    animate_progress(streak, next_milestone, color=streak_color,
                     label=f"{streak} / {next_milestone} days")
else:
    if gap_days > 0:
        print_line(f"  {BOLD}{RED}💤 Commit gap : {gap_days} day(s) without a commit{RESET}")
    else:
        print_line(f"  {BOLD}No commit streak on record.{RESET}")

print()
animate_divider("·", MAGENTA, speed=0.005)
print_line(f"  {BOLD}{title}{RESET}")
print()
for msg in messages:
    print_line(msg)
print()
animate_divider("─", CYAN)

# ── 오늘 커밋 없을 때 응원 메시지 ───────────────────────────
if not committed_today:
    print()
    animate_divider("✦", YELLOW, speed=0.005)
    if streak > 0:
        print_line(f"  {BOLD}{YELLOW}⚠️  No commit yet today!{RESET}")
        print()
        print_line(f"  🔥  Your {streak}-day streak is at risk of breaking!")
        print_line(f"  💪  One commit is all it takes to keep it alive.")
        print_line(f"  🎯  Don't let this streak end — you've got this!")
    else:
        print_line(f"  {BOLD}{YELLOW}🌱  No commit yet today!{RESET}")
        print()
        print_line(f"  🚀  Plant your first grass of the day with a single commit.")
        print_line(f"  🌟  Small commits add up to a beautiful green garden.")
        print_line(f"  💡  Stay consistent — today's habit builds tomorrow's streak.")
    print()
    animate_divider("✦", YELLOW, speed=0.005)

print()
EOF
