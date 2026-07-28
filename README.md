Language: English | [日本語](README.ja.md)

# human-gate

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/shimo4228/human-gate) [![GitMCP](https://img.shields.io/endpoint?url=https://gitmcp.io/badge/shimo4228/human-gate)](https://gitmcp.io/shimo4228/human-gate)

An always-loaded rule (plus a deterministic detection hook) that fixes **what the human judges** at a coding agent's approval gate. Most gate designs only answer *when* to stop (reversibility, blast radius). This rule answers the second axis: *once stopped, what is the human actually approving?*

The answer: **artifacts belong to machines, intent belongs to the human.** Machine-checkable correctness — build, types, lint, tests, secret scans — is owned by deterministic gates and review agents; a heavy review pipeline is an investment in taking the human *off* artifact inspection, not a staging area for it. The human's judgment is reserved for the layer no test can check: whether the change matches what the operator actually wants.

## What gets presented at the gate (split by target)

| Target | Presented |
|--------|-----------|
| **Behavior-shaping artifacts** — rules, skills, identity documents, public docs | **Full text.** The text *is* the intent |
| **Control plane** — hooks, permission grants, scheduled task definitions | **Full text.** A change here moves the gate itself |
| **Evidence-producing artifacts** — tests, fixtures, lint config, coverage thresholds, CI definitions, review-agent prompts, dependencies | **Full text.** A change here moves *what counts as verified*: rewrite the tests to match the implementation and the agent can report all-PASS without lying |
| **Implementation code / generated artifacts** | **A fixed five-field intent summary** — never the diff, never the PASS list |

Two overriding rules:

- **Escalation by irreversibility**: irreversible or high-impact changes (data migrations, permissions/billing, external publication, deletion paths, key rotation) get full text *regardless of target class*. The first axis (reversibility) overrides the second.
- **FAIL is the exception**: when a deterministic gate fails, the detection line itself is shown (with secret values masked) — false-positive judgment belongs to the human. Only PASS results stay off the approval surface, and "not shown" never means "not kept": PASS evidence stays in machine-readable logs.

## The fixed intent-summary schema

Free-form summaries let deviations quietly vanish. The summary has five mandatory fields, checked against a human-approved referent (the plan approved before implementation):

1. **Approved intent** — what the plan said
2. **Realized change** — what actually happened
3. **Plan delta** — a forced three-value field: *none / present / re-approval needed*
4. **User / operational impact**
5. **Evidence-side changes** — did anything that produces verification evidence change?

The forced plan-delta field is the point: deviating from the plan is fine; a deviation that disappears from the summary is not.

## Why no LLM-only approval path

A review agent is an inspector, not an approver. An LLM judge carries the generator–verifier gap — when proposer and checker are the same system, the check inherits the proposer's blind spots. Approval is therefore composed of *deterministic-gate PASS* + *human intent judgment*, never an LLM sign-off alone.

## The hook

[`hooks/evidence-file-notice.sh`](hooks/evidence-file-notice.sh) is the deterministic detection surface for the evidence-producing category: a PreToolUse hook that fires on `git commit`, lists staged evidence-side files (tests, CI definitions, lint config, dependency manifests, …), and asks the agent to append their diffs to the intent summary. It emits `additionalContext`, never blocks — which files are evidence-side is a structural property (path-decidable, so code owns it); what to do about them is the human's call. It is a conservative candidate extractor, not a complete classifier.

Wire it in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/evidence-file-notice.sh" }]
      }
    ]
  }
}
```

## Install

```bash
# Rule — copy into your always-loaded rules directory
cp rules/common/human-gate.md ~/.claude/rules/common/human-gate.md

# Hook — copy, then wire it in settings.json (snippet above)
cp hooks/evidence-file-notice.sh ~/.claude/hooks/evidence-file-notice.sh
```

The rule file is published verbatim from the author's live harness and is written in Japanese; this README carries the full conceptual summary in English. Cross-references inside the rule (`coding-style.md`, `planning.md`, `security.md`) point at sibling rules of that harness, published in [claude-harness](https://github.com/shimo4228/claude-harness) — adapt or drop them for your own rules directory.

## Syncing from the harness

The canonical copies live in the author's live Claude Code harness. This repository is a one-way publication mirror:

```bash
scripts/sync-from-local.sh --dry-run   # report differences only
scripts/sync-from-local.sh             # apply to working tree (never commits)
```

## About this rule

This rule is the operational instance — in the author's harness — of the approval-gate concepts of the [Agent Knowledge Cycle (AKC)](https://github.com/shimo4228/agent-knowledge-cycle) ([DOI 10.5281/zenodo.19200726](https://doi.org/10.5281/zenodo.19200726)): the **line of approval** and the **human approval gate** (AKC glossary, ADR-0005), and the human-gated property of *Harness Alignment and Harness Drift* ([DOI 10.5281/zenodo.20578272](https://doi.org/10.5281/zenodo.20578272), §5): "What can be verified without the operator runs unattended; every change that shapes behavior passes the gate, and intent enters the loop with it." AKC is one of three research lines by [@shimo4228](https://github.com/shimo4228), alongside [Contemplative Agent](https://github.com/shimo4228/contemplative-agent) ([DOI 10.5281/zenodo.19212118](https://doi.org/10.5281/zenodo.19212118)) and [Agent Attribution Practice (AAP)](https://github.com/shimo4228/agent-attribution-practice) ([DOI 10.5281/zenodo.19652013](https://doi.org/10.5281/zenodo.19652013)).

## License

MIT
