# gbare Integration Tests

## 注意

このディレクトリの統合テストは実際のSSHサーバーへの接続が必要です。

## 必要要件

- SSH接続可能なサーバー
- サーバー上にgitリポジトリを作成する権限
- 環境変数の設定:
  - `GBARE_USER`
  - `GBARE_HOST`
  - `GBARE_PATH`

## 実行方法

```bash
# 環境変数を設定してから実行
export GBARE_USER="your-username"
export GBARE_HOST="your-server"
export GBARE_PATH="/path/to/git"

# テスト実行
zsh tests/integration/test.zsh
```

## 注意事項

- 実際のサーバーにテストリポジトリが作成されます
- テスト終了後にクリーンアップされますが、失敗時は手動削除が必要な場合があります
- CI/CDでは実行されません（ユニットテストのみ実行）
