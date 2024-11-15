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
        ($env:TERM -eq "xterm-256color" -or $env:TERM -eq "tmux-256color")    # Inside a compatible *nix terminal

    )
}

#endregion

#region PATH

function Get-MacOsConfig
{
    return @{
        Paths = @(
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "$($HOME)/.cargo/bin"
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
            "$($HOME)/.local/bin",
            "$($HOME)/.cargo/bin"
        )
        EnvironmentVariables = @{}
    }
}

function Set-NonWindowsOsConfig
{
    $Config = if($isMacOs)
    { 
        Get-MacOsConfig 
    }
    elseif($isLinux)
    {
        Get-LinuxConfig 
    }

    $ASDF_BIN = "$($env:HOME)/.asdf/bin"
    $ASDF_USER_SHIMS = "$($env:HOME)/.asdf/shims"
    $TERRAMORPH_SHIMS = "$($env:HOME)/.terramorph/shims"

    $PrependPath = @($ASDF_BIN, $ASDF_USER_SHIMS, $TERRAMORPH_SHIMS) + $Config.Paths

    [System.Environment]::SetEnvironmentVariable(
        'PATH',
        $PrependPath + @($ENV:PATH) -join [IO.Path]::PathSeparator,
        [System.EnvironmentVariableTarget]::Process
    )

    $Config.EnvironmentVariables.GetEnumerator() | Foreach-Object {
        [System.Environment]::SetEnvironmentVariable($_.Key, $_.Value, [EnvironmentVariableTarget]::Process)
    }

    $env:OHMYPOSH_MYTHEME_PATH = "$($HOME)/development/my/powershell-profile"
    $env:PSMYHOME = "$($HOME)/development/my/powershell-gallery"
    $env:EDITOR = "nvim"
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

# Auto load my functions
. Import-MyFunction

# Setup alias
Set-Alias -Name Watch -Value Watch-Command -Force
#Set-Alias -Name code -Value code-insiders.cmd -Force
Set-Alias -Name podman -Value podman-remote -Force

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
Remove-PSReadLineKeyHandler -Chord "Ctrl+r"
Remove-PSReadLineKeyHandler -Chord "Alt+c"

# Remove binding for Linux compatibility (inside TMUX)
Set-PSReadLineKeyHandler -Chord "Ctrl+Enter" -Function AcceptLine

# PSReadline binding
Set-PSReadLineKeyHandler -Chord "Ctrl+f" -Function ForwardWord
Set-PSReadLineKeyHandler -Chord "Ctrl+t" -ScriptBlock { Open-TmuxSession }

if(Test-Powerline)
{ 
    Set-PSReadLineOption -PromptText "$([char]::ConvertFromUtf32(0x276F)) " 
}
else
{
    Set-PSReadLineOption -PromptText "> " 
}
