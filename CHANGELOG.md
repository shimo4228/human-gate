# Changelog

All notable changes to this rule are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/).

## [1.0] — initial release

First public release of `human-gate`.

- The second gate axis: artifact correctness belongs to machines, intent to
  the human; presentation splits by target (behavior-shaping artifacts /
  control plane / evidence-producing artifacts → full text; implementation
  code → fixed five-field intent summary with a forced plan-delta field).
- Escalation by irreversibility (axis 1 overrides axis 2), FAIL-line
  exception with secret masking, "not shown ≠ not kept" for PASS evidence.
- Bundled deterministic detection hook (`evidence-file-notice.sh`,
  PreToolUse, non-blocking `additionalContext`).
- Extracted from the author's live harness (harness ADR-0019, 2026-07-25,
  extended 2026-07-28 after cross-model review during article drafting).
