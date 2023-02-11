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
    return  $MySettings.ForcePowerlinePrompt -or `
            ($null -ne $env:WT_SESSION) -and ($env:TERM_PROGRAM -ne "vscode") -and -not $MySettings.DisablePowerlinePrompt
}

#endregion

#region PATH

function Set-MacOsConfig
{
    $ASDF_BIN = "$($env:HOME)/.asdf/bin"
    $ASDF_USER_SHIMS = "$($env:HOME)/.asdf/shims"

    [System.Environment]::SetEnvironmentVariable('ASDF_BIN', $ASDF_BIN, [EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('ASDF_USER_SHIMS', $ASDF_USER_SHIMS, [EnvironmentVariableTarget]::Process)

    [System.Environment]::SetEnvironmentVariable('HOMEBREW_PREFIX','/opt/homebrew',[System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('HOMEBREW_CELLAR','/opt/homebrew/Cellar',[System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('HOMEBREW_REPOSITORY','/opt/homebrew',[System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('MANPATH',$('/opt/homebrew/share/man'+$(if(${ENV:MANPATH}){':'+${ENV:MANPATH}})+':'),[System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('INFOPATH',$('/opt/homebrew/share/info'+$(if(${ENV:INFOPATH}){':'+${ENV:INFOPATH}})),[System.EnvironmentVariableTarget]::Process)

    [System.Environment]::SetEnvironmentVariable(
        'PATH',
        "$($ASDF_BIN):$($ASDF_USER_SHIMS):" +
        "/opt/homebrew/bin:/opt/homebrew/sbin" +
        $ENV:PATH,
        [System.EnvironmentVariableTarget]::Process
    )

    $MySettings.ForcePowerlinePrompt = $env:TERM_PROGRAM -eq "iTerm.app"
    $env:OHMYPOSH_MYTHEME_PATH = "$($env:HOME)/.config/powershell"
}

#endregion

if($null -eq $MySettings)
{
    $MySettings = @{
        DisablePowerlinePrompt = $false
    }
}

if($isMacOs) { Set-MacOsConfig }

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
        if(Test-Powerline) { "$($ENV:OHMYPOSH_MYTHEME_PATH)\xadozuk.powerline.omp.json" }
        else { "$($ENV:OHMYPOSH_MYTHEME_PATH)\xadozuk.simple.omp.json" }
    }
    else
    {
        Write-Host -ForegroundColor Cyan "You can override Oh My Posh configuration by setting envinronment variable `OHMYPOSH_MYTHEME_PATH"
        "~\AppData\Local\Programs\oh-my-posh\themes\jandedobbeleer.omp.json"
    }

oh-my-posh init pwsh --config $OhMyPoshConfigFile | Invoke-Expression

# Auto load my functions
. Import-MyFunction

# Setup alias
Set-Alias -Name Watch -Value Watch-Command -Force
#Set-Alias -Name code -Value code-insiders.cmd -Force

$PSReadLineVersion = (Get-Module -Name PSReadLine).Version
$PSReadLinePredictionSource = `
        if($PSReadLineVersion -ge [Version]"2.2.0")     { "HistoryAndPlugin" }
        elseif($PSReadLineVersion -ge [Version]"2.2.0") { "History" }
        else                                            { "None" }

Set-PSReadLineOption -PredictionSource $PSReadLinePredictionSource -PredictionViewStyle ListView -EditMode Windows

# PSReadline binding
Set-PSReadLineKeyHandler -Key "Ctrl+f" -Function ForwardWord

if(Test-Powerline) { Set-PSReadLineOption -PromptText "$([char]::ConvertFromUtf32(0x276F)) " }
else { Set-PSReadLineOption -PromptText "> " }
