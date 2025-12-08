# gbare Tests

## テストの種類

### ユニットテスト (`unit/`)
- SSH接続不要
- 高速実行
- CI/CDで自動実行

### 統合テスト (`integration/`)
- 実際のSSHサーバーが必要
- 手動実行のみ
- CI/CDでは実行されない

## 必要要件

- zsh
- git

外部のテストフレームワークは不要です。カスタムテストフレームワークを使用しています。

## テストの実行

```bash
# すべてのユニットテストを実行
./tests/run_tests.zsh

# 個別のテストファイルを実行
zsh tests/unit/test_gbare.zsh
zsh tests/unit/test_gbare_functions.zsh
```

## テスト構成

- `lib/test_framework.zsh` - カスタムテストフレームワーク
- `unit/test_gbare.zsh` - 基本的なヘルパー関数のテスト
- `unit/test_gbare_functions.zsh` - 詳細な機能テスト
- `run_tests.zsh` - テストランナー

## テストの追加

新しいテストファイルは `tests/unit/test_*.zsh` の命名規則で作成してください。

### テストの書き方

```zsh
#!/usr/bin/env zsh

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test_framework.zsh"

oneTimeSetUp() {
  source "${SCRIPT_DIR}/gbare.zsh"
  # 初期設定
}

test_example() {
  local result=$(some_function "arg")
  assertEquals "expected" "$result" "Test description"
}

runAllTests
exit $?
```

## 利用可能なアサーション

- `assertEquals <expected> <actual> <message>` - 値が等しいことを確認
- `assertContains <haystack> <needle> <message>` - 文字列が含まれることを確認
- `assertTrue <message> <condition>` - 条件が真であることを確認
- `assertFalse <message> <condition>` - 条件が偽であることを確認
