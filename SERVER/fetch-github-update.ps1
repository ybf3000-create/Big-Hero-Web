param()

$ErrorActionPreference = "Continue"
$env:GIT_TERMINAL_PROMPT = "0"

function ConvertTo-ProxyUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $candidate = $Value.Trim()
    if ($candidate.Contains(";")) {
        $entries = @{}
        foreach ($part in $candidate.Split(";")) {
            $pair = $part.Split("=", 2)
            if ($pair.Count -eq 2) {
                $entries[$pair[0].Trim().ToLowerInvariant()] = $pair[1].Trim()
            }
        }
        if ($entries.ContainsKey("https")) {
            $candidate = $entries["https"]
        }
        elseif ($entries.ContainsKey("http")) {
            $candidate = $entries["http"]
        }
        elseif ($entries.ContainsKey("socks")) {
            $candidate = "socks5h://" + $entries["socks"]
        }
    }

    $candidate = $candidate -replace "^(?i:https?=)", ""
    if ($candidate -notmatch "^[a-zA-Z][a-zA-Z0-9+.-]*://") {
        $candidate = "http://" + $candidate
    }
    return $candidate
}

$candidates = New-Object System.Collections.ArrayList
$seen = @{}

function Add-ProxyCandidate {
    param([string]$Label, [string]$Value)

    $proxyUrl = ConvertTo-ProxyUrl $Value
    if ([string]::IsNullOrWhiteSpace($proxyUrl)) {
        return
    }
    $key = $proxyUrl.ToLowerInvariant()
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        [void]$candidates.Add([pscustomobject]@{ Label = $Label; Url = $proxyUrl })
    }
}

try {
    $target = [Uri]"https://github.com/"
    $resolved = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy($target)
    if ($null -ne $resolved -and $resolved.AbsoluteUri -ne $target.AbsoluteUri) {
        Add-ProxyCandidate "Windows system proxy" $resolved.AbsoluteUri
    }
}
catch {
    # Registry and environment fallbacks below still cover common proxy apps.
}

try {
    $internetSettings = Get-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction Stop
    if ([int]$internetSettings.ProxyEnable -eq 1) {
        Add-ProxyCandidate "Windows configured proxy" ([string]$internetSettings.ProxyServer)
    }
}
catch {
    # A missing user proxy setting simply means this candidate is unavailable.
}

Add-ProxyCandidate "HTTPS_PROXY environment proxy" $env:HTTPS_PROXY
Add-ProxyCandidate "HTTP_PROXY environment proxy" $env:HTTP_PROXY

$gitHttpProxy = (& git config --get http.proxy 2>$null | Select-Object -First 1)
$gitHttpsProxy = (& git config --get https.proxy 2>$null | Select-Object -First 1)
Add-ProxyCandidate "Git HTTPS proxy" ([string]$gitHttpsProxy)
Add-ProxyCandidate "Git HTTP proxy" ([string]$gitHttpProxy)

foreach ($candidate in $candidates) {
    Write-Host ("Trying {0}..." -f $candidate.Label)
    & git -c ("http.proxy={0}" -f $candidate.Url) -c ("https.proxy={0}" -f $candidate.Url) fetch --quiet origin main
    if ($LASTEXITCODE -eq 0) {
        Write-Host ("GitHub connection succeeded through {0}." -f $candidate.Label)
        exit 0
    }
}

Write-Host "Trying a direct connection..."
& git -c "http.proxy=" -c "https.proxy=" fetch --quiet origin main
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub direct connection succeeded."
    exit 0
}

exit 1
