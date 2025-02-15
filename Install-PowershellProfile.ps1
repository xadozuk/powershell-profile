#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter()]
    [string] $CheckoutPath = "$($HOME)/development/my",

    [Parameter()]
    [string] $GalleryFolderName = "powershell-gallery",

    [Parameter()]
    [string] $GalleryRepository = "https://github.com/xadozuk/powershell-gallery.git",

    [Parameter()]
    [string] $ProcessorArchitecture = "amd64",

    [Parameter()]
    [switch] $ForceInstallOhMyPosh
)

# Checkout powershell-gallery
$CurrentLocation = Get-Location

Write-Verbose "Cloning powershell gallery repository..."
$CheckoutPath | Push-Location | Out-Null
&git clone $GalleryRepository $GalleryFolderName | Out-Null

Write-Verbose "Linking powershell profile..."

$ProfilePath = Split-Path -Path $PROFILE.CurrentUserAllHosts -Parent

# On Windows, require Run-as Admin
New-Item -Path "$ProfilePath/profile.ps1" -ItemType SymbolicLink -Target "$PSScriptRoot/profile.ps1" -Force | Out-Null

# Install oh-my-posh
if($null -eq (Get-Command "oh-my-posh" -ErrorAction SilentlyContinue) -or $ForceInstallOhMyPosh)
{
    Write-Verbose "Installing oh-my-posh"

    if($IsWindows)
    {
        winget install JanDeDobbeleer.OhMyPosh -s winget
    }
    elseif($IsMacOS)
    {
        brew install jandedobbeleer/oh-my-posh/oh-my-posh
    }
    elseif($IsLinux)
    {
        sudo wget "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-$ProcessorArchitecture" -O "/usr/local/bin/oh-my-posh"
        sudo chmod +x /usr/local/bin/oh-my-posh
    }
}

# Required modules
Install-Module -Name CompletionPredictor -Scope CurrentUser -Force
Install-Module -Name Az.Tools.Predictor -Scope CurrentUser -Force

# Utility module
Install-Module -Name PSFzf -Scope CurrentUser -Force

$CurrentLocation | Push-Location

. $PROFILE.CurrentUserAllHosts
