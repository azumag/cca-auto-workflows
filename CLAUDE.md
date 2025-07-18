# 絵文字を使うな

# Github actions
## anthropics/claude-code-action@beta
### 仕様： https://github.com/anthropics/claude-code-action/blob/main/README.md

### 非対応
anthropics/claude-code-action@beta を使うとき以下が非対応です.
github actions github-script のみの利用のときは使用可能です。

- workflow_run
- repository_dispatch

## Github actions
自動で作成した github actions からの comment, label などではアクションをトリガーできない
PATで作成したものはトリガーされる。