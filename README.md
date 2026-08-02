Language: English | [日本語](README.ja.md)

# human-gate

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/shimo4228/human-gate) [![GitMCP](https://img.shields.io/endpoint?url=https://gitmcp.io/badge/shimo4228/human-gate)](https://gitmcp.io/shimo4228/human-gate)

> **Retired from the author's live harness on 2026-08-02.** The platform now treats the operator's task authorization as the approval boundary and lets the agent continue within it, so a second custom approval step was no longer useful. The repository remains as a historical example of removing a scaffold after its role has been absorbed; it is no longer synced from or active in the author's harness.

This repository documents an always-loaded rule (plus a deterministic detection hook) that fixed **what the human judges** at a coding agent's approval gate. Most gate designs only answer *when* to stop (reversibility, blast radius). This rule answered the second axis: *once stopped, what is the human actually approving?*

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

## How the hook worked

[`hooks/evidence-file-notice.sh`](hooks/evidence-file-notice.sh) was the deterministic detection surface for the evidence-producing category. On `git commit`, this PreToolUse hook listed staged evidence-side files and asked the agent to append their diffs to the intent summary. It emitted `additionalContext` and never blocked.

The historical setup used this `~/.claude/settings.json` entry:

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

## Historical installation

These commands are provided only to reproduce the archived design; they are not a recommendation for current harnesses.

```bash
# Rule — copy into your always-loaded rules directory
cp rules/common/human-gate.md ~/.claude/rules/common/human-gate.md

# Hook — copy, then wire it in settings.json (snippet above)
cp hooks/evidence-file-notice.sh ~/.claude/hooks/evidence-file-notice.sh
```

The bundled rule is the final Japanese snapshot from the author's former live setup; this README carries the conceptual summary in English. Its cross-references (`coding-style.md`, `planning.md`, `security.md`) describe that historical harness and may need adaptation if you reuse the rule elsewhere.

## Retirement and sync

The live harness copies were removed on 2026-08-02. `scripts/sync-from-local.sh` now exits with a retirement notice instead of deleting or replacing this historical snapshot.

```bash
scripts/sync-from-local.sh
```

## About this rule

This rule was an operational instance in the author's harness of the approval-gate concepts of the [Agent Knowledge Cycle (AKC)](https://github.com/shimo4228/agent-knowledge-cycle) ([DOI 10.5281/zenodo.19200726](https://doi.org/10.5281/zenodo.19200726)): the **line of approval** and the **human approval gate** (AKC glossary, ADR-0005), and the human-gated property of *Harness Alignment and Harness Drift* ([DOI 10.5281/zenodo.20578272](https://doi.org/10.5281/zenodo.20578272), §5). Its retirement records the point when the platform handled the capability well enough that the explicit scaffold could be removed. Related work by [@shimo4228](https://github.com/shimo4228) includes [Contemplative Agent](https://github.com/shimo4228/contemplative-agent) ([DOI 10.5281/zenodo.19212118](https://doi.org/10.5281/zenodo.19212118)) and [Agent Attribution Practice (AAP)](https://github.com/shimo4228/agent-attribution-practice) ([DOI 10.5281/zenodo.19652013](https://doi.org/10.5281/zenodo.19652013)).

## License

MIT
