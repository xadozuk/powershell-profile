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
    return ($null -ne $env:WT_SESSION) -and ($env:TERM_PROGRAM -ne "vscode") -and -not $MySettings.DisablePowerlinePrompt
}

#endregion

if($null -eq $MySettings)
{
    $MySettings = @{
        DisablePowerlinePrompt = $false
    }
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
$PredictionSource = `
    switch($PSReadLineOption)
    {
        { $_ -ge [Version]"2.2.0" } { "HistoryAndPlugin" }
        { $_ -ge [Version]"2.1.0" } { "History" }
        default { "None" }
    }

# PSReadline binding
Set-PSReadLineKeyHandler -Key "Ctrl+f" -Function ForwardWord

if(Test-Powerline) { Set-PSReadLineOption -PromptText "$([char]::ConvertFromUtf32(0x276F)) " }
else { Set-PSReadLineOption -PromptText "> " }
