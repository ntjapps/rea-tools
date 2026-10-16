#!/bin/bash
# Install (or refresh) the REA skill for Claude Code, on demand only: the skill from the ntjapps/rea fork at a pinned
# commit plus this host's section (claude/host-section.md). No MCP server is registered.
# Usage: ./install-skill.sh [commit]   (default: REA_SKILL_COMMIT below). Needs an authenticated `gh`.
# Target: $CLAUDE_CONFIG_DIR/skills (default ~/.claude/skills). An existing copy is backed up first.
set -euo pipefail
REA_SKILL_COMMIT="${1:-1bd5c5c87e81}"
REPO=ntjapps/rea
SRC=.agents/skills/reverse-engineer-anything
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/reverse-engineer-anything"
FILES=(SKILL.md references/android-applications.md references/connection-and-recovery.md
       references/evidence-workflows.md references/javascript-applications.md
       references/native-and-artifacts.md references/runtime-observation.md)

SHA="$(gh api "repos/$REPO/commits/$REA_SKILL_COMMIT" --jq .sha)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/references"
for f in "${FILES[@]}"; do
    gh api "repos/$REPO/contents/$SRC/$f?ref=$SHA" --jq .content | base64 -d > "$TMP/$f"
done
# Insert the host section right after the YAML front matter.
python3 - "$TMP/SKILL.md" "$HERE/claude/host-section.md" <<'EOF'
import sys
skill, host = sys.argv[1], open(sys.argv[2]).read()
s = open(skill).read()
end = s.index("\n---\n", 4) + 5
open(skill, "w").write(s[:end] + "\n" + host.rstrip() + "\n" + s[end:])
EOF
echo "$SHA" > "$TMP/.source-commit"

if [ -e "$DEST" ]; then
    BAK="$DEST.bak-$(date +%Y%m%d%H%M%S)"
    mv "$DEST" "$BAK"
    echo "backed up the previous skill to $BAK"
fi
mkdir -p "$(dirname "$DEST")"
cp -r "$TMP" "$DEST"
chmod 755 "$DEST" "$DEST/references"
echo "installed reverse-engineer-anything ($SHA) to $DEST; start a new Claude Code session to load it"
