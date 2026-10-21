[CmdletBinding()]
param(
    [ValidateSet('Play', 'Editor', 'FindGodot')]
    [string]$Mode = 'Play',
    [switch]$ResolveOnly
)

$ErrorActionPreference = 'Stop'
$projectDirectory = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))

function Find-GodotExecutable {
    $candidates = [Collections.Generic.List[string]]::new()
    if ($env:GODOT_EXE) {
        $candidates.Add($env:GODOT_EXE)
    }
    $desktopGodot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot'
    $workspaceTools = Join-Path (Split-Path -Parent $projectDirectory) 'tools\godot-4.7.1'
    foreach ($directory in @($desktopGodot, $workspaceTools)) {
        foreach ($name in @('Godot_v4.7.1-stable_win64.exe', 'Godot_v4.7.1-stable_win64_console.exe')) {
            $candidates.Add((Join-Path $directory $name))
        }
    }
    foreach ($name in @('godot', 'godot4', 'godot.exe', 'godot4.exe')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $candidates.Add($command.Source) }
    }
    foreach ($directory in @($desktopGodot, $workspaceTools)) {
        if (Test-Path -LiteralPath $directory -PathType Container) {
            foreach ($file in (Get-ChildItem -LiteralPath $directory -Filter 'Godot*.exe' -File | Sort-Object Name)) {
                $candidates.Add($file.FullName)
            }
        }
    }
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $resolved = (Resolve-Path -LiteralPath $candidate).Path
        # Prefer the GUI sibling so no console accompanies the editor or game.
        if ($resolved.EndsWith('_console.exe', [StringComparison]::OrdinalIgnoreCase)) {
            $guiSibling = $resolved.Substring(0, $resolved.Length - '_console.exe'.Length) + '.exe'
            if (Test-Path -LiteralPath $guiSibling -PathType Leaf) { return $guiSibling }
        }
        return $resolved
    }
    throw 'Godot was not found. Install Godot 4.7.1 or set the GODOT_EXE environment variable to its executable.'
}

try {
    if ($Mode -eq 'FindGodot') {
        Find-GodotExecutable
        exit 0
    }
    $releaseExecutable = Join-Path $projectDirectory 'build\Symbiont.exe'
    if ($Mode -eq 'Play' -and (Test-Path -LiteralPath $releaseExecutable -PathType Leaf)) {
        $launchExecutable = $releaseExecutable
        $launchArguments = ''
    } else {
        $launchExecutable = Find-GodotExecutable
        $launchArguments = '--path "' + $projectDirectory + '"'
        if ($Mode -eq 'Editor') { $launchArguments += ' --editor res://scenes/hub.tscn' }
    }
    if ($ResolveOnly) {
        [pscustomobject]@{
            Mode = $Mode
            Executable = $launchExecutable
            Arguments = $launchArguments
            WorkingDirectory = $projectDirectory
        } | ConvertTo-Json
        exit 0
    }
    # CreateNoWindow suppresses helper consoles; the interactive Godot window
    # remains visible. No background shell or persistent helper is required.
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $launchExecutable
    $startInfo.Arguments = $launchArguments
    $startInfo.WorkingDirectory = $projectDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    [Diagnostics.Process]::Start($startInfo) | Out-Null
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
