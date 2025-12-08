#!/usr/bin/env zsh

# ========================================
# gbare Test Script
# Tests gbare commands directly
# ========================================

# 色付き出力
autoload -U colors && colors

print_success() {
  echo "${fg[green]}✓ $1${reset_color}"
}

print_error() {
  echo "${fg[red]}✗ $1${reset_color}"
}

print_info() {
  echo "${fg[blue]}ℹ $1${reset_color}"
}

print_section() {
  echo ""
  echo "${fg[yellow]}========================================${reset_color}"
  echo "${fg[yellow]}$1${reset_color}"
  echo "${fg[yellow]}========================================${reset_color}"
}

# ========================================
# テスト設定
# ========================================

# gbare プラグインを読み込む
SCRIPT_DIR=$(dirname "$0")
if [[ -f "${SCRIPT_DIR}/gbare.plugin.zsh" ]]; then
  source "${SCRIPT_DIR}/gbare.plugin.zsh"
  print_success "Loaded gbare.plugin.zsh from ${SCRIPT_DIR}"
elif [[ -f "${HOME}/.zsh/plugins/gbare/gbare.plugin.zsh" ]]; then
  source "${HOME}/.zsh/plugins/gbare/gbare.plugin.zsh"
  print_success "Loaded gbare.plugin.zsh from ~/.zsh/plugins/gbare"
else
  print_error "gbare.plugin.zsh not found"
  print_info "Make sure gbare.plugin.zsh is in the same directory as this test script"
  exit 1
fi

TEST_DIR=$(mktemp -d)
TEST_REPO_NAME="test-gbare-$(date +%s)"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_info "Test directory: ${TEST_DIR}"
print_info "Test repository: ${TEST_REPO_NAME}"

# テスト結果記録
test_result() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ $1 -eq 0 ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    print_success "$2"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    print_error "$2"
    return 1
  fi
}

# クリーンアップ関数
cleanup() {
  print_section "Cleanup"
  
  # テストディレクトリを削除
  if [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
    print_success "Removed test directory: ${TEST_DIR}"
  fi
  
  # テストリポジトリを削除（サーバー上）
  print_info "Attempting to remove test repository from server..."
  _gbare_ssh "rm -rf ${GBARE_PATH}/${TEST_REPO_NAME}.git ${GBARE_PATH}/explicit-test-*.git ${GBARE_PATH}/auto-test-*.git" 2>/dev/null
  
  if [[ $? -eq 0 ]]; then
    print_success "Removed test repositories from server"
  else
    print_info "Test repository cleanup completed (may not exist)"
  fi
}

# Ctrl+C でクリーンアップ
trap cleanup EXIT INT TERM

# ========================================
# 前提条件チェック
# ========================================

print_section "Pre-flight Checks"

# gbare コマンドが利用可能か
if ! command -v gbare >/dev/null 2>&1; then
  print_error "gbare command not found after loading plugin"
  exit 1
fi
print_success "gbare command is available"

# 設定確認
print_info "Current configuration:"
gbare config

echo ""
print_info "Testing with:"
echo "  User: ${GBARE_USER}"
echo "  Host: ${GBARE_HOST}"
echo "  Port: ${GBARE_PORT:-(default)}"
echo "  Path: ${GBARE_PATH}"

# SSH接続テスト
echo ""
print_info "Testing SSH connection to ${GBARE_HOST}..."
_gbare_ssh "echo 'SSH connection successful'" >/dev/null 2>&1
test_result $? "SSH connection to ${GBARE_HOST}"

if [[ $? -ne 0 ]]; then
  print_error "Cannot proceed without SSH connection"
  exit 1
fi

# ========================================
# Test 1: gbare help
# ========================================

print_section "Test 1: gbare help"

gbare help >/dev/null 2>&1
test_result $? "gbare help command works"

# ========================================
# Test 2: gbare config
# ========================================

print_section "Test 2: gbare config"

OUTPUT=$(gbare config 2>&1)
echo "$OUTPUT" | grep -q "GBARE_USER"
test_result $? "gbare config displays GBARE_USER"

echo "$OUTPUT" | grep -q "GBARE_HOST"
test_result $? "gbare config displays GBARE_HOST"

# ========================================
# Test 3: gbare list (before creating repo)
# ========================================

print_section "Test 3: gbare list (initial state)"

gbare list >/dev/null 2>&1
test_result $? "gbare list command works"

# ========================================
# Test 4: gbare url (for non-existent repo)
# ========================================

print_section "Test 4: gbare url"

URL=$(gbare url "${TEST_REPO_NAME}" 2>&1)
test_result $? "gbare url command works"

echo "$URL" | grep -q "${TEST_REPO_NAME}.git"
test_result $? "URL contains repository name"

echo "$URL" | grep -q "ssh://"
test_result $? "URL is SSH format"

# ========================================
# Test 5: gbare create with -y flag
# ========================================

print_section "Test 5: gbare create -y (auto-yes flag)"

cd "$TEST_DIR"
mkdir -p "${TEST_REPO_NAME}"
cd "${TEST_REPO_NAME}"

print_info "Creating repository with -y flag (no confirmation needed)..."

# -y フラグで自動承認
gbare create -y >/dev/null 2>&1

test_result $? "gbare create -y with auto directory name"

# ローカルリポジトリが初期化されたか
if [[ -d .git ]]; then
  test_result 0 "Local .git directory created"
else
  test_result 1 "Local .git directory NOT created"
fi

# リモートが追加されたか
git remote -v | grep -q origin
test_result $? "Remote 'origin' added"

# ========================================
# Test 6: gbare info
# ========================================

print_section "Test 6: gbare info"

OUTPUT=$(gbare info "${TEST_REPO_NAME}" 2>&1)
test_result $? "gbare info command works"

echo "$OUTPUT" | grep -q "Repository: ${TEST_REPO_NAME}.git"
test_result $? "Info shows repository name"

echo "$OUTPUT" | grep -q "Server: ${GBARE_HOST}"
test_result $? "Info shows server hostname"

# ========================================
# Test 7: Push to repository
# ========================================

print_section "Test 7: Push to remote repository"

cd "$TEST_DIR/${TEST_REPO_NAME}"

# テストファイルを作成
echo "# ${TEST_REPO_NAME}" > README.md
echo "Test repository created at $(date)" >> README.md

git add README.md
git commit -m "first commit" >/dev/null 2>&1
test_result $? "Git commit with 'first commit' message"

# Push (main または master ブランチ)
git push -u origin main >/dev/null 2>&1 || git push -u origin master >/dev/null 2>&1
test_result $? "Git push to remote successful"

# ========================================
# Test 8: gbare list (should show test repo)
# ========================================

print_section "Test 8: gbare list (verify test repo exists)"

OUTPUT=$(gbare list 2>&1)
echo "$OUTPUT" | grep -q "${TEST_REPO_NAME}"
test_result $? "Test repository appears in list"

# ========================================
# Test 9: gbare clone
# ========================================

print_section "Test 9: gbare clone"

cd "$TEST_DIR"
CLONE_DIR="cloned-${TEST_REPO_NAME}"

print_info "Cloning repository to ${CLONE_DIR}..."
gbare clone "${TEST_REPO_NAME}" "${CLONE_DIR}" >/dev/null 2>&1

test_result $? "gbare clone command successful"

# クローンしたディレクトリが存在するか
if [[ -d "${CLONE_DIR}" ]]; then
  test_result 0 "Cloned directory exists"
else
  test_result 1 "Cloned directory NOT found"
fi

# .git ディレクトリが存在するか
if [[ -d "${CLONE_DIR}/.git" ]]; then
  test_result 0 "Cloned repository has .git directory"
else
  test_result 1 "Cloned repository missing .git directory"
fi

# README.md が存在するか
if [[ -f "${CLONE_DIR}/README.md" ]]; then
  test_result 0 "Cloned repository contains README.md"
else
  test_result 1 "Cloned repository missing README.md"
fi

# ========================================
# Test 10: gbare remote with -y flag
# ========================================

print_section "Test 10: gbare remote -y (auto-yes flag)"

cd "$TEST_DIR"
REMOTE_TEST_DIR="remote-test-${TEST_REPO_NAME}"
mkdir -p "${REMOTE_TEST_DIR}"
cd "${REMOTE_TEST_DIR}"

# 新しいリポジトリを初期化
git init >/dev/null 2>&1
test_result $? "Git init for remote test"

print_info "Adding remote with -y flag (no confirmation needed)..."

# -y フラグで自動承認
gbare remote "${TEST_REPO_NAME}" -y >/dev/null 2>&1

test_result $? "gbare remote -y command successful"

# リモートが追加されたか確認
git remote -v | grep -q origin
test_result $? "Remote 'origin' added via gbare remote -y"

# ========================================
# Test 11: gbare create with explicit name and -y
# ========================================

print_section "Test 11: gbare create <name> -y"

cd "$TEST_DIR"
EXPLICIT_REPO="explicit-test-$(date +%s)"
mkdir -p "${EXPLICIT_REPO}-dir"
cd "${EXPLICIT_REPO}-dir"

print_info "Creating repository with explicit name and -y flag: ${EXPLICIT_REPO}"

# 明示的な名前と -y フラグ
gbare create "${EXPLICIT_REPO}" -y >/dev/null 2>&1

test_result $? "gbare create <name> -y"

# リモートURLが正しいか確認
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
echo "$REMOTE_URL" | grep -q "${EXPLICIT_REPO}.git"
test_result $? "Remote URL contains explicit repository name"

# サーバー上のリポジトリを削除（クリーンアップ）
_gbare_ssh "rm -rf ${GBARE_PATH}/${EXPLICIT_REPO}.git" >/dev/null 2>&1

# ========================================
# Test 12: gbare create -y (auto directory name)
# ========================================

print_section "Test 12: gbare create -y (auto directory name)"

cd "$TEST_DIR"
AUTO_REPO="auto-test-$(date +%s)"
mkdir -p "${AUTO_REPO}"
cd "${AUTO_REPO}"

print_info "Creating repository with -y and auto-detected directory name"

# -y だけで名前は自動検出
gbare create -y >/dev/null 2>&1

test_result $? "gbare create -y (auto directory name)"

# 正しいリポジトリ名でリモートが追加されているか
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
echo "$REMOTE_URL" | grep -q "${AUTO_REPO}.git"
test_result $? "Remote URL contains auto-detected directory name"

# サーバー上のリポジトリを削除
_gbare_ssh "rm -rf ${GBARE_PATH}/${AUTO_REPO}.git" >/dev/null 2>&1

# ========================================
# Test 13: gbare remote with custom remote name and -y
# ========================================

print_section "Test 13: gbare remote <name> <remote> -y"

cd "$TEST_DIR"
CUSTOM_REMOTE_DIR="custom-remote-test"
mkdir -p "${CUSTOM_REMOTE_DIR}"
cd "${CUSTOM_REMOTE_DIR}"

git init >/dev/null 2>&1

print_info "Adding remote with custom name 'upstream' and -y flag"

# カスタムリモート名と -y フラグ
gbare remote "${TEST_REPO_NAME}" upstream -y >/dev/null 2>&1

test_result $? "gbare remote <name> <remote> -y"

# upstream リモートが追加されているか
git remote -v | grep -q upstream
test_result $? "Custom remote 'upstream' added"

# ========================================
# Test 14: gbare delete
# ========================================

print_section "Test 14: gbare delete"

print_info "Deleting test repository: ${TEST_REPO_NAME}"
print_info "This will prompt for confirmation. Type the repository name to continue."

# 確認プロンプトに自動的にリポジトリ名を入力
echo "${TEST_REPO_NAME}" | gbare delete "${TEST_REPO_NAME}"

test_result $? "gbare delete command successful"

# リポジトリが削除されたか確認
sleep 1
OUTPUT=$(gbare list 2>&1)
echo "$OUTPUT" | grep -q "${TEST_REPO_NAME}"

if [[ $? -ne 0 ]]; then
  test_result 0 "Repository successfully removed from server"
else
  test_result 1 "Repository still exists on server"
fi

# ========================================
# Test 15: Helper functions
# ========================================

print_section "Test 15: Helper functions"

# _gbare_remote_url のテスト
URL=$(_gbare_remote_url "test-repo")
echo "$URL" | grep -q "test-repo.git"
test_result $? "_gbare_remote_url function works"

# _gbare_ssh のテスト
_gbare_ssh "echo 'test'" >/dev/null 2>&1
test_result $? "_gbare_ssh function works"

# ========================================
# Test Summary
# ========================================

print_section "Test Summary"

echo ""
echo "Total Tests:  ${TOTAL_TESTS}"
echo "Passed:       ${fg[green]}${PASSED_TESTS}${reset_color}"
echo "Failed:       ${fg[red]}${FAILED_TESTS}${reset_color}"

if [[ $FAILED_TESTS -eq 0 ]]; then
  echo ""
  print_success "All tests passed! 🎉"
  echo ""
  print_info "gbare plugin is working correctly"
  exit 0
else
  echo ""
  print_error "Some tests failed"
  echo ""
  print_info "Review the output above for details"
  exit 1
fi
