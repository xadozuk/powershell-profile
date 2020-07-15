#region Helpers functions

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
    
    return $Command.EndExecutionTime - $Command.StartExecutionTime
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

function Get-ShortPath
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string] $Path
    )

    if($Path -like "$HOME*")
    {
        "~" + $Path.Replace($HOME, '')
    }
    else
    {
        $Path
    }
}

function Test-Powerline
{
    return ($null -ne $env:WT_SESSION) -and ($env:TERM_PROGRAM -ne "vscode")
}

#endregion

#region Custom prompt

$MyTheme = @{
    Symbols = @{
        PromptIndicator = '❯'
        FailedCommand   = '⨯'
        Separator       =  [Text.Encoding]::UTF8.GetString(@(0xee, 0x82, 0xb0))
    }
    
    Colors = @{
        DefaultFG = "White"
        DefaultBG = "Black"
        CurrentPathFG  = "DarkGray"
        CurrentPathBG  = "Black"
        CommandTimeFG  = "White"
        CommandTimeBG  = "DarkGreen"
        FailedCommandFG = "White"
        FailedCommandBG = "Red"
        GitStatusFG     = "White"
        GitStatusBG     = "DarkBlue"
    }

    Options = @{
        Padding = 1
    }
}

function Write-Prompt
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [object] $Object = "",

        [Parameter()]
        [string] $ForegroundColor = "White",

        [Parameter()]
        [string] $BackgroundColor = "Black",

        [Parameter()]
        [switch] $NewLine,

        [Parameter()]
        [switch] $Separator
    )

    if($NewLine) { Write-Host "" }

    $Object = if($Separator)
    { 
        $MyTheme.Symbols.Separator
    }
    else
    { 
        $Format = if($NewLine) { "{1}{0}" } else { "{0}{1}{0}" }
        $Format -f (" " * $MyTheme.Options.Padding), $Object
    }

    Write-Host `
        -Object $Object `
        -ForegroundColor $ForegroundColor `
        -BackgroundColor $BackgroundColor `
        -NoNewline
}

function Write-PowerlinePrompt
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $FailedCommand
    )

    $s = $MyTheme.Symbols
    $c = $MyTheme.Colors

    if($FailedCommand)
    {
        Write-Prompt -Object $s.FailedCommand -ForegroundColor $c.FailedCommandFG -BackgroundColor $c.FailedCommandBG
        Write-Prompt -Separator -BackgroundColor $c.CommandTimeBG -ForegroundColor $c.FailedCommandBG
    }

    $Host.UI.RawUI.WindowTitle = "PowerShell"

    # Last command run time
    $LastCommandTime = Get-CommandExecutionTime -Last
    
    if($LastCommandTime)
    {
        Write-Prompt (ConvertTo-HumanInterval -Interval $LastCommandTime) -ForegroundColor $c.CommandTimeFG -BackgroundColor $c.CommandTimeBG
        Write-Prompt -Separator -ForegroundColor $c.CommandTimeBG -BackgroundColor $c.CurrentPathBG
    }

    # Current path
    $CurrentPath = $ExecutionContext.SessionState.Path.CurrentLocation.ProviderPath

    $ShortPath = Get-ShortPath -Path $CurrentPath
    Write-Prompt $ShortPath -ForegroundColor $c.CurrentPathFG -BackgroundColor $c.CurrentPathBG

    # Git
    if(Test-GitRepository -Path $CurrentPath)
    {
        Write-Prompt -Separator -ForegroundColor $c.CurrentPathBG -BackgroundColor $c.GitStatusBG
        Write-Prompt (Get-GitStatus).Branch -ForegroundColor $c.GitStatusFG -BackgroundColor $c.GitStatusBG
        Write-Prompt -Separator -ForegroundColor $c.GitStatusBG -BackgroundColor $c.DefaultBG
    }

    Write-Host "`n$($s.PromptIndicator * ($nestedPromptLevel + 1))" -NoNewLine
    return " "
}

function Write-ClassicPrompt
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $FailedCommand
    )

    if($FailedCommand)
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

    $ShortPath = Get-ShortPath -Path $CurrentPath
    Write-Host $ShortPath -NoNewline -ForegroundColor DarkGray

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

function Prompt
{
    $FailedCommand = -not $?

    # if in Windows Terminal
    if(Test-Powerline)
    {
        Write-PowerlinePrompt -FailedCommand $FailedCommand
    }
    else
    {
        Write-ClassicPrompt -FailedCommand $FailedCommand
    }
}

#endregion

$PSDefaultParameterValues = @{
    "Install-Module:Scope" = "CurrentUser"
}

# Auto load my functions
. Import-MyFunction

# Setup alias
Set-Alias -Name Watch -Value Watch-Command -Force

if((Get-Module -Name PSReadLine).Version -ge [Version]"2.1.0")
{
    # PSReadline options
    Set-PSReadLineOption -PredictionSource History   
}

# PSReadline binding
Set-PSReadLineKeyHandler -Key "Ctrl+f" -Function ForwardWord

if(Test-Powerline) { Set-PSReadLineOption -PromptText "❯ " }
else { Set-PSReadLineOption -PromptText "> " }
