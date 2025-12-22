# Parseability Examples

Config and rollback logs use pipe-delimited format: `FIELD1|FIELD2|FIELD3|...`

## Bash/Zsh Examples

### Extract all OS values from config.log
```bash
while IFS='|' read -r timestamp script user pwd call version key value; do
    [[ "$key" == "OS" ]] && echo "Detected OS: $value"
done < ./logs/config.log
```

### Extract REPO_PATH and SHELL_CONFIG
```bash
grep '|REPO_PATH|' ./logs/config.log | cut -d'|' -f8
grep '|SHELL_CONFIG|' ./logs/config.log | cut -d'|' -f8
```

### Timeline: combine config and rollback logs by timestamp
```bash
(cat ./logs/config.log; cat ./logs/rollback.log) | \
    sort -t'|' -k1 | \
    while IFS='|' read -r ts script user pwd call version key_or_action rest; do
        echo "[$ts] $script: $key_or_action"
    done
```

### Extract all revert commands and execute them
```bash
while IFS='|' read -r timestamp script user pwd call version action description revert_cmd; do
    [[ -n "$revert_cmd" ]] && echo "# To revert $action: $revert_cmd"
done < ./logs/rollback.log
```

### Find all alias additions
```bash
grep '|alias_added|' ./logs/rollback.log | cut -d'|' -f8-
```

## PowerShell Examples

### Extract all OS values
```powershell
Get-Content ./logs/config.log | ForEach-Object {
    $fields = $_ -split '\|'
    if ($fields[6] -eq "OS") { Write-Host "Detected OS: $($fields[7])" }
}
```

### Extract REPO_PATH
```powershell
$repoPath = (Get-Content ./logs/config.log | Where-Object { $_ -match '\|REPO_PATH\|' } | ForEach-Object {
    $fields = $_ -split '\|'
    $fields[7]
}) | Select-Object -Last 1
```

### Build timeline
```powershell
$config = Get-Content ./logs/config.log | ForEach-Object { [pscustomobject]@{Log=$_; Type="config"} }
$rollback = Get-Content ./logs/rollback.log | ForEach-Object { [pscustomobject]@{Log=$_; Type="rollback"} }
($config + $rollback) | ForEach-Object {
    $fields = $_.Log -split '\|'
    "$($fields[0]) [$($_.Type)] - $($fields[1])"
} | Sort-Object
```

### Execute all revert commands
```powershell
Get-Content ./logs/rollback.log | ForEach-Object {
    $fields = $_ -split '\|'
    if ($fields[8]) {
        Write-Host "Reverting: $($fields[7])`nCommand: $($fields[8])"
        # Invoke-Expression $fields[8]  # Uncomment to execute
    }
}
```

## Row Count Validation

All files start with `[n]` where n is the data row count:

```bash
# Bash: validate config.log has expected rows
first_line=$(head -n1 ./logs/config.log)
expected_rows=${first_line//[!0-9]/}
actual_rows=$(($(wc -l < ./logs/config.log) - 1))  # Subtract header
[[ "$expected_rows" == "$actual_rows" ]] && echo "✓ Row count valid" || echo "✗ Row count mismatch"
```

```powershell
# PowerShell: validate rollback.log
$first = (Get-Content ./logs/rollback.log)[0]
$expected = [int]($first -replace '\[|\]', '')
$actual = (Get-Content ./logs/rollback.log).Count - 1
if ($expected -eq $actual) { Write-Host "✓ Row count valid" } else { Write-Host "✗ Row count mismatch" }
```

## Joining Config and Rollback by Timestamp

Timeline-building script (bash):
```bash
#!/bin/bash
(cat ./logs/config.log; cat ./logs/rollback.log) | \
    tail -n +2 | \
    sort -t'|' -k1 | \
    while IFS='|' read -r ts script user pwd call version type desc_or_key value_or_revert; do
        case "$type" in
            CALL|OS|SHELL|REPO_PATH)
                echo "$ts|CONFIG|$script|$type=$value_or_revert"
                ;;
            *)
                echo "$ts|ACTION|$script|$type: $desc_or_key"
                ;;
        esac
    done
```
