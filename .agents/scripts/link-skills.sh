#!/usr/bin/env bash
# Mirror .agents/skills/<name> into agent-native skill dirs as relative symlinks.
# Only Claude Code needs this today: Copilot, Codex, Cursor and Gemini CLI read
# .agents/skills/ natively. Add a directory to TARGETS if a new agent needs it.
#
# Usage: .agents/scripts/link-skills.sh [--check]
#   --check  exit 1 if links are missing or stale, without changing anything.
# Compatible with macOS bash 3.2 (no associative arrays).

set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"
TARGETS=".claude/skills"
check=0
[ "${1:-}" = "--check" ] && check=1

skills=""
for dir in "$AGENTS_DIR"/skills/*/ "$AGENTS_DIR"/skills-local/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    skills="$skills $(basename "$(dirname "$dir")")/$(basename "$dir")"
done

drift=0
for target in $TARGETS; do
    mkdir -p "$REPO_ROOT/$target"
    for entry in $skills; do
        src_dir="${entry%%/*}"
        name="${entry#*/}"
        link_target="../../.agents/$src_dir/$name"
        link_path="$REPO_ROOT/$target/$name"
        if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$link_target" ]; then
            continue
        fi
        if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
            echo "ERROR: $target/$name is a real directory. Move it to .agents/skills/ first." >&2
            exit 1
        fi
        drift=1
        if [ "$check" = 1 ]; then
            echo "Missing or stale link: $target/$name"
        else
            rm -f "$link_path"
            ln -s "$link_target" "$link_path"
            echo "Linked: $target/$name -> $link_target"
        fi
    done

    for link in "$REPO_ROOT/$target"/*; do
        [ -L "$link" ] || continue
        case "$(readlink "$link")" in
            ../../.agents/*) ;;
            *) continue ;;
        esac
        name="$(basename "$link")"
        case " $skills " in
            *"/$name "*) continue ;;
        esac
        drift=1
        if [ "$check" = 1 ]; then
            echo "Stale link: $target/$name"
        else
            rm "$link"
            echo "Pruned: $target/$name"
        fi
    done
done

if [ "$check" = 1 ] && [ "$drift" = 1 ]; then
    echo "Run .agents/scripts/link-skills.sh to fix." >&2
    exit 1
fi
exit 0
