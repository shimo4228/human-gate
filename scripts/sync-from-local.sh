#!/usr/bin/env bash
# sync-from-local.sh — one-way export from the live Claude Code harness
# (~/.claude) into this repo.
#
# human-gate variant: publishes the single harness-canonical rule file
# (rules/common/human-gate.md) PLUS its deterministic detection hook
# (hooks/evidence-file-notice.sh). The published set is an explicit
# allowlist: each component must exist in the harness (and the rule must
# declare the expected origin marker), or the script aborts — it never
# silently drops a published component. Root files (README, LICENSE,
# llms*.txt, CHANGELOG) are never touched. The script never commits —
# `git diff` in this repo is the review gate.
#
# Usage:
#   scripts/sync-from-local.sh --dry-run   # report differences only
#   scripts/sync-from-local.sh             # apply to working tree
#
# Config (env overrides):
#   HARNESS_SYNC_SOURCE  source harness dir      (default: ~/.claude)
#   HARNESS_SYNC_ORIGIN  origin value to require (default: shimo4228)

set -euo pipefail

SOURCE_DIR="${HARNESS_SYNC_SOURCE:-$HOME/.claude}"
ORIGIN="${HARNESS_SYNC_ORIGIN:-shimo4228}"
TARGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# the fixed published set (allowlist), relative to harness root / repo root
RULE_REL="rules/common/human-gate.md"
HOOK_REL="hooks/evidence-file-notice.sh"
SUBTREES=(rules hooks)

DRY_RUN=0
[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && DRY_RUN=1

# read the header into a variable first: piping head into grep can take head's
# SIGPIPE exit under `set -o pipefail` and spuriously fail; -F matches literally
# so an overridden ORIGIN cannot act as a regex.
has_origin() {
  local header
  header="$(head -15 "$1")"
  grep -qF "origin: $ORIGIN" <<<"$header"
}

# --- guard: every published component must exist (rule must declare origin) ---
if [[ ! -f "$SOURCE_DIR/$RULE_REL" ]]; then
  echo "ABORT: $SOURCE_DIR/$RULE_REL not found — harness copy missing." >&2
  exit 1
fi
if ! has_origin "$SOURCE_DIR/$RULE_REL"; then
  echo "ABORT: $SOURCE_DIR/$RULE_REL does not declare 'origin: $ORIGIN'." >&2
  exit 1
fi
if [[ ! -f "$SOURCE_DIR/$HOOK_REL" ]]; then
  echo "ABORT: $SOURCE_DIR/$HOOK_REL not found — harness copy missing." >&2
  exit 1
fi

# --- guard: managed subtrees must be clean so the sync delta is reviewable ---
if (( ! DRY_RUN )); then
  if ! git -C "$TARGET_DIR" diff --quiet -- "${SUBTREES[@]}" ||
     ! git -C "$TARGET_DIR" diff --cached --quiet -- "${SUBTREES[@]}"; then
    echo "ABORT: uncommitted changes in ${SUBTREES[*]} — commit or stash first," >&2
    echo "       so that 'git diff' after sync shows exactly the sync delta." >&2
    exit 1
  fi
fi

# --- staging ---
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/rules/common" "$STAGING/hooks"

cp "$SOURCE_DIR/$RULE_REL" "$STAGING/$RULE_REL"
cp "$SOURCE_DIR/$HOOK_REL" "$STAGING/$HOOK_REL"
chmod +x "$STAGING/$HOOK_REL"

# --- secret scan (high-confidence patterns; abort on any hit) ---
SECRET_RE='sk-ant-api[0-9A-Za-z_-]+|ghp_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{20,}|AKIA[0-9A-Z]{16}|xox[bporas]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|hf_[A-Za-z]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY'
if hits="$(grep -rEl "$SECRET_RE" "$STAGING" 2>/dev/null)"; then
  echo "ABORT: potential secrets detected in staged payload:" >&2
  echo "$hits" >&2
  exit 1
fi

# --- report / apply ---
if (( DRY_RUN )); then
  echo "# DRY-RUN (origin: $ORIGIN) — differences staging vs $TARGET_DIR"
  for t in "${SUBTREES[@]}"; do
    diff -rq "$STAGING/$t" "$TARGET_DIR/$t" 2>/dev/null || true
  done
  exit 0
fi

for t in "${SUBTREES[@]}"; do
  rm -rf "${TARGET_DIR:?}/$t"
done
cp -R "$STAGING"/. "$TARGET_DIR"/
