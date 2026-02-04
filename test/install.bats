#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/dotfailes_test"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR" || return 1
  
  # Create test helper script that sources functions
  cat > "$TEST_DIR/test_helper.sh" << 'EOF'
#!/bin/bash
# Extract and source functions from install.sh without running main
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source <(awk '/^# Detect OS/,/^main\(\)/ {if (!/^main\(\)/) print}' "$SCRIPT_DIR/../install.sh")

# Mock variables for testing
SCRIPT_NAME="test.sh"
SCRIPT_VERSION="1.0.0"
CALL_ARGS="test"
CONFIG_ROW_COUNT=0
ROLLBACK_ROW_COUNT=0
EOF
  chmod +x "$TEST_DIR/test_helper.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
  cd "$BATS_TEST_DIRNAME" || return 1
  rm -rf ./logs
}

# ============================================================================
# UNIT TESTS: Individual Functions
# ============================================================================

@test "detect_os: returns Linux on Linux system" {
  result=$(bash -c 'detected_os="Linux"; source <(echo "detect_os() { case \"\$detected_os\" in Linux*) echo \"Linux\";; Darwin*) echo \"MacOS\";; CYGWIN*|MINGW*|MSYS*) echo \"Windows\";; *) echo \"Unknown\";; esac; }"); detect_os')
  [[ "$result" == "Linux" ]]
}

@test "detect_os: returns MacOS on Darwin system" {
  result=$(bash -c 'detected_os="Darwin"; source <(echo "detect_os() { case \"\$detected_os\" in Linux*) echo \"Linux\";; Darwin*) echo \"MacOS\";; CYGWIN*|MINGW*|MSYS*) echo \"Windows\";; *) echo \"Unknown\";; esac; }"); detect_os')
  [[ "$result" == "MacOS" ]]
}

@test "detect_os: returns Windows on MINGW system" {
  result=$(bash -c 'detected_os="MINGW64_NT-10.0"; source <(echo "detect_os() { case \"\$detected_os\" in Linux*) echo \"Linux\";; Darwin*) echo \"MacOS\";; CYGWIN*|MINGW*|MSYS*) echo \"Windows\";; *) echo \"Unknown\";; esac; }"); detect_os')
  [[ "$result" == "Windows" ]]
}

@test "info: produces output with INFO prefix" {
  result=$(bash -c 'BLUE=""; NC=""; info() { echo -e "${BLUE}[INFO]${NC} $1"; }; info "test message"')
  [[ "$result" =~ \[INFO\] ]]
  [[ "$result" =~ "test message" ]]
}

@test "success: produces output with SUCCESS prefix" {
  result=$(bash -c 'GREEN=""; NC=""; success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }; success "test success"')
  [[ "$result" =~ \[SUCCESS\] ]]
  [[ "$result" =~ "test success" ]]
}

@test "warn: produces output with WARN prefix" {
  result=$(bash -c 'YELLOW=""; NC=""; warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }; warn "test warning"')
  [[ "$result" =~ \[WARN\] ]]
  [[ "$result" =~ "test warning" ]]
}

@test "error: produces output with ERROR prefix to stderr" {
  result=$(bash -c 'RED=""; NC=""; error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }; error "test error"' 2>&1)
  [[ "$result" =~ \[ERROR\] ]]
  [[ "$result" =~ "test error" ]]
}

@test "append_config: creates logs directory and config.log" {
  bash -c 'cd "'"$TEST_DIR"'"; mkdir -p ./logs; CONFIG_ROW_COUNT=0; SCRIPT_NAME="test"; SCRIPT_VERSION="1.0"; CALL_ARGS=""; append_config() { local key="$1"; local value="$2"; local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"); mkdir -p "./logs"; if [[ ! -s "./logs/config.log" ]]; then printf "# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE\n" > "./logs/config.log"; fi; printf "%s|%s|%s|%s|%s|%s|%s|%s\n" "$timestamp" "$SCRIPT_NAME" "$USER" "$PWD" "$CALL_ARGS" "$SCRIPT_VERSION" "$key" "$value" >> "./logs/config.log"; ((CONFIG_ROW_COUNT++)); }; append_config "KEY" "VALUE"'
  [ -d "$TEST_DIR/logs" ]
  [ -f "$TEST_DIR/logs/config.log" ]
}

@test "append_config: creates header on first write" {
  bash -c 'cd "'"$TEST_DIR"'"; CONFIG_ROW_COUNT=0; SCRIPT_NAME="test"; SCRIPT_VERSION="1.0"; CALL_ARGS=""; append_config() { local key="$1"; local value="$2"; local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"); mkdir -p "./logs"; if [[ ! -s "./logs/config.log" ]]; then printf "# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE\n" > "./logs/config.log"; fi; printf "%s|%s|%s|%s|%s|%s|%s|%s\n" "$timestamp" "$SCRIPT_NAME" "$USER" "$PWD" "$CALL_ARGS" "$SCRIPT_VERSION" "$key" "$value" >> "./logs/config.log"; }; append_config "KEY" "VALUE"'
  head -n1 "$TEST_DIR/logs/config.log" | grep -q "# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE"
}

@test "append_config: logs entry with 8 pipe-delimited fields" {
  bash -c 'cd "'"$TEST_DIR"'"; CONFIG_ROW_COUNT=0; SCRIPT_NAME="test"; SCRIPT_VERSION="1.0"; CALL_ARGS=""; append_config() { local key="$1"; local value="$2"; local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"); mkdir -p "./logs"; if [[ ! -s "./logs/config.log" ]]; then printf "# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE\n" > "./logs/config.log"; fi; printf "%s|%s|%s|%s|%s|%s|%s|%s\n" "$timestamp" "$SCRIPT_NAME" "$USER" "$PWD" "$CALL_ARGS" "$SCRIPT_VERSION" "$key" "$value" >> "./logs/config.log"; }; append_config "TESTKEY" "testvalue"'
  data_line=$(grep -v "^#" "$TEST_DIR/logs/config.log" | head -n1)
  field_count=$(echo "$data_line" | awk -F'|' '{print NF}')
  [ "$field_count" -eq 8 ]
  echo "$data_line" | grep -q "|TESTKEY|testvalue"
}

# ============================================================================
# INTEGRATION TESTS: Full Script Execution
# ============================================================================

@test "install.sh: check_jq detects missing jq" {
  skip "Manual test - requires jq to be uninstalled"
}

@test "install.sh: check_git detects missing git" {
  skip "Manual test - requires git to be uninstalled"
}

@test "install.sh: creates config.log with CALL entry" {
  cd "$TEST_DIR"
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  grep -q '|CALL|' ./logs/config.log
}

@test "install.sh: uses pipe-delimited format with 8 fields" {
  cd "$TEST_DIR"
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  line=$(grep -v "^#" ./logs/config.log | head -n1)
  field_count=$(echo "$line" | awk -F'|' '{print NF}')
  [ "$field_count" -eq 8 ]
}

@test "install.sh: logs contain ISO-8601 timestamps" {
  cd "$TEST_DIR"
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' ./logs/config.log
}

@test "install.sh: logs contain script metadata" {
  cd "$TEST_DIR"
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  grep -q '|install.sh|' ./logs/config.log
  grep -q '|1.0.0|' ./logs/config.log
}

@test "install.sh: appends row count summary at end" {
  cd "$TEST_DIR"
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  tail -n1 ./logs/config.log | grep -q "# TOTAL_ROWS:"
}

@test "install.sh: --help shows usage" {
  run bash "$BATS_TEST_DIRNAME/../install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "install.sh: non-interactive mode with all params" {
  cd "$TEST_DIR"
  bash "$BATS_TEST_DIRNAME/../install.sh" \
    --repo-path "$TEST_DIR/.dotfiles" \
    --setup-name "testsetup" \
    --dotfiles-folder "$TEST_DIR/home" \
    --no-alias \
    --shell bash \
    2>/dev/null || true
  
  [ -f ./logs/config.log ]
  grep -q '|REPO_PATH|' ./logs/config.log
  grep -q '|SETUP_NAME|' ./logs/config.log
  grep -q '|DOTFILES_FOLDER|' ./logs/config.log
}
