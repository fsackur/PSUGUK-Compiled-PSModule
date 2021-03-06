
<#
    This will load Posh-Git and temporarily update your prompt.

#>


param([switch]$Reverse)


#This isn't really intended for running at the console
if ($Host.Name -notlike "*ISE*") {
    ise .\StepThrough-CommitHistory.ps1
    Write-Host -ForegroundColor Yellow "switching to ISE - press F5 to step forward through history, Ctrl-F5 to step backward"
}


#Try to import git and set it up
try {
    Import-Module Posh-Git -ErrorAction Stop

} catch {
    try {
        if ((Read-Host "Attempt to install chocolatey, git and posh-git (y/n)") -notlike "y") {return}

        Install-Package Posh-Git -ForceBootstrap -Force
        iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
        choco install git -y

    } catch {
        Write-Host -ForegroundColor Yellow "I tried to install some stuff but failed."
        return
    }
}

#Set the git prompt
if (!$GitPromptSettings.DefaultPromptSuffix) {
    $GitPromptSettings | Add-Member NoteProperty -Name 'DefaultPromptSuffix' -Value '`n$(''>'' * ($nestedPromptLevel + 1)) '
    function global:prompt {
        $realLASTEXITCODE = $LASTEXITCODE
        Write-Host($pwd.ProviderPath) -nonewline
        Write-VcsStatus
        $global:LASTEXITCODE = $realLASTEXITCODE
        return "`n> "
    }
}

$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Clear()

#F5 will already step forwards; add an ISE shortcut to step back
try {
    [void]$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add(
        "Step back through commit history",
        [scriptblock]::Create("$PSScriptRoot\StepThrough-CommitHistory.ps1 -Reverse"),
        "Alt+Shift+F5"
    )
} catch [System.Management.Automation.MethodInvocationException] {
    if ($_ -notmatch "already in use by the menu or editor functionality") {
        throw $_
    }
}



#if ($Reverse) {Write-Output "Jiminy crickets!"}
Set-Location $PSScriptRoot
$ReflogText = git reflog

$HeadHash = $ReflogText[0] -replace ' .*'

$CommitComments = @{}
$ReflogText | %{
    $tokens = $_.Split(' ', 4)
    $Commits.($tokens[0]) = $tokens[3]
}

$CommitHashes = New-Object 'System.Collections.Generic.List[string]'($ReflogText.Count)
$ReflogText | %{$CommitHashes.Add($_ -replace ' .*')}
$CommitHashes.Reverse()
#Get rid of duplicates from resets, checkouts etc
[string[]]$templist = $CommitHashes | select -Unique
$CommitHashes = New-Object 'System.Collections.Generic.List[string]'($CommitHashes.Count)
$CommitHashes.AddRange($templist)
$CommitHashes.Reverse()
$ReflogText
$CommitHashes
