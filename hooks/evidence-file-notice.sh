#!/usr/bin/env bash
# evidence-file-notice.sh — PreToolUse hook (Bash): git commit 前に「検査の証拠を作る
# ファイル」を列挙する。
#
# rules/common/human-gate.md「検査の証拠を作るもの → 本文を提示する」の決定論的な
# 検出面。エージェントがテスト・lint 設定・CI 定義・依存を実装に合わせて緩めた場合、
# 嘘をつかずに「全件 PASS」と要約できてしまう (2026-07-28 cross-model review)。
# どのファイルが証拠側かはパスで決まる = 構造的性質なので code が持つ
# (rules/common/patterns.md の Code vs LLM seam)。
#
# 入力: stdin から JSON (tool_input.command)
# 出力: staged に証拠側ファイルがあれば additionalContext で列挙 (= allow のまま通知)
#       それ以外は無出力
# block しない — 「証拠側を触るな」ではなく「本文を併記せよ」という提示物の規約であり、
# 判断はゲートの人間が持つ。完全な分類器ではなく保守的な候補抽出である点も block しない理由
# (通常コードに埋め込まれたテスト・独自ディレクトリ・lockfile は取り逃す)。

set -euo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""

[[ -z "$COMMAND" ]] && exit 0

# git commit を含むコマンドのみ対象 (secret-scan-precommit.sh と同一の判定)
printf '%s' "$COMMAND" | grep -qE '\bgit\b[^;|&]*[[:space:]]commit\b' || exit 0

# 対象 repo の特定: `git -C <path> ... commit` > 先頭の `cd <path> &&` > カレント
repo_dir=""
c_re='(^|[;&|])[[:space:]]*git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[^;&|]*[[:space:]]commit([[:space:]]|$)'
if [[ "$COMMAND" =~ $c_re ]]; then
  repo_dir="${BASH_REMATCH[2]}"
elif [[ "$COMMAND" =~ ^cd[[:space:]]+([^[:space:];&|]+) ]]; then
  repo_dir="${BASH_REMATCH[1]}"
fi
repo_dir="${repo_dir/#\~/$HOME}"

if [[ -n "$repo_dir" ]]; then
  cd "$repo_dir" 2>/dev/null || exit 0
fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# 証拠側ファイルの候補抽出。自分の repo に合わせて育てる想定の保守的リスト。
EVIDENCE_RE='^(tests?/|spec/|\.github/workflows/|\.claude/(agents|hooks|skills)/|hooks/)|(_test\.|\.test\.|_spec\.|conftest\.py|pyproject\.toml|package\.json|ruff\.toml|\.eslintrc|setup\.cfg|tox\.ini|codecov\.ya?ml|\.pre-commit-config\.ya?ml)'

hits=$(git diff --cached --name-only 2>/dev/null | grep -E "$EVIDENCE_RE" || true)
[[ -z "$hits" ]] && exit 0

count=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')
list=$(printf '%s\n' "$hits" | sed 's/^/  - /')

jq -n --arg ctx "検査の証拠を作るファイルが staged に ${count} 件あります (human-gate.md: 本文提示側)。
${list}

意図の要約だけで畳まず、該当ファイルの差分を人間に併記してください。判定そのものではなく
「何をもって PASS とみなすか」が変わっている可能性があります。テストが実装に合わせて
緩められていないかは、この差分でしか見えません。" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
