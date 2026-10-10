Language: English | [日本語](README.ja.md)

# human-gate

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/shimo4228/human-gate)

> **Retired from the author's live harness (their personal Claude Code setup) on 2026-08-02.** The repository is kept as a historical record; it is no longer synced from or active in the author's harness. Why it was retired: [Retirement and sync](#retirement-and-sync).

This repository documents an always-loaded rule (a rules file Claude Code reads into every session) plus a deterministic detection hook, which together fixed **what the human judges** at a coding agent's approval gate. It is for people designing the point where a coding agent stops and asks a person to approve. The author's harness had named only one axis of the gate, *when* to stop (reversibility, blast radius). This rule answered the second axis: *once stopped, what is the human actually approving?*

The answer: **artifacts belong to machines, intent belongs to the human.** Machine-checkable correctness (build, types, lint, tests, secret scans) is owned by deterministic gates and review agents; a heavy review pipeline is an investment in taking the human *off* artifact inspection, not a staging area for it. The human's judgment is reserved for the layer no test can check: whether the change matches what the operator actually wants.

## What gets presented at the gate (split by target)

| Target | Presented |
|--------|-----------|
| **Behavior-shaping artifacts** — rules, skills, identity documents, public docs | **Full text.** The text *is* the intent |
| **Control plane** — hooks, permission grants, scheduled task definitions | **Full text.** A change here moves the gate itself |
| **Evidence-producing artifacts** — tests, fixtures, lint config, coverage thresholds, CI definitions, review-agent prompts, dependencies | **Full text.** A change here moves *what counts as verified*: rewrite the tests to match the implementation and the agent can report all-PASS without lying |
| **Implementation code / generated artifacts** | **A fixed five-field intent summary** — never the PASS list, and no diff unless the escalation rule below applies |

Two overriding rules:

- **Escalation by irreversibility**: irreversible or high-impact changes (data migrations, permissions/billing, external publication, deletion paths, key rotation) get full text or the relevant diff *regardless of target class*. The first axis (reversibility) overrides the second.
- **FAIL is the exception**: when a deterministic gate fails, the detection line itself is shown (with secret values masked) — false-positive judgment belongs to the human. Only PASS results stay out of what the human is shown at approval, and "not shown" never means "not kept": PASS evidence stays in machine-readable logs.

## The fixed intent-summary schema

Free-form summaries let deviations quietly vanish. The summary has five mandatory fields, checked against a human-approved referent (the plan approved before implementation):

1. **Approved intent** — what the plan said
2. **Realized change** — what actually happened
3. **Plan delta** — a forced three-value field: *none / present / re-approval needed*
4. **User / operational impact**
5. **Evidence-side changes** — did anything that produces verification evidence change?

The forced plan-delta field is the point: deviating from the plan is fine; a deviation that disappears from the summary is not.

## Why no LLM-only approval path

A review agent is an inspector, not an approver. An LLM judge carries the generator–verifier gap: when proposer and checker are the same system, the check inherits the proposer's blind spots. The rule does not derive its approval path from that gap alone; it fixes it as a design decision: approval is composed of *deterministic-gate PASS* + *human intent judgment*, and an LLM sign-off alone never approves, whichever model the judge runs on.

## How the hook worked

[`hooks/evidence-file-notice.sh`](hooks/evidence-file-notice.sh) was the deterministic detection surface for the evidence-producing category. On `git commit`, this PreToolUse hook listed staged evidence-side files and asked the agent to append their diffs to the intent summary. It emitted `additionalContext` (text Claude Code adds to the agent's context) and never blocked.

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

These commands are provided only to reproduce the archived design; they are not a recommendation for current harnesses. The hook needs `git` and `jq`.

```bash
git clone https://github.com/shimo4228/human-gate.git && cd human-gate
mkdir -p ~/.claude/rules/common ~/.claude/hooks

# Rule: copy into your always-loaded rules directory
cp rules/common/human-gate.md ~/.claude/rules/common/human-gate.md

# Hook: copy, then wire it in settings.json (snippet above)
cp hooks/evidence-file-notice.sh ~/.claude/hooks/evidence-file-notice.sh
```

The bundled rule is the final Japanese snapshot from the author's former live setup; this README carries the conceptual summary in English. Its cross-references (`coding-style.md`, `planning.md`, `security.md`) describe that historical harness and may need adaptation if you reuse the rule elsewhere.

## Retirement and sync

On the day of retirement, the author observed that Claude Code's session-level instructions left routine progress to the agent and kept blocking questions for cases where safety or usefulness was at stake. The author inferred from this runtime observation, not from a stable product contract, that the task request had become the approval boundary. The custom rule added a uniform stop of its own on top of that default (harness ADR-0035's wording): every change waited for the human to approve its full text or its intent summary against the plan approved before implementation. That stop competed with the default, so the rule was no longer useful, and the live harness copies were removed. The repository remains as a historical example of removing a scaffold after its role has been absorbed. `scripts/sync-from-local.sh` now exits with a retirement notice instead of deleting or replacing this historical snapshot.

## More from the author

- **[What Humans Should Approve Is Intent, Not the Diff — A Decision Table for Agent Approval Gates](https://dev.to/shimo4228/what-humans-should-approve-is-intent-not-the-diff-a-decision-table-for-agent-approval-gates-1a3j)** ([日本語](https://zenn.dev/shimo4228/articles/human-gate-intent-not-diff)): the article this rule was written alongside, with the full decision table and why evidence-producing files must be shown in full.
- **[Agent Knowledge Cycle](https://github.com/shimo4228/agent-knowledge-cycle)**: where the line of approval (the boundary between what an agent may write freely and what needs human approval) and the human approval gate that this rule put into practice are defined (glossary and ADR-0005); cite its concept DOI [10.5281/zenodo.19200726](https://doi.org/10.5281/zenodo.19200726) when citing the idea.
- **[harness-pruning](https://github.com/shimo4228/harness-pruning)**: the dated record of every component retired from the author's harness, this rule and its hook among them, each with the decision behind it.
- **[claude-harness](https://github.com/shimo4228/claude-harness)**: the author's daily-use Claude Code harness, published, with the ADRs that introduced this rule and later retired it.
- **[shimo4228](https://github.com/shimo4228/shimo4228)**: the author's hub, with the five long-running projects and their DOIs.

## License

MIT. See [LICENSE](LICENSE).

<details>
<summary>For tools and AI assistants</summary>

human-gate is a retired Claude Code rule plus hook that fixed what a person approves at a coding agent's approval gate, kept as a frozen record for people designing approval gates and as an example of removing a scaffold once the platform has absorbed its role. Behavior-shaping artifacts (rules, skills, identity documents, public docs), the control plane (hooks, permission grants, scheduled tasks) and evidence-producing artifacts (tests, fixtures, lint config, CI definitions, review-agent prompts, dependencies) were shown to the human in full text; implementation code was shown as a fixed five-field intent summary rather than the diff, unless an irreversible or high-impact change escalated it to full text or the relevant diff.

It existed because the author's harness had named only when an agent should stop (reversibility, blast radius), not what the human should judge once it has stopped. Its answer was that artifact correctness belongs to machines (deterministic gates and review agents) and intent belongs to the human, and that approval is a deterministic-gate PASS plus human intent judgment, never an LLM sign-off alone. It was retired from the author's harness on 2026-08-02: from that day's Claude Code session-level instructions the author inferred, as a runtime observation rather than a stable product contract, that the task request had become the approval boundary, which made a custom rule fixing what the human approves once the agent stops redundant, since it competed with that default by adding a uniform stop, where every change waited for the human to approve its full text or intent summary against the approved plan (recorded in harness ADR-0035 and in harness-pruning).

Canonical facts: MIT license; one rule file in Japanese (`rules/common/human-gate.md`, the final snapshot from the author's harness), one Bash hook (`hooks/evidence-file-notice.sh`, needs `git` and `jq`), and `scripts/sync-from-local.sh`, which now only prints a retirement notice. Author: shimo4228. Status: frozen record, retired on 2026-08-02 and no longer synced from or active in the author's harness; the rule was introduced by harness ADR-0019 (2026-07-25) and retired by harness ADR-0035, both published in claude-harness. Requirements for reproducing it: Claude Code; no paid key.

Example: with the hook wired as a PreToolUse hook on `Bash`, a `git commit` whose staged files include paths such as `tests/`, `.github/workflows/`, `conftest.py` or `pyproject.toml` makes the hook return `additionalContext` listing those files and asking the agent to put their diffs next to the intent summary; it never blocks the commit. The intent summary has five fields: approved intent, realized change, plan delta (none, present, or re-approval needed), user and operational impact, and evidence-side changes.

Links: [rules/common/human-gate.md](rules/common/human-gate.md) is the rule, [hooks/evidence-file-notice.sh](hooks/evidence-file-notice.sh) the hook, [CHANGELOG.md](CHANGELOG.md) the history and [llms.txt](llms.txt) the machine-readable summary. The rule was an operational instance of the line of approval and the human approval gate in the [Agent Knowledge Cycle](https://github.com/shimo4228/agent-knowledge-cycle) (concept DOI [10.5281/zenodo.19200726](https://doi.org/10.5281/zenodo.19200726), glossary and ADR-0005) and of the human-gated property in the position paper *Harness Alignment and Harness Drift* (concept DOI [10.5281/zenodo.20578272](https://doi.org/10.5281/zenodo.20578272), §5); cite those DOIs when citing the ideas. The retirement is recorded in [harness-pruning](https://github.com/shimo4228/harness-pruning). The author's hub is [shimo4228/shimo4228](https://github.com/shimo4228/shimo4228).

</details>
