param(
    [string]$GodotPath = "D:\Godot4\Godot_v4.4-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$clientRoot = Split-Path -Parent $PSScriptRoot
$scripts = Get-ChildItem -LiteralPath $clientRoot -Filter "*.gd" -File -Recurse |
    Sort-Object FullName

foreach ($script in $scripts) {
    $relativePath = $script.FullName.Substring($clientRoot.Length + 1).Replace("\", "/")
    Write-Host "Checking $relativePath"
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $GodotPath `
            -ArgumentList @("--headless", "--path", $clientRoot, "--script", $script.FullName, "--check-only") `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $output = @(
            Get-Content -LiteralPath $stdoutPath
            Get-Content -LiteralPath $stderrPath
        ) | Where-Object { $_ -notmatch "^Godot Engine v" }

        if ($process.ExitCode -ne 0) {
            $output | Write-Host
            throw "GDScript check failed: $relativePath"
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "All $($scripts.Count) GDScript files passed syntax checking."
