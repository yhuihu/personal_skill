param(
    [string]$SourceTable,
    [string]$TargetTable,
    [string]$DbHost = "localhost",
    [int]$DbPort = 2881,
    [string]$DbUser = "root@test",
    [string]$DbPass = "test",
    [string]$DbName = "test"
)
$e=@()
function q($q) {
  $r = cmd /c "docker exec oceanbase-ce obclient -h$DbHost -P$DbPort -u$DbUser -p$DbPass -D$DbName -e ""$q"" -N 2>&1"
  if ($LASTEXITCODE -eq 0) { $r.Trim() }
}
""
"=== Harness: Table Copy Verification ==="
"Source: $SourceTable  Target: $TargetTable"
"Connection: $DbHost`:$DbPort / $DbName"
""
Write-Host "--- [1/2] Row Count ---"
$sc = q "SELECT COUNT(*) FROM $SourceTable"
$tc = q "SELECT COUNT(*) FROM $TargetTable"
if ($sc -eq "" -or $sc -eq $null) { $sc = "0" }
if ($tc -eq "" -or $tc -eq $null) { $tc = "0" }
Write-Host "  Source rows: $sc"
Write-Host "  Target rows: $tc"
if ($sc -eq $tc) {
  Write-Host "  [PASS] Row count matches" -ForegroundColor Green
} else {
  Write-Host "  [FAIL] Row count mismatch" -ForegroundColor Red
  $e += "Row count mismatch"
}
""
Write-Host "--- [2/2] Index Verification ---"
$si = q "SHOW INDEXES FROM $SourceTable"
$ti = q "SHOW INDEXES FROM $TargetTable"
if ($si -eq $ti) {
  Write-Host "  [PASS] Indexes match" -ForegroundColor Green
} else {
  Write-Host "  [FAIL] Indexes differ" -ForegroundColor Red
  $e += "Index mismatch"
}
""
if ($e.Count -eq 0) {
  Write-Host "=== [PASS] Harness: All OK ===" -ForegroundColor Green
  exit 0
} else {
  Write-Host "=== [FAIL] Harness: $($e.Count) error(s) ===" -ForegroundColor Red
  exit 1
}
