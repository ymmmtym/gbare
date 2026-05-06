# ========================================
# gbare - Bare Repository Manager
# Manage bare Git repositories on remote servers
# ========================================

# This file is kept for backward compatibility.
# New installations should use gbare.plugin.zsh which sources modular files from lib/.

local _gbare_root="${0:A:h}"
source "${_gbare_root}/lib/config.zsh"
source "${_gbare_root}/lib/helpers.zsh"
source "${_gbare_root}/lib/core.zsh"
source "${_gbare_root}/lib/completion.zsh"
