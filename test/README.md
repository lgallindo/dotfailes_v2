# Testing dotfailes

## Overview

This directory contains unit and integration tests for the dotfailes installation script using the [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) framework.

## Setup

BATS is included as a submodule in `test/bats-core/`. If the directory is empty, clone it:

```bash
cd test
git clone https://github.com/bats-core/bats-core.git
```

## Running Tests

### Run All Tests

```bash
./test/bats-core/bin/bats test/install.bats
```

### Run Specific Test

```bash
./test/bats-core/bin/bats test/install.bats --filter "detect_os"
```

### Run with TAP Output

```bash
./test/bats-core/bin/bats --tap test/install.bats
```

### Run with Verbose Output

```bash
./test/bats-core/bin/bats --verbose-run test/install.bats
```

## Test Structure

### Unit Tests

Tests for individual functions:
- `detect_os()` - OS detection logic
- `info()`, `success()`, `warn()`, `error()` - Output formatting functions
- `append_config()` - Configuration logging
- `append_rollback()` - Rollback instruction logging

### Integration Tests

Tests for full script execution:
- Non-interactive mode with CLI arguments
- Log file creation and formatting
- Metadata capture
- Row counting

## Test Coverage

Current test coverage includes:
- ✅ OS detection (Linux, MacOS, Windows)
- ✅ Output functions (info, success, warn, error)
- ✅ Configuration logging with headers
- ✅ Pipe-delimited log format (8 fields)
- ✅ ISO-8601 timestamps
- ✅ Script metadata capture
- ✅ Row count summaries
- ✅ Non-interactive installation
- ⏭️  Interactive mode (requires manual testing)
- ⏭️  Prerequisite checking (jq, git)
- ⏭️  Shell detection and configuration
- ⏭️  Alias creation
- ⏭️  Rollback functionality

## Adding New Tests

Follow this pattern:

```bash
@test "function_name: test description" {
  # Arrange: Set up test environment
  cd "$TEST_DIR"
  
  # Act: Execute code being tested
  result=$(your_function_call)
  
  # Assert: Verify expected outcome
  [[ "$result" == "expected_value" ]]
  [ -f expected_file.log ]
  grep -q "expected_pattern" file.log
}
```

## Debugging Tests

Run with trace mode to see execution:

```bash
bats --trace test/install.bats
```

Or use `run` helper with output inspection:

```bash
@test "example" {
  run bash script.sh
  echo "Status: $status"
  echo "Output: $output"
  [ "$status" -eq 0 ]
}
```

## Troubleshooting

### No Output in Git Bash/MINGW

BATS's default pretty formatter may not render in Git Bash/MINGW terminals. If tests complete with no visible output:

1. **Check exit code**: `echo $?` after running tests (0 = all passed)
2. **Use TAP format**: `./test/bats-core/bin/bats --formatter tap test/install.bats`
3. **Use JUnit format**: `./test/bats-core/bin/bats --formatter junit test/install.bats`
4. **Redirect to file**: `./test/bats-core/bin/bats test/install.bats > results.txt 2>&1`

### Line Ending Issues (Windows)

BATS test files require LF (Unix) line endings, not CRLF (Windows). If you see errors like:
```
SC1017: Literal carriage return. Run script through tr -d '\r'
```

Fix with:
```bash
dos2unix test/install.bats
dos2unix test/simple.bats
```

Or configure Git to handle line endings:
```bash
git config core.autocrlf input
```

### Test Success with No Output

In some terminals, successful test runs show:
- No visible output
- Exit code 0
- Quick completion (~1 second)

This is **normal behavior** - it means all tests passed! The lack of output is due to terminal compatibility, not test failure.

## Dependencies

- Bash 3.2+
- BATS 1.0+
- Standard Unix utilities (awk, grep, sed, etc.)

## CI/CD Integration

To integrate with CI/CD pipelines:

```bash
# GitHub Actions
- name: Run tests
  run: ./test/bats-core/bin/bats test/install.bats

# GitLab CI
test:
  script:
    - ./test/bats-core/bin/bats test/install.bats
```
