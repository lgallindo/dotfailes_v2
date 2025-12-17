@test "install.sh non-interactive mode sets up repo and alias" {
  run bash "$BATS_TEST_DIRNAME/../install.sh" --repo-path "$TEST_DIR/.dotfiles" --setup-name "testsetup" --dotfiles-folder "$TEST_DIR" --remote "https://example.com/repo.git"
  [ "$status" -eq 0 ]
  [ -f install_config.csv ]
  grep -q 'dotfailes alias' "$HOME/.bash_aliases" || grep -q 'dotfailes alias' "$HOME/.bashrc"
}
#!/usr/bin/env bats

setup() {
  export TEST_DIR="$BATS_TMPDIR/dotfailes_test"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "install.sh creates install_config.csv and logs alias" {
  run bash "$BATS_TEST_DIRNAME/../install.sh" <<< $'y\n\n\n\n\ny\n'
  [ "$status" -eq 0 ]
  [ -f install_config.csv ]
  grep -q 'ALIAS_CMD' install_config.csv
}

@test "install.sh loads from install_config.csv if present" {
  echo 'ALIAS_CMD,ROLLBACK_LOG,SCRIPT,SHELL_CONFIG,DEFAULT_REPO_PATH,DEFAULT_SETUP_NAME,DEFAULT_FOLDER' > install_config.csv
  echo "alias dotfiles='git --git-dir=/tmp/.dotfiles --work-tree=/tmp',/tmp/rollback.log,dotfailes.sh,/tmp/.bashrc,/tmp/.dotfiles,mysetup,/tmp" >> install_config.csv
  run bash "$BATS_TEST_DIRNAME/../install.sh" <<< $'n\n'
  [ "$status" -eq 0 ]
}
