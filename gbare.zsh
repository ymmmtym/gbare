# ========================================
# gbare - Bare Repository Manager
# Manage bare Git repositories on remote servers
# ========================================

# This file is kept for backward compatibility.
# New installations should use gbare.plugin.zsh which sources modular files from lib/.

# 設定（環境変数で上書き可能）
: ${GBARE_USER:="yumenomatayume"}
: ${GBARE_HOST:="nas"}
: ${GBARE_PORT:=""}  # 空文字列がデフォルト（22を指定しない）
: ${GBARE_PATH:="/volume1/homes/${GBARE_USER}/git"}

# Load all modules
source ${0:A:h}/lib/helpers.zsh
source ${0:A:h}/lib/core.zsh
source ${0:A:h}/lib/completion.zsh
