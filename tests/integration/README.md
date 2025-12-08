# gbare Integration Tests

## 概要

実際のSSHサーバーを使用した統合テストです。

## ローカルでの実行

### 必要要件

- Docker
- Docker Compose
- zsh
- git

### セットアップと実行

```bash
# Git serverを起動
./tests/integration/setup.sh

# 環境変数を設定
export GBARE_USER=git
export GBARE_HOST=localhost
export GBARE_PORT=2222
export GBARE_PATH=/git-server/repos

# テスト実行
zsh tests/integration/test.zsh

# クリーンアップ
./tests/integration/cleanup.sh
```

## CI/CDでの実行

GitHub Actionsで自動的に実行されます:
- Dockerでgit-serverコンテナを起動
- SSH鍵を設定
- 統合テストを実行
- 自動クリーンアップ

## 注意事項

- ローカル実行時はポート2222が使用されます
- テスト終了後は必ずクリーンアップしてください
- 実際のリポジトリが作成・削除されます
