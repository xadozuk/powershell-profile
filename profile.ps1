$PSDefaultParameterValues = @{
    "Install-Module:Scope" = "CurrentUser"
}

function Reset-Profile
{
    . $Profile.CurrentUserAllHosts
}

function Test-GitRepository
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $Path
    )

    if(-not $Path) { return $false }

    if(Test-Path -Path (Join-Path -Path $Path -ChildPath '.git') -PathType Container)
    {
        return $true
    }

    return Test-GitRepository -Path (Split-Path $Path)
}

function Get-GitStatus
{
    param(
        [Parameter()]
        [switch] $Detailed
    )

    $Object = @{
        Branch = ""
        Detached = $false
    }

    $Object.Branch = &"git.exe" "rev-parse" "--abbrev-ref" "HEAD"

    # Detached mode
    if($Object.Branch -eq "HEAD")
    {
        $Object.Branch = &"git.exe" "rev-parse" "--short" "HEAD"
        $Object.Detached = $true
    }

    if($Detailed)
    {
        $Status = &"git.exe" "-c" "core.quotepath=false" "-c" "color.status=false" "status" "-uno" "--short" "--branch" | Select-Object -First 1

        if($Status -match '^## (?<branch>\S+?)(?:\.\.\.(?<upstream>\S+))?(?: \[(?:ahead (?<ahead>\d+))?(?:, )?(?:behind (?<behind>\d+))?(?<gone>gone)?\])?$')
        {
            $Object.AheadBy = [int] $matches['ahead']
            $Object.BehindBy = [int] $matches['behind']
        }
    }

    [PSCustomObject] $Object
}

function Write-GitStatus
{
    $Status = Get-GitStatus

    Write-Host $Status.Branch -NoNewline -ForegroundColor "Blue"
}

function Get-CommandExecutionTime
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName="ByCommand")]
        [Microsoft.PowerShell.Commands.HistoryInfo] $Command,

        [Parameter(Mandatory, ParameterSetName="Last")]
        [switch] $Last
    )

    if($Last)
    {
        $History = Get-History

        if($History.Count -eq 0) { return $null }

        $Command = (Get-History)[-1]
    }

    return $Command.Duration
}

function ConvertTo-HumanInterval
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [TimeSpan] $Interval
    )

    if($Interval.TotalMilliseconds -lt 1000)
    {
        return "{0:n0}ms" -f $Interval.TotalMilliseconds
    }
    elseif ($Interval.TotalSeconds -lt 60)
    {
        return "{0:n0}s" -f $Interval.TotalSeconds
    }
    elseif ($Interval.TotalMinutes -lt 60)
    {
        return "{0:n0}min {1:n0}s" -f $Interval.TotalMinutes, $Interval.Seconds
    }
    else
    {
        return "{0:n0}h {1:n0}min {2:n0}s" -f $Interval.TotalHours, $Interval.Minutes, $Interval.Seconds
    }
}

function Prompt
{
    if(-not $?)
    {
        Write-Host -ForegroundColor Red "! " -NoNewline
    }

    $Host.UI.RawUI.WindowTitle = "PowerShell"   

    # Last command run time
    $LastCommandTime = Get-CommandExecutionTime -Last
    
    if($LastCommandTime)
    {
        Write-Host "[" -NoNewline
        Write-Host -NoNewline -ForegroundColor "Green" (ConvertTo-HumanInterval -Interval $LastCommandTime)
        Write-Host "] " -NoNewline
    }

    # Current path
    $CurrentPath = $ExecutionContext.SessionState.Path.CurrentLocation.ProviderPath

    <#
    if($CurrentPath -like "$HOME*")
    {
        Write-Host '~' -NoNewline -ForegroundColor Yellow
        $CurrentPath = $CurrentPath.Replace("$HOME", '')
    }
    #>

    Write-Host $CurrentPath -NoNewline -ForegroundColor DarkGray

    # Git
    if(Test-GitRepository -Path $CurrentPath)
    {
        Write-Host " [" -NoNewline
        Write-GitStatus
        Write-Host "]" -NoNewline
    }

    Write-Host "`n$('>' * ($nestedPromptLevel + 1))" -NoNewline
    return " "
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

# Auto load my functions
. Import-MyFunction

# Setup alias
Set-Alias -Name Watch -Value Watch-Command -Force

# PSReadline binding
Set-PSReadLineKeyHandler -Key "Ctrl+f" -Function ForwardWord
