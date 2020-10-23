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

function Get-CurrentAzContext
{
    if(-not (Test-Path -Path "~\.azure\AzureRmContext.json")) { return $null }

    $Az = Get-Content -Path "~\.azure\AzureRmContext.json" | ConvertFrom-Json 
    return $Az.Contexts.($Az.DefaultContextKey)
}

function Get-CurrentKubernetesContext
{
    if($null -eq (Get-Command -Name kubectl)) { return $null }

    return &"kubectl" config current-context
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
        Separator       = [Text.Encoding]::UTF8.GetString(@(0xee, 0x82, 0xb0))
        Azure           = [char]::ConvertFromUtf32(0xfd03)
        Docker          = [char]::ConvertFromUtf32(0xf308)
        Folder          = [char]::ConvertFromUtf32(0xf07b)
        GitBranch       = [char]::ConvertFromUtf32(0xe725)
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
        GitStatusFG     = "Black"
        GitStatusBG     = "Cyan"
        AzContextFG     = "White"
        AzContextBG     = "DarkBlue"
        K8sContextFG    = "White"
        K8sContextBG    = "DarkYellow"
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

function _Write-PowerlinePrompt
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Segments
    )

    for($i = 0; $i -lt $Segments.Count; $i++)
    {
        $NextBGColor = if($i + 1 -eq $Segments.Count -or $Segments[$i + 1].NewLine) { $MyTheme.Colors.DefaultBG }
                       else { $Segments[$i + 1].BackgroundColor }

        Write-Prompt -Object $Segments[$i].Object -ForegroundColor $Segments[$i].ForegroundColor -BackgroundColor $Segments[$i].BackgroundColor -NewLine:$Segments[$i].NewLine

        if(-not $Segments[$i].NoSeparator)
        {
            Write-Prompt -Separator -BackgroundColor $NextBGColor -ForegroundColor $Segments[$i].BackgroundColor
        }
    }

    Write-Host "`n$($s.PromptIndicator * ($nestedPromptLevel + 1))" -NoNewLine
    return " "
}

function Write-PowerlinePrompt
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $FailedCommand
    )

    $Host.UI.RawUI.WindowTitle = "PowerShell"
    $CurrentPath = $ExecutionContext.SessionState.Path.CurrentLocation.ProviderPath

    $Segments = [System.Collections.ArrayList]::new()

    $s = $MyTheme.Symbols
    $c = $MyTheme.Colors

    if($FailedCommand)
    {
        [void] $Segments.Add(@{
            Object          = $s.FailedCommand
            ForegroundColor = $c.FailedCommandFG
            BackgroundColor = $c.FailedCommandBG
        })

        #Write-Prompt -Object $s.FailedCommand -ForegroundColor $c.FailedCommandFG -BackgroundColor $c.FailedCommandBG
        #Write-Prompt -Separator -BackgroundColor $c.CommandTimeBG -ForegroundColor $c.FailedCommandBG
    }    

    # Last command run time
    $LastCommandTime = Get-CommandExecutionTime -Last
    if($LastCommandTime)
    {
        [void] $Segments.Add(@{
            Object = (ConvertTo-HumanInterval -Interval $LastCommandTime)
            ForegroundColor = $c.CommandTimeFG
            BackgroundColor = $c.CommandTimeBG
        })
    }

    # Azure subscription
    $CurrentAzContext = Get-CurrentAzContext
    if($CurrentAzContext)
    {
        #Write-Prompt $CurrentAzContext.Subscription.Name -ForegroundColor $c.AzContextFG -BackgroundColor $c.CommandTimeBG
        #Write-Prompt -Separator -ForegroundColor $c.CommandTimeBG -BackgroundColor $c.CurrentPathBG
        [void] $Segments.Add(@{
            Object = $s.Azure + " " + $CurrentAzContext.Subscription.Name
            ForegroundColor = $c.AzContextFG
            BackgroundColor = $c.AzContextBG
        })
    }

    # K8s context
    $CurrentK8sContext = Get-CurrentKubernetesContext
    if($CurrentK8sContext)
    {
        [void] $Segments.Add(@{
            Object = $s.Docker + " " + $CurrentK8sContext
            ForegroundColor = $c.K8sContextFG
            BackgroundColor = $c.K8sContextBG
        })
    }

    # Git
    if(Test-GitRepository -Path $CurrentPath)
    {
        [void] $Segments.Add(@{
            Object = $s.GitBranch + " "+ (Get-GitStatus).Branch
            ForegroundColor = $c.GitStatusFG
            BackgroundColor = $c.GitStatusBG
        })
    }

    # Current path
    $ShortPath = Get-ShortPath -Path $CurrentPath
    
    [void] $Segments.Add(@{
        Object = $s.Folder + " " + $ShortPath
        ForegroundColor = $c.CurrentPathFG
        BackgroundColor = $c.CurrentPathBG
        NewLine         = $true
        NoSeparator     = $true
    })

    return _Write-PowerlinePrompt -Segments $Segments
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
    # Install module in user scope by default (no need for admin prompt)
    "Install-Module:Scope"      = "CurrentUser"

    # Capture last command in the $__ var
    "Out-Default:OutVariable"   = "__"
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
