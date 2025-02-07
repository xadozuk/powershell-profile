#region Helpers functions

function Reset-Profile
{
    . $Profile.CurrentUserAllHosts
}

function Import-MyFunction
{
    if($null -ne $env:PSMYHOME -and (Test-Path -Path $env:PSMYHOME -PathType Container))
    {
        $Files = Get-ChildItem -Path $env:PSMYHOME -Filter "*.ps1" -Recurse -File

        $Files | ForEach-Object { . $_.FullName }
    }
    else
    {
        Write-Host -ForegroundColor Cyan "You can customize the auto-load folder by setting `$env:PSMYHOME"
    }
}

function Test-Powerline
{
    return -not $MySettings.DisablePowerlinePrompt -and $env:TERM_PROGRAM -ne "vscode" -and (
        ($null -ne $env:WT_SESSION) -or     # Inside Windows terminal
        # Inside a compatible *nix terminal
        ($env:TERM -in @("xterm-256color", "tmux-256color", "xterm-ghostty"))
    )
}

#endregion

#region PATH

function Get-MacOsConfig
{
    return @{
        Paths = @(
            "$($HOME)/.local/share/mise/shims"
            "$($HOME)/.cargo/bin"
            "/opt/homebrew/bin"
            "/opt/homebrew/sbin"
            "/usr/local/bin"
        )
        EnvironmentVariables = @{
            HOMEBREW_PREFIX     = "/opt/homebrew"
            HOMEBREW_CELLAR     = "/opt/homebrew/Cellar"
            HOMEBREW_REPOSITORY = "/opt/homebrew"
            LIBRARY_PATH        = "$env:LIBRARY_PATH:/opt/homebrew/lib"
            MANPATH             = @("/opt/homebrew/share/man", $ENV:MANPATH) -join [IO.Path]::PathSeparator
            INFOPATH            = @("/opt/homebrew/share/INFO", $ENV:INFOPATH) -join [IO.Path]::PathSeparator
        }
    }
}

function Get-LinuxConfig
{
    return @{
        Paths = @(
            "$($HOME)/.local/share/mise/shims"
            "$($HOME)/.local/bin"
            "$($HOME)/.cargo/bin"
        )
        EnvironmentVariables = @{}
    }
}

function Set-NonWindowsOsConfig
{
    $Config = if($IsMacOs)
    {
        Get-MacOsConfig
    }
    elseif($IsLinux)
    {
        Get-LinuxConfig
    }

    $PrependPath = @(
        "$($env:HOME)/.terramorph/shims",
        "$($env:HOME)/.local/share/bob/nvim-bin"
    )

    $CurrentPath = $env:PATH -split [IO.Path]::PathSeparator

    [System.Environment]::SetEnvironmentVariable(
        'PATH',
        ($PrependPath + $Config.Paths + $CurrentPath | Select-Object -Unique) -join [IO.Path]::PathSeparator,
        [System.EnvironmentVariableTarget]::Process
    )

    $Config.EnvironmentVariables.GetEnumerator() | Foreach-Object {
        [System.Environment]::SetEnvironmentVariable($_.Key, $_.Value, [EnvironmentVariableTarget]::Process)
    }

    $env:OHMYPOSH_MYTHEME_PATH = "$($HOME)/development/my/powershell-profile"
    $env:PSMYHOME = "$($HOME)/development/my/powershell-gallery"
    $env:EDITOR = "nvim"
}

function Set-PSReadLineConfig
{
    Import-Module PSReadLine
    Import-Module PSFzf

    $PSReadLineVersion = (Get-Module -Name PSReadLine).Version
    $PSReadLinePredictionSource = `
        if($PSReadLineVersion -ge [Version]"2.2.0")
    {
        "HistoryAndPlugin"
    }
    elseif($PSReadLineVersion -ge [Version]"2.2.0")
    {
        "History"
    }
    else
    {
        "None"
    }

    # PSReadLine Predictors
    if($PSReadLinePredictionSource -eq "HistoryAndPlugin")
    {
        Import-Module CompletionPredictor
        Import-Module Az.Tools.Predictor
    }

    Set-PSReadLineOption -PredictionSource $PSReadLinePredictionSource -PredictionViewStyle ListView -EditMode Windows

    # Remove PSFzf binding
    # Remove-PSReadLineKeyHandler -Chord "Ctrl+r"
    # Remove-PSReadLineKeyHandler -Chord "Alt+c"

    # Remove binding for Linux compatibility (inside TMUX)
    Set-PSReadLineKeyHandler -Chord "Ctrl+Enter" -Function AcceptLine

    # PSReadline binding
    Set-PSReadLineKeyHandler -Chord "Ctrl+f" -Function ForwardWord

    # Set-PSReadLineKeyHandler -Chord "Ctrl+r" -Function ReverseSearchHistory
    Set-PsFzfOption -PSReadlineChordReverseHistory "Ctrl+r" -PSReadlineChordSetLocation "Ctrl-g"

    Set-PSReadLineKeyHandler -Chord "Tab" -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord "Ctrl+t" -ScriptBlock { Open-TmuxSession }

    if(Test-Powerline)
    {
        Set-PSReadLineOption -PromptText "$([char]::ConvertFromUtf32(0x276F)) "
    }
    else
    {
        Set-PSReadLineOption -PromptText "> "
    }
}

#endregion

if($null -eq $MySettings)
{
    $MySettings = @{
        DisablePowerlinePrompt = $false
    }
}

if(-not $IsWindows)
{
    Set-NonWindowsOsConfig
}

$PSDefaultParameterValues = @{
    # Install module in user scope by default (no need for admin prompt)
    "Install-Module:Scope"      = "CurrentUser"

    # Capture last command in the $__ var
    "Out-Default:OutVariable"   = "__"
}

# Prompt
$OhMyPoshConfigFile =
if($null -ne $ENV:OHMYPOSH_MYTHEME_PATH)
{
    if(Test-Powerline)
    {
        "$($ENV:OHMYPOSH_MYTHEME_PATH)/xadozuk.powerline.omp.json"
    }
    else
    {
        "$($ENV:OHMYPOSH_MYTHEME_PATH)/xadozuk.simple.omp.json"
    }
}
else
{
    Write-Host -ForegroundColor Cyan "You can override Oh My Posh configuration by setting envinronment variable `OHMYPOSH_MYTHEME_PATH"
    ""
}

oh-my-posh init pwsh --config $OhMyPoshConfigFile | Invoke-Expression

if($null -ne (Get-Module Az -ListAvailable))
{
    $env:POSH_AZURE_ENABLED = $true
}

if($null -ne (Get-Command zoxide -ErrorAction SilentlyContinue))
{
    Invoke-Expression (& { zoxide init powershell | Out-String })
    Set-Alias -Name cd -Value z -Option AllScope -Scope Global
}

if(Test-Path -PathType Leaf -Path "~/.tmux/plugins/tmux-session-wizard/bin/t")
{
    Set-Alias -Name t -Value "~/.tmux/plugins/tmux-session-wizard/bin/t"
}

# Auto load my functions
. Import-MyFunction

# Setup alias
Set-Alias -Name Watch -Value Watch-Command -Force
#Set-Alias -Name code -Value code-insiders.cmd -Force
Set-Alias -Name podman -Value podman-remote -Force

# Detect when we are not in a interactive session (pwsh spawned by another process, usually as shell for executing vs extension, nvim command, etc...)
# Import-Module predictors cause the shell to hang in this case
if(-not [Console]::IsOutputRedirected)
{
    Set-PSReadLineConfig
}

# Activate Mise
if($null -ne (Get-Command -Name mise -ErrorAction SilentlyContinue) -and -not $env:MISE_ACTIVATED)
{
    mise activate pwsh | Out-String | Invoke-Expression
    $env:MISE_ACTIVATED = $true
}

