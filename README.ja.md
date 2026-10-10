Language: [English](README.md) | 日本語

# human-gate

> **2026-08-02 に著者の実運用 harness（著者個人の Claude Code の設定一式）から退役しました。** この repo は歴史的な記録として残しており、著者の harness では使わず、同期もしません。退役の理由は[退役と同期](#退役と同期)にあります。

この repo は、コーディングエージェントの承認ゲートで**人間が何を判断するか**を固定していた常駐 rule（Claude Code が毎セッション読み込む rules ファイル）と、決定論的な検出 hook を記録しています。コーディングエージェントが止まって人間に承認を求める場面を設計する人に向けています。著者の harness では、ゲートの軸として*いつ*止まるか（可逆性・影響範囲）しか命名されていませんでした。この rule は第 2 の軸に答えていました: *止まったとき、人間は実際に何を承認しているのか？*

答え: **生成物（artifact）は機械、意図は人間。** 機械検証できる正しさは決定論ゲートと review agent が持ちます。対象は build・types・lint・tests・secret scan です。手厚いレビュー体制は人間を生成物の検査から*降ろす*ための投資であり、人間が読むためのお膳立てではありません。人間の判断は、テストでは検査できない層に取っておきます。変更が、依頼した人の本当に望むものと合っているかという層です。

## ゲートで提示するもの（対象で分岐）

| 対象 | 提示物 |
|--------|-----------|
| **振る舞いを形づくる生成物**（behavior-shaping artifact）— rules・skills・identity 文書・公開ドキュメント | **本文。** テキストが意図そのもの |
| **制御面**（control plane）— hooks・permission 付与・scheduled task 定義 | **本文。** ここの変更はゲート自体を動かす |
| **証拠生成物** — テスト・fixture・lint 設定・カバレッジ閾値・CI 定義・review agent の prompt・依存 | **本文。** ここの変更は*何をもって検証済みとするか*を動かす: テストを実装に合わせて書き換えれば、嘘をつかずに「全件 PASS」と報告できてしまう |
| **実装コード・自動生成されたファイル** | **固定 5 フィールドの意図の要約**。PASS 一覧は提示せず、下の昇格規則に当たらない限り diff も提示しない |

上書き規則が 2 つあります:

- **不可逆性による昇格**: 不可逆・高影響な変更（データ移行・権限/課金・外部公開・削除処理・鍵ローテーション）は*対象区分によらず*本文または該当差分を提示します。第 1 軸（可逆性）が第 2 軸を上書きします。
- **FAIL は例外**: 決定論ゲートが FAIL したときは検出行そのものを提示します（秘密の実値はマスク）。偽陽性の判定は人間のものです。承認時に人間へ見せるもの（判断面）から外すのは PASS だけで、「見せない」≠「残さない」: PASS の証跡は機械可読ログに保存します。

## 意図の要約の固定スキーマ

自由記述の要約は逸脱を静かに消します。要約は 5 つの必須フィールドで、人間が承認した照合先（実装前に承認された plan）と照合します:

1. **承認済み意図** — plan が言っていたこと
2. **実現した変更** — 実際に起きたこと
3. **plan との差分** — *なし / あり / 再承認が必要* の 3 値のどれかを必ず入れるフィールド
4. **ユーザー・運用への影響**
5. **証拠側の変更** — 検証証拠を作るものが変わっていないか

plan 差分フィールドを必須にしている点が要点です: plan からの逸脱自体は悪くありません。逸脱が要約から消えることが危険なのです。

## なぜ LLM 単独の承認経路を作らないか

review agent は検査者であって承認者ではありません。LLM judge は generator–verifier gap を持ちます。提案者と検査者が同一システムなら、検査は提案者の盲点を継承します。ただし rule は承認経路をこの gap だけから導いてはいません。設計上の決定として、承認は*決定論ゲートの PASS* + *人間の意図の判断*で構成し、judge がどのモデルであっても LLM 単独の sign-off では承認しません。

## Hook の当時の動作

[`hooks/evidence-file-notice.sh`](hooks/evidence-file-notice.sh) は、証拠生成物カテゴリを検出する仕組みでした。`git commit` 時に staged の証拠側ファイルを列挙し、意図の要約に diff の併記を求める PreToolUse hook でした。`additionalContext`（Claude Code がエージェントの文脈に追加するテキスト）を出すだけで、処理は止めませんでした。

当時は `~/.claude/settings.json` に次のように配線していました:

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

## 歴史的 snapshot のインストール

以下は退役済み設計を再現するための記録であり、現行 harness への導入を推奨するものではありません。hook には `git` と `jq` が必要です。

```bash
git clone https://github.com/shimo4228/human-gate.git && cd human-gate
mkdir -p ~/.claude/rules/common ~/.claude/hooks

# Rule: 常駐 rules ディレクトリへコピー
cp rules/common/human-gate.md ~/.claude/rules/common/human-gate.md

# Hook: コピーして settings.json に配線（上のスニペット）
cp hooks/evidence-file-notice.sh ~/.claude/hooks/evidence-file-notice.sh
```

同梱 rule は、著者が以前使っていた実運用 harness の最終 snapshot です。rule 内の相互参照（`coding-style.md`・`planning.md`・`security.md`）は当時の構成を指すため、別環境で再利用する場合は調整してください。

## 退役と同期

退役の日、著者は Claude Code の session-level instruction が、通常の作業の進行を agent に委ね、停止して尋ねるのは安全性や有用性が損なわれる場合に限る方向を示していることを観察しました。著者はこの runtime の観察から、依頼の範囲が承認の境界になったと推論しました（安定した製品仕様ではありません）。この rule はこの既定の上に一律の停止（harness の ADR-0035 の表現）を加えて競合していたため不要になりました。一律の停止とは、どの変更も、実装前に承認された plan と照合した本文または意図の要約を人間が承認するまで止まることです。そこで実運用 harness 側の正本を削除しました。この repo は、役割を終えた足場を外した歴史的事例として残しています。`scripts/sync-from-local.sh` は歴史的 snapshot を削除・置換せず、退役通知を表示して終了します。

## 著者のほかの仕事

- **[人間が承認すべきなのは diff ではなく意図——エージェント承認ゲートの判定表](https://zenn.dev/shimo4228/articles/human-gate-intent-not-diff)**（[English](https://dev.to/shimo4228/what-humans-should-approve-is-intent-not-the-diff-a-decision-table-for-agent-approval-gates-1a3j)）: この rule と並行して書いた記事です。判定表の全体と、証拠生成物を本文で見せなければならない理由が分かります。
- **[Agent Knowledge Cycle](https://github.com/shimo4228/agent-knowledge-cycle)**: この rule が運用していた line of approval（エージェントが自由に書けるものと人間の承認が要るものの境界）と human approval gate を定義している repo です（glossary と ADR-0005）。考え方を引用するときは concept DOI [10.5281/zenodo.19200726](https://doi.org/10.5281/zenodo.19200726) を使ってください。
- **[harness-pruning](https://github.com/shimo4228/harness-pruning)**: 著者のハーネスから退役させた部品を、それぞれの判断とともに日付順に残した記録です。この rule と hook も含まれます。
- **[claude-harness](https://github.com/shimo4228/claude-harness)**: 著者が毎日使っている Claude Code ハーネスの公開版です。この rule を導入した ADR と退役させた ADR もここにあります。
- **[shimo4228](https://github.com/shimo4228/shimo4228)**: 著者のハブです。5 つの長期プロジェクトと DOI があります。

## License

MIT。[LICENSE](LICENSE) を参照してください。

<details>
<summary>ツールと AI アシスタント向けの資料</summary>

human-gate は、コーディングエージェントの承認ゲートで人間が何を承認するかを固定していた、退役済みの Claude Code の rule と hook です。承認ゲートを設計する人のための凍結した記録として、またプラットフォームが役割を吸収した後に足場を外した例として残しています。振る舞いを形づくる生成物（rules・skills・identity 文書・公開ドキュメント）、制御面（hooks・permission 付与・scheduled task）、証拠生成物（テスト・fixture・lint 設定・CI 定義・review agent の prompt・依存）は本文で人間に見せ、実装コードは diff ではなく固定 5 フィールドの意図の要約で見せていました。ただし不可逆・高影響な変更は、本文または該当差分の提示に昇格させていました。

存在した理由は、著者の harness がエージェントがいつ止まるべきか（可逆性・影響範囲）しか命名しておらず、止まった後に人間が何を判断すべきかを決めていなかったからです。この rule の答えは、生成物の正しさは機械（決定論ゲートと review agent）が、意図は人間が持つこと、そして承認は決定論ゲートの PASS と人間の意図の判断で構成し、LLM 単独の sign-off にはしないことでした。2026-08-02 に著者の harness から退役しました。同日の Claude Code の session-level instruction から、著者は依頼の範囲が承認の境界になったと推論し（安定した製品仕様ではなく runtime の観察からの推論です）、止まったときに人間が何を承認するかを固定する独自の rule は、その既定の上に一律の停止（どの変更も、承認済みの plan と照合した本文または意図の要約を人間が承認するまで止まる）を加えて競合しており、不要になったと判断したためです。この判断は harness の ADR-0035 と harness-pruning に記録しています。

基本情報: MIT ライセンスです。日本語の rule ファイル 1 つ（`rules/common/human-gate.md`、著者の harness での最終 snapshot）、Bash の hook 1 つ（`hooks/evidence-file-notice.sh`、`git` と `jq` が必要）、退役通知を表示するだけになった `scripts/sync-from-local.sh` から成ります。著者は shimo4228 です。状態: 凍結した記録です。2026-08-02 に退役し、著者の harness では使わず、同期もしていません。rule は harness の ADR-0019（2026-07-25）で導入され、harness の ADR-0035 で退役しました。どちらも claude-harness で公開しています。再現に必要なもの: Claude Code です。有料の鍵は要りません。

例: hook を `Bash` の PreToolUse hook として配線すると、staged のファイルに `tests/`、`.github/workflows/`、`conftest.py`、`pyproject.toml` などが含まれる `git commit` で、hook はそれらのファイルを列挙し、意図の要約の隣に差分を併記するようエージェントに求める `additionalContext` を返します。commit は止めません。意図の要約は 5 フィールドで、承認済み意図、実現した変更、plan との差分（なし・あり・再承認が必要）、ユーザー・運用への影響、証拠側の変更です。

リンク: [rules/common/human-gate.md](rules/common/human-gate.md) が rule、[hooks/evidence-file-notice.sh](hooks/evidence-file-notice.sh) が hook、[CHANGELOG.md](CHANGELOG.md)（英語）が履歴、[llms.txt](llms.txt)（英語）が機械可読の要約です。この rule は、[Agent Knowledge Cycle](https://github.com/shimo4228/agent-knowledge-cycle)（concept DOI [10.5281/zenodo.19200726](https://doi.org/10.5281/zenodo.19200726)、glossary と ADR-0005）の line of approval と human approval gate、および position paper *Harness Alignment and Harness Drift*（concept DOI [10.5281/zenodo.20578272](https://doi.org/10.5281/zenodo.20578272)、§5）の human-gated property を運用した実装でした。考え方を引用するときはこれらの DOI を使ってください。退役は [harness-pruning](https://github.com/shimo4228/harness-pruning) に記録しています。著者のハブは [shimo4228/shimo4228](https://github.com/shimo4228/shimo4228) です。

</details>
