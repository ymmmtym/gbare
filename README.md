# gbare

**gbare** は、リモートサーバー（Linux/NAS）上のベアリポジトリを簡単に管理するための zsh プラグインです。

GitHub の `gh` CLI のように、シンプルなコマンドでベアリポジトリの作成、クローン、管理ができます。

## 特徴

- 🚀 **簡単なリポジトリ作成** - `gbare create` で即座にベアリポジトリを作成
- 📁 **自動ディレクトリ名検出** - 引数なしでカレントディレクトリ名を使用
- 🔑 **SSH ベース** - セキュアな SSH 接続を使用
- 🎯 **直感的なコマンド** - `gh` CLI のような使いやすいインターフェース
- ⚡ **確認スキップオプション** - `-y` フラグで自動承認
- 🛠️ **柔軟な設定** - 環境変数でカスタマイズ可能

## 必要要件

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:9a9ca2cbd6ad3bbd768f62cc15ecc258b4e5c479d334e20b671732a7c88a51c0 -->

- zsh 5.0 以降

<!-- /coderabbit-ai-generated:v1 -->
- git
- SSH アクセス可能なサーバー（Linux または Synology NAS など）

## インストール

### Sheldon を使用する場合

**~/.config/sheldon/plugins.toml**

```toml
# 環境変数設定
[plugins.gbare-env]
inline = """
export GBARE_USER="your-username"
export GBARE_HOST="your-server"
export GBARE_PATH="/var/git"
# export GBARE_PORT="22"  # 必要な場合のみ
"""

# gbare プラグイン
[plugins.gbare]
github = "yourusername/gbare"
apply = ["source"]
```

### 手動インストール

```bash
# プラグインをクローン
mkdir -p ~/.zsh/plugins
cd ~/.zsh/plugins
git clone https://github.com/yourusername/gbare.git

# ~/.zshrc に追加
echo 'source ~/.zsh/plugins/gbare/gbare.plugin.zsh' >> ~/.zshrc

# 環境変数を設定
echo 'export GBARE_USER="your-username"' >> ~/.zshrc
echo 'export GBARE_HOST="your-server"' >> ~/.zshrc
echo 'export GBARE_PATH="/var/git"' >> ~/.zshrc

# 再読み込み
source ~/.zshrc
```

## 設定

環境変数で設定をカスタマイズできます:

```bash
export GBARE_USER="your-username"      # SSH ユーザー名
export GBARE_HOST="your-server"        # サーバーのホスト名または IP
export GBARE_PORT="22"                 # SSH ポート（オプション、デフォルトは22）
export GBARE_PATH="/var/git"           # リポジトリのパス
export GBARE_CACHE_TTL="60"            # 一覧キャッシュの秒数（0 で無効、デフォルト 0）
export GBARE_JOBS="4"                  # 一括操作の並列数（デフォルト 1）
```

**デフォルト設定:**
- `GBARE_USER`: `yumenomatayume`
- `GBARE_HOST`: `nas`
- `GBARE_PORT`: (空) - SSH のデフォルト（22）を使用
- `GBARE_PATH`: `/volume1/homes/${GBARE_USER}/git`
- `GBARE_CACHE_TTL`: `0` - キャッシュ無効（例: `60` で 60 秒間再利用）
- `GBARE_CACHE_DIR`: `${XDG_CACHE_HOME:-$HOME/.cache}/gbare`
- `GBARE_JOBS`: `1` - 逐次実行（例: `4` で 4 並列）

現在の設定を確認:
```bash
gbare config
```

## 使い方

### 基本コマンド

```bash
# 新しいリポジトリを作成（カレントディレクトリ名を使用）
gbare create

# 明示的な名前で作成
gbare create myproject

# 確認をスキップして作成
gbare create myproject -y

# リポジトリ一覧を表示
gbare list

# リポジトリをクローン
gbare clone myproject

# リポジトリ情報を表示
gbare info myproject

# リモート URL を取得
gbare url myproject

# 既存のローカルリポジトリにリモートを追加
gbare remote myproject

# 確認をスキップしてリモート追加
gbare remote myproject -y

# リポジトリを削除
gbare delete myproject

# ヘルプを表示
gbare help
```

### 典型的なワークフロー

#### 新規プロジェクトの作成

```bash
# プロジェクトディレクトリを作成
mkdir myproject
cd myproject

# ベアリポジトリを作成（確認付き）
gbare create

# または確認なしで作成
gbare create -y

# ファイルを追加してコミット
echo "# My Project" > README.md
git add .
git commit -m "first commit"
git push -u origin main
```

#### 既存のローカルリポジトリにリモートを追加

```bash
cd existing-project

# ベアリポジトリを作成してリモート追加
gbare create -y

# または、既にサーバー上にリポジトリがある場合
gbare remote existing-project -y
git push -u origin main
```

#### リポジトリのクローン

```bash
# 自分のサーバーからクローン
gbare clone myproject

# 特定のディレクトリにクローン
gbare clone myproject ~/work/myproject
```

## コマンドリファレンス

| コマンド | 短縮形 | 説明 |
|---------|--------|------|
| `gbare create [name] [-y]` | `gbare c` | ベアリポジトリを作成 |
| `gbare list [--refresh]` | `gbare ls`, `gbare l` | リポジトリ一覧を表示 |
| `gbare clone <name> [dir]` | `gbare cl` | リポジトリをクローン |
| `gbare clone -j <n> <name>...` | `gbare cl` | 複数リポジトリを並列クローン |
| `gbare delete <name>...` | `gbare rm`, `gbare d` | リポジトリを削除 |
| `gbare info <name>...` | `gbare i` | リポジトリ情報を表示 |
| `gbare url <name>...` | `gbare u` | SSH URL を取得 |
| `gbare remote [name] [remote] [-y]` | `gbare r` | リモートを追加 |
| `gbare backup [dir] [-j <n>]` | `gbare b` | 全リポジトリをバックアップ |
| `gbare config` | `gbare cfg` | 現在の設定を表示 |
| `gbare help` | `gbare h` | ヘルプを表示 |

### オプション

- `-y`, `--yes`: 確認プロンプトをスキップ（`create` と `remote` で使用可能）
- `-j`, `--jobs <n>`: 同時実行数（`clone`、`delete`、`info`、`backup` で使用可能）
- `--refresh`: キャッシュを無視して再取得（`list` で使用可能）

### キャッシュ

`GBARE_CACHE_TTL` を設定すると、リポジトリ一覧を `GBARE_CACHE_DIR` に
キャッシュします。SSH の往復が減るため、`gbare list` や補完が速くなります。
既定は `0`（無効）です。`create` と `delete` の成功時には自動で無効化され、
`gbare list --refresh` で明示的に取り直せます。

```bash
export GBARE_CACHE_TTL="60"

gbare list              # 初回はサーバーへ問い合わせ、以降は 60 秒キャッシュ
gbare list --refresh    # キャッシュを無視して再取得
```

### 並列処理

`clone`、`delete`、`info`、`backup` は複数のリポジトリを受け取れます。
`GBARE_JOBS` か `-j` で同時実行数を指定すると並列に処理します。

```bash
gbare clone -j 4 one two three   # 4 並列でクローン
gbare info one two three         # 3 件を表示
gbare backup -j 4                # バックアップを 4 並列で実行
```

出力はリポジトリの指定順に並ぶため、並列実行でもログは読みやすいままです。
`delete` は複数指定時に一度だけ確認を求めます。

## 例

### Synology NAS での使用

```bash
# 環境変数を設定
export GBARE_USER="admin"
export GBARE_HOST="192.168.1.100"
export GBARE_PATH="/volume1/homes/admin/git"

# リポジトリを作成
gbare create mynas-project -y

# SSH URL の例
# ssh://admin@192.168.1.100/volume1/homes/admin/git/mynas-project.git
```

### 一般的な Linux サーバーでの使用

```bash
# 環境変数を設定
export GBARE_USER="git"
export GBARE_HOST="git.example.com"
export GBARE_PORT="2222"
export GBARE_PATH="/srv/git"

# リポジトリを作成
gbare create company-project -y

# SSH URL の例
# ssh://git@git.example.com:2222/srv/git/company-project.git
```

### 複数のサーバーを使用

```bash
# デフォルト設定（~/.zshrc）
export GBARE_USER="personal"
export GBARE_HOST="home-nas"
export GBARE_PATH="/var/git"

# 一時的に別のサーバーを使用
GBARE_HOST="work-server" GBARE_PATH="/git" gbare create work-project -y
```

## テスト

テストスクリプトが含まれています:

```bash
# テストを実行
./test-gbare.zsh
```

テストは以下を検証します:
- SSH 接続
- リポジトリの作成と削除
- クローン機能
- リモート追加
- コマンドの動作

## トラブルシューティング

### SSH 接続エラー

```bash
# SSH 接続をテスト
ssh user@your-server "echo 'Connection OK'"

# SSH キーが設定されているか確認
ssh-add -l
```

### リポジトリが見つからない

```bash
# 設定を確認
gbare config

# サーバー上のディレクトリを確認
ssh user@your-server "ls -la /path/to/git"
```

### ポート指定

デフォルトの SSH ポート（22）以外を使用する場合:

```bash
export GBARE_PORT="2222"
```

## よくある質問

**Q: GitHub CLI (`gh`) との違いは?**

A: `gh` は GitHub API を使用しますが、`gbare` は SSH 経由で自分のサーバーのベアリポジトリを管理します。GitHub に依存せず、プライベートなサーバーで使用できます。

**Q: Synology NAS で使えますか?**

A: はい! Synology NAS の Git Server パッケージと完全に互換性があります。

**Q: HTTPS は使えますか?**

A: 現在は SSH のみサポートしています。HTTPS は将来のバージョンで検討します。

**Q: リポジトリをバックアップするには?**

A: サーバー上で通常のファイルバックアップを行うか、別のサーバーにクローンしてミラーとして使用できます。

## ライセンス

MIT License

## 貢献

プルリクエストを歓迎します!

1. このリポジトリをフォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 作者

yumenomatayume

## 関連リンク

- [Git Documentation](https://git-scm.com/doc)
- [Synology Git Server](https://www.synology.com/en-global/dsm/packages/Git)

---

**gbare** を使って、自分のサーバーで快適な Git ライフを! 🚀
