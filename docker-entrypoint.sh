#!/bin/sh
# Seeds baked-in template files (CLAUDE.md, .claude/commands/plan.md,
# .claude/settings.json) into the mounted project at /workspace, but only
# for files that don't already exist. Never overwrites anything you've
# already customized. Runs every container start; it's a no-op once the
# files are in place.
set -eu
 
TEMPLATE_DIR="/opt/claude-templates/project"
TARGET_DIR="/workspace"
 
mkdir -p "${TARGET_DIR}/.claude/commands"
 
seed() {
    src="$1"
    dest="$2"
    if [ ! -e "${dest}" ]; then
        cp "${src}" "${dest}"
        echo "claude-code-docker: seeded ${dest#${TARGET_DIR}/}"
    fi
}
 
seed "${TEMPLATE_DIR}/CLAUDE.md"                       "${TARGET_DIR}/CLAUDE.md"
seed "${TEMPLATE_DIR}/.claude/settings.json"           "${TARGET_DIR}/.claude/settings.json"
seed "${TEMPLATE_DIR}/.claude/commands/plan.md"        "${TARGET_DIR}/.claude/commands/plan.md"
 
exec "$@"