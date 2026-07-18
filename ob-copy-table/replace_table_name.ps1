param(
    [string]$FilePath,
    [string]$SourceName,
    [string]$TargetName
)

$escaped = [regex]::Escape($SourceName)
$pattern = "(CREATE\s+TABLE\s+)(``?)$escaped(``?)"
$replacement = '$1$2' + $TargetName + '$3'

(Get-Content $FilePath) -replace $pattern, $replacement | Set-Content $FilePath
