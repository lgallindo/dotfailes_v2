#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/dotfailes_test"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
  rm -rf ./logs
}

@test "install.sh creates config.log with CALL entry" {
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  grep -q '|CALL|' ./logs/config.log
}

@test "install.sh uses pipe-delimited format with 8 fields" {
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  line=$(head -n1 ./logs/config.log)
  field_count=$(echo "$line" | awk -F'|' '{print NF}')
  [ "$field_count" -eq 8 ]
}

@test "install.sh logs contain metadata" {
  bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --shell bash 2>/dev/null || true
  [ -f ./logs/config.log ]
  grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' ./logs/config.log
  grep -q '|install.sh|' ./logs/config.log
}
