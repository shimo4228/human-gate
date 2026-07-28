Language: [English](README.md) | 日本語

# human-gate

コーディングエージェントの承認ゲートで**人間が何を判断するか**を固定する常駐 rule（+ 決定論的検出 hook）です。多くのゲート設計は*いつ*止まるか（可逆性・影響範囲）しか答えません。この rule は第 2 の軸に答えます: *止まったとき、人間は実際に何を承認しているのか？*

答え: **artifact は機械、intent は人間。** 機械検証できる正しさ——build・types・lint・tests・secret scan——は決定論ゲートと review agent が持ちます。手厚いレビュー体制は人間を artifact 検査から*降ろす*ための投資であり、人間が読むためのお膳立てではありません。人間の判断は、テストでは検査できない層——変更が operator の本当に望むものと合っているか——に取っておきます。

## ゲートで提示するもの（対象で分岐）

| 対象 | 提示物 |
|--------|-----------|
| **behavior-shaping artifact** — rules・skills・identity 文書・公開ドキュメント | **本文。** テキストが意図そのもの |
| **control plane** — hooks・permission 付与・scheduled task 定義 | **本文。** ここの変更はゲート自体を動かす |
| **証拠生成物** — テスト・fixture・lint 設定・カバレッジ閾値・CI 定義・review agent の prompt・依存 | **本文。** ここの変更は*何をもって verified とするか*を動かす: テストを実装に合わせて書き換えれば、嘘をつかずに「全件 PASS」と報告できてしまう |
| **実装コード・生成物** | **固定 5 フィールドの意図の要約**——diff も PASS 一覧も提示しない |

上書き規則が 2 つあります:

- **不可逆性による昇格**: 不可逆・高影響な変更（データ移行・権限/課金・外部公開・削除処理・鍵ローテーション）は*対象区分によらず*本文を提示します。第 1 軸（可逆性）が第 2 軸を上書きします。
- **FAIL は例外**: 決定論ゲートが FAIL したときは検出行そのものを提示します（秘密の実値はマスク）——偽陽性の判定は人間のものです。承認面から外すのは PASS だけで、「見せない」≠「残さない」: PASS の証跡は機械可読ログに保存します。

## 意図の要約の固定スキーマ

自由記述の要約は逸脱を静かに消します。要約は 5 つの必須フィールドで、人間が承認した referent（実装前に承認された plan）と照合します:

1. **承認済み意図** — plan が言っていたこと
2. **実現した変更** — 実際に起きたこと
3. **plan との差分** — 強制 3 値: *なし / あり / 再承認が必要*
4. **ユーザー・運用への影響**
5. **証拠側の変更** — 検証証拠を作るものが変わっていないか

強制された plan 差分フィールドが要点です: plan からの逸脱自体は悪くありません。逸脱が要約から消えることが危険なのです。

## なぜ LLM 単独の承認経路を作らないか

review agent は検査者であって承認者ではありません。LLM judge は generator–verifier gap を持ちます——提案者と検査者が同一システムなら、検査は提案者の盲点を継承します。したがって承認は*決定論ゲートの PASS* + *人間の intent 判断*で構成し、LLM 単独の sign-off にはしません。

## Hook

[`hooks/evidence-file-notice.sh`](hooks/evidence-file-notice.sh) は証拠生成物カテゴリの決定論的検出面です: `git commit` で発火する PreToolUse hook で、staged の証拠側ファイル（テスト・CI 定義・lint 設定・依存 manifest…）を列挙し、意図の要約に diff の併記を求めます。`additionalContext` を出すだけで block はしません——どのファイルが証拠側かは構造的性質（パスで決まる = code の担当）、どうするかは人間の判断です。保守的な候補抽出器であり、完全な分類器ではありません。

`~/.claude/settings.json` での配線:

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

## インストール

```bash
# Rule — 常駐 rules ディレクトリへコピー
cp rules/common/human-gate.md ~/.claude/rules/common/human-gate.md

# Hook — コピーして settings.json に配線（上のスニペット）
cp hooks/evidence-file-notice.sh ~/.claude/hooks/evidence-file-notice.sh
```

rule 本文は著者の生きた harness からの verbatim publish（日本語）です。rule 内の相互参照（`coding-style.md`・`planning.md`・`security.md`）はその harness の隣接 rule を指し、[claude-harness](https://github.com/shimo4228/claude-harness) に公開されています——自分の rules ディレクトリに合わせて調整するか、削ってください。

## harness からの同期

正本は著者の生きた Claude Code harness にあります。この repo は一方向の公開ミラーです:

```bash
scripts/sync-from-local.sh --dry-run   # 差分の報告のみ
scripts/sync-from-local.sh             # working tree に適用（commit はしない）
```

## About this rule

この rule は [Agent Knowledge Cycle (AKC)](https://github.com/shimo4228/agent-knowledge-cycle)（[DOI 10.5281/zenodo.19200726](https://doi.org/10.5281/zenodo.19200726)）の承認ゲート概念——**line of approval** と **human approval gate**（AKC glossary・ADR-0005）、および *Harness Alignment and Harness Drift*（[DOI 10.5281/zenodo.20578272](https://doi.org/10.5281/zenodo.20578272)）§5 の human-gated property——の、著者の harness における運用インスタンスです: "What can be verified without the operator runs unattended; every change that shapes behavior passes the gate, and intent enters the loop with it." AKC は [@shimo4228](https://github.com/shimo4228) の 3 研究線の 1 つです（他: [Contemplative Agent](https://github.com/shimo4228/contemplative-agent) [DOI 10.5281/zenodo.19212118](https://doi.org/10.5281/zenodo.19212118)、[Agent Attribution Practice (AAP)](https://github.com/shimo4228/agent-attribution-practice) [DOI 10.5281/zenodo.19652013](https://doi.org/10.5281/zenodo.19652013)）。

## License

MIT
