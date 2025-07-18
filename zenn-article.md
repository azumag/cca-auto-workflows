---
title: "Claude Code Actions で完全自動開発ワークフローを構築する"
type: "tech"
topics: ["github-actions", "claude", "ai", "automation", "devops"]
published: false
---

# Claude Code Actions で完全自動開発ワークフローを構築する

## はじめに

今回、AnthropicのClaude Code Actionsを活用して、Issue の作成から実装、PR作成、マージまでを完全に自動化したワークフローを構築しました。このシステムでは、人間の介入なしに継続的な開発サイクルが回り続けます。

本記事では、このワークフローの仕組み、技術的な実装方法、そして GitHub Actions の制限を回避するための工夫について詳しく解説します。

## システム概要

### ワークフロー図

```mermaid
graph TD
    A[Daily Issue Creator<br/>毎日6時にIssue作成] --> B[Auto Issue Resolver<br/>毎時間ランダムIssue選択]
    B --> C[processing ラベル追加]
    C --> D[Issue Processor<br/>Claude Code Actions 実行]
    D --> E[Claude による実装]
    E --> F[pr-ready ラベル追加]
    F --> G[GitHub App Token 生成]
    G --> H[PR 自動作成]
    H --> I[pr-created ラベル追加]
    I --> J[CI/CD パイプライン実行]
    J --> K[Auto Merge<br/>（将来実装予定）]
    
    style A fill:#e1f5fe
    style D fill:#f3e5f5
    style E fill:#f3e5f5
    style G fill:#fff3e0
    style H fill:#fff3e0
```

### システムの特徴

1. **完全自動化**: 人間の介入なしに開発サイクルが継続
2. **無限ループ回避**: PAT と GitHub App の使い分けで Actions の制限を回避
3. **ラベルベース状態管理**: 各段階を明確にラベルで管理
4. **スケーラブル**: 複数の Issue を並行処理可能

## 技術的実装

### 1. 日次 Issue 作成

```yaml
name: Daily Issue Creator

on:
  schedule:
    # 毎日午前6時（JST）に実行 (UTC 21:00)
    - cron: '0 21 * * *'
  workflow_dispatch:

jobs:
  create-daily-issue:
    runs-on: ubuntu-latest
    steps:
      - name: Create System Improvement Issue
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          script: |
            const title = "システム改善";
            const body = [
              "# Daily System Improvement Task",
              "## 概要",
              "このタスクは、システムの改善を目的とした日次のタスクです。",
              // ... 詳細な説明
            ].join('\n');
            
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: title,
              body: body,
              labels: ['daily-task', 'auto-generated']
            });
```

**ポイント**:
- `PERSONAL_ACCESS_TOKEN` を使用してワークフローをトリガー可能にする
- cron で定期実行し、継続的な開発タスクを生成

### 2. ランダム Issue 処理

```yaml
name: Auto Issue Resolver

on:
  schedule:
    - cron: '0 * * * *'  # 毎時間実行

jobs:
  process-issue:
    runs-on: ubuntu-latest
    steps:
      - name: Select and add processing label to random issue
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
          script: |
            const allIssues = await github.rest.issues.listForRepo({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'open',
              per_page: 100
            });

            // processing ラベルが付いていないissueをフィルタリング
            const availableIssues = allIssues.data.filter(issue =>
              !issue.labels.some(label => label.name === 'processing')
            );

            // ランダムに一つ選択
            const randomIndex = Math.floor(Math.random() * availableIssues.length);
            const selectedIssue = availableIssues[randomIndex];

            // processing ラベルを追加
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: selectedIssue.number,
              labels: ['processing']
            });
```

**ポイント**:
- 既に処理中の Issue を除外してランダム選択
- `processing` ラベルで重複処理を防止

### 3. Claude Code Actions による実装

```yaml
name: Issue Processor

on:
  issues:
    types: [labeled]

jobs:
  process-issue:
    if: |
      (github.event.action == 'labeled' && github.event.label.name == 'processing')
    
    steps:
      - name: Run Claude Code for Issue Implementation
        uses: anthropics/claude-code-action@beta
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          allowed_tools: "Agent,Bash,Edit,MultiEdit,WebFetch,WebSearch,Write"
          
          direct_prompt: |
            このIssue #${{ github.event.issue.number }} を解決してください。
            実装が完了したら、pr-ready ラベルをこの Issue に追加してください

            **タイトル**: ${{ github.event.issue.title }}
            **説明**: ${{ github.event.issue.body || '説明なし' }}
```

**ポイント**:
- Issue がラベリングされた瞬間に Claude が実装開始
- 実装完了後に `pr-ready` ラベルを追加するよう指示

### 4. GitHub App を使った PR 作成

```yaml
      - name: Generate GitHub App Token
        if: steps.check-pr-trigger.outputs.create_pr == 'true'
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}

      - name: Create Pull Request
        uses: actions/github-script@v7
        with:
          github-token: ${{ steps.app-token.outputs.token }}
          script: |
            // Claude が生成した PR リンクを解析
            const comments = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: issueNumber
            });
            
            // PR 作成
            const pr = await github.rest.pulls.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Fix: ${issueTitle}`,
              body: `Fixes #${issueNumber}\n\nAuto-generated PR to resolve issue.`,
              head: head,
              base: base
            });
```

## なぜ完全自動化が可能なのか

### 1. PAT と GitHub App の使い分け

GitHub Actions には重要な制限があります：

> **GitHub Actions からの自動アクションではワークフローがトリガーされない**

この制限を回避するため、以下の使い分けを行っています：

| アクション | 使用トークン | 理由 |
|-----------|-------------|------|
| Issue 作成・ラベル操作 | Personal Access Token (PAT) | ワークフローをトリガーするため |
| PR 作成・マージ | GitHub App Token | 自己マージを可能にするため |

### 2. PAT の重要性

```yaml
github-token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
```

PAT を使用することで：
- 自動作成した Issue でもワークフローがトリガーされる
- ラベル追加時に Issue Processor が起動する
- 無限ループを防ぎつつ継続的な自動化が可能

### 3. GitHub App が必要な理由

PR の自己マージには特別な権限が必要です：

```yaml
# GitHub App Token で PR 作成
github-token: ${{ steps.app-token.outputs.token }}
```

**通常のトークンでは不可能な操作**:
- 自分が作成した PR を自分でマージ
- 制限されたブランチ保護ルールの回避

## 権限設定とセキュリティ

### 必要な権限

#### GitHub App 権限
```
- Contents: Write (コード変更)
- Pull Requests: Write (PR 作成・マージ)
- Issues: Write (Issue 操作)
- Actions: Read (CI 結果確認)
```

#### PAT 権限
```
- repo (フルアクセス)
- workflow (ワークフロー実行)
```

### セキュリティ考慮事項

1. **最小権限の原則**
   - GitHub App は必要最小限の権限のみ
   - PAT は信頼できるボットアカウントで作成

2. **トークン管理**
   ```yaml
   secrets:
     CLAUDE_CODE_OAUTH_TOKEN: "Claude API アクセス用"
     PERSONAL_ACCESS_TOKEN: "ワークフロートリガー用"
     APP_ID: "GitHub App ID"
     APP_PRIVATE_KEY: "GitHub App 秘密鍵"
   ```

3. **監査ログ**
   - すべての自動アクションをログで追跡
   - ラベルベースで状態管理し透明性を確保

## 無限ループ制限の回避

### GitHub Actions の制限

GitHub Actions には以下の制限があります：

1. **GITHUB_TOKEN では他のワークフローをトリガーできない**
2. **Actions から作成されたコメント・ラベルではワークフローが起動しない**

### 回避策

```yaml
# ❌ 無限ループの原因
github-token: ${{ secrets.GITHUB_TOKEN }}

# ✅ 正しい設定
github-token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
```

**理由**:
- PAT は「人間のユーザー」として認識される
- GitHub Actions の制限を受けない
- 他のワークフローを正常にトリガーできる

### 実装パターン

```mermaid
sequenceDiagram
    participant Cron as Cron Trigger
    participant PAT as PAT Actions
    participant Claude as Claude Actions
    participant App as GitHub App

    Cron->>PAT: Issue 作成
    PAT->>Claude: ラベル追加 (processing)
    Claude->>Claude: 実装実行
    Claude->>PAT: ラベル追加 (pr-ready)
    PAT->>App: GitHub App Token 生成
    App->>App: PR 作成・マージ
```

## 注意点と制限

### 1. レート制限

```yaml
# GitHub API レート制限対策
- name: Wait before next action
  run: sleep 10
```

### 2. Claude Code Actions の制限

現在の Claude Code Actions では以下が非対応：
- `workflow_run` イベント
- `repository_dispatch` イベント

### 3. コスト管理

```yaml
# 実行時間制限
timeout-minutes: 30

# 並行実行制限
concurrency:
  group: issue-processing
  cancel-in-progress: false
```

### 4. エラーハンドリング

```yaml
- name: Handle Errors
  if: failure()
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.issues.addLabels({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.payload.issue.number,
        labels: ['error', 'needs-manual-review']
      });
```

## 今後の改善点

1. **自動マージ機能**
   - CI パス後の自動マージ
   - コード品質チェック

2. **優先度システム**
   - 重要度に応じた Issue 処理
   - SLA 管理

3. **フィードバックループ**
   - 実装品質の自動評価
   - 学習機能の追加

## まとめ

Claude Code Actions を活用することで、完全自動開発ワークフローが実現できました。重要なポイントは：

1. **PAT と GitHub App の適切な使い分け**
2. **GitHub Actions の制限を理解した設計**
3. **ラベルベースの明確な状態管理**
4. **セキュリティを考慮した権限設定**

このシステムにより、継続的な改善サイクルが人間の介入なしに回り続け、開発効率の大幅な向上が期待できます。

現在もこのワークフローは稼働中で、日々新しい機能や改善が自動的に実装されています。AI を活用した開発の新しい可能性を示す事例として、参考にしていただければ幸いです。