[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$InputPath,

    [ValidateSet('pipeline', 'vlm-auto-engine', 'hybrid-auto-engine')]
    [string]$Backend = 'hybrid-auto-engine',

    [string]$OutputRoot = (Join-Path (Get-Location).Path 'mineru-output'),
    [string]$Distro = '',
    [string]$VenvPath = '~/venvs/mineru',
    [string]$ModelSource = '',
    [switch]$Install,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if ([System.Console]::OutputEncoding.WebName -ne 'utf-8') {
    [System.Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}

function Normalize-WindowsPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $normalized = $Path.Trim()
    if ($normalized.StartsWith('file:///', [System.StringComparison]::OrdinalIgnoreCase)) {
        $uri = [System.Uri]$normalized
        $normalized = [System.Uri]::UnescapeDataString($uri.LocalPath)
    }
    return [System.IO.Path]::GetFullPath($normalized)
}

function ConvertTo-WslPath {
    param([Parameter(Mandatory = $true)][string]$WindowsPath)

    $full = Normalize-WindowsPath -Path $WindowsPath
    if ($full -notmatch '^([A-Za-z]):\\(.*)$') {
        throw "Only drive-letter Windows paths are supported for WSL conversion: $WindowsPath"
    }

    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2] -replace '\\', '/'
    return "/mnt/$drive/$rest"
}

function Quote-Bash {
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + ($Value -replace "'", "'\''") + "'"
}

function Quote-BashPath {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -eq '~') {
        return '~'
    }
    if ($Value.StartsWith('~/')) {
        $rest = $Value.Substring(2)
        if ([string]::IsNullOrEmpty($rest)) {
            return '~'
        }
        return "~/" + (Quote-Bash $rest)
    }
    return Quote-Bash $Value
}

function Quote-PowerShellDisplay {
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

function Get-WslDistroNames {
    $raw = & wsl -l -q 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to list WSL distributions. Ensure WSL2 is installed and run 'wsl -l -v'."
    }

    return @(
        $raw | ForEach-Object {
            ($_ -replace "`0", '').Trim()
        } | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
    )
}

function Resolve-WslDistro {
    param([string]$Requested)

    $distros = @(Get-WslDistroNames)
    if ($distros.Count -eq 0) {
        throw "No WSL distributions are installed. Install Ubuntu with WSL or run MinerU on native Linux."
    }

    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        if ($distros -contains $Requested) {
            return $Requested
        }
        throw "WSL distro '$Requested' was not found. Available distros: $($distros -join ', ')"
    }

    $ubuntu = @($distros | Where-Object { $_ -like 'Ubuntu*' })
    if ($ubuntu.Count -gt 0) {
        return $ubuntu[0]
    }

    return $distros[0]
}

function Get-SafeName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $invalid = [Regex]::Escape((-join [System.IO.Path]::GetInvalidFileNameChars()))
    $safe = [Regex]::Replace($Name, "[$invalid]+", '_').Trim().Trim('.')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'document'
    }
    return $safe
}

$resolvedDistro = Resolve-WslDistro -Requested $Distro
$backendOutputRoot = Join-Path $OutputRoot $Backend
New-Item -ItemType Directory -Force -Path $backendOutputRoot | Out-Null
$wslOutputRoot = ConvertTo-WslPath -WindowsPath $backendOutputRoot

$setupCommands = @()
if ($Install) {
    $setupCommands += @(
        'sudo apt update',
        'sudo apt install -y python3 python3-venv python3-pip build-essential',
        "python3 -m venv $(Quote-BashPath $VenvPath)",
        "source $(Quote-BashPath $VenvPath)/bin/activate",
        'python -m pip install --upgrade pip uv',
        'uv pip install -U "mineru[all]"'
    )
}
else {
    $setupCommands += "source $(Quote-BashPath $VenvPath)/bin/activate"
}

if (-not [string]::IsNullOrWhiteSpace($ModelSource)) {
    $setupCommands += "export MINERU_MODEL_SOURCE=$(Quote-Bash $ModelSource)"
}

foreach ($path in $InputPath) {
    $windowsInput = Normalize-WindowsPath -Path $path
    if (-not (Test-Path -LiteralPath $windowsInput -PathType Leaf)) {
        throw "Input file not found: $windowsInput"
    }

    $wslInput = ConvertTo-WslPath -WindowsPath $windowsInput
    $baseName = Get-SafeName -Name ([System.IO.Path]::GetFileNameWithoutExtension($windowsInput))
    $expectedOutput = Join-Path $backendOutputRoot $baseName

    $mineruCommand = @(
        'mineru',
        '-p', (Quote-Bash $wslInput),
        '-o', (Quote-Bash $wslOutputRoot),
        '-b', (Quote-Bash $Backend)
    ) -join ' '

    $bashCommand = ($setupCommands + $mineruCommand) -join ' && '

    Write-Host "Distro: $resolvedDistro"
    Write-Host "Input:  $windowsInput"
    Write-Host "Output root passed to -o: $backendOutputRoot"
    Write-Host "Expected per-document directory: $expectedOutput"
    Write-Host "WSL:    wsl -d $resolvedDistro -- bash -lc $(Quote-PowerShellDisplay $bashCommand)"

    if (-not $DryRun) {
        & wsl -d $resolvedDistro -- bash -lc $bashCommand
        if ($LASTEXITCODE -ne 0) {
            throw "MinerU failed for $windowsInput with exit code $LASTEXITCODE"
        }
    }
}

Write-Host "Markdown files:"
Get-ChildItem -LiteralPath $backendOutputRoot -Recurse -Filter '*.md' -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName
