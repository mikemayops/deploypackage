
Function Copy-WithProgress {
    [CmdletBinding()]
    Param (

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        $Source,
        
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        $Destination

    )

    $Source=$Source.tolower()
    $Filelist=Get-Childitem $Source -Recurse
    $Total=$Filelist.count
    $Position=0

    foreach ($File in $Filelist){

        $Filename=$File.Fullname.tolower().replace($Source,'')
        $DestinationFile=($Destination+$Filename)
        Write-Progress -Activity "Copying data from $source to $Destination" -Status "Copying File $Filename" -PercentComplete (($Position/$total)*100) 
        Copy-Item $File.FullName -Destination $DestinationFile
        $Position++

    }

    Write-Progress -Activity "Copying data from $source to $Destination" -Status "Finished" -Completed

}
Function Monitor-Jobs {
    [CmdletBinding()]
    param(
        [string]$jobName
    )

    $JobsLaunch = Get-Date
    do {
    Clear-Host
    
    $myjobs = get-job -Name $JobName -IncludeChildJob
    $myjobs | Out-File "$env:TEMP\scrapjobs.txt"
    Get-Content "$env:TEMP\scrapjobs.txt"
    $jobscount = $myjobs.Count
    Write-Host "$jobscount installations running" -ForegroundColor DarkYellow
    
    $done = 0
    
    foreach ($job in $myjobs) {
    
        $mystate = $job.State
        if ($mystate -eq "Completed") {$done = $done + 1}
        elseif ($mystate -eq "Failed") {$done = $done + 1}
    
    }
    Write-Host "$done installations done" -ForegroundColor Green


    $currentTime = Get-Date
    Write-Host "Jobs started at $JobsLaunch" -ForegroundColor Blue
    Write-Host "Current time $currentTime" -ForegroundColor Blue
    
    $timecount = $currentTime - $JobsLaunch
    
    Write-Host "Elapsed time - $($timecount.Minutes):$($timecount.Seconds)" -ForegroundColor Green
    Start-Sleep 1

    if ( $done -lt $jobscount ) {Clear-Host}

    } while ( $done -lt $jobscount )
    
    $FailedJobs = Get-Job -State "Failed" | Format-List *
    Write-Output "[$($env:USERNAME)]: $(get-date) - All jobs finished. Find job details here:`n $(Out-String -InputObject $FailedJobs)"  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
    Get-Job | Remove-job
}
Function Deploy-Package {
    [CmdletBinding()]
    
    Param (
        
        [ValidateNotNull()]
        [System.Management.Automation.Credential()]
        [PScredential]
        $Credential,

        [ValidateNotNull()]
        [string[]]$ComputerName,
        
        # Specifies a path to the source of the package.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="ParameterSetName",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Specifies a path to the source of the package.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string]
        $SourcePath,
        [string[]]$Command,
        [string]$JobName = "Deploy-Package"

    )
    
    $SourceDirx64 = "$SourcePath\x64"
    $SourceDirx86 = "$SourcePath\x86"

    $TstStructure = Test-Path $SourceDirx64,$SourceDirx86

    if ($TstStructure -eq $false) {

        Write-Output "[$($env:USERNAME)]: $(get-date) - Error: Wrong Source Folder Sturcture. Exiting script." | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
        Write-Verbose -Message "[$($env:USERNAME)]: $(get-date) - Error: Wrong Source Folder Sturcture. Exiting script."
        exit

    }

    $LogDir = "$SourcePath\Logs"
    $Logdirtst = Test-Path -Path "$LogDir"
    if ($Logdirtst -eq $false) { New-Item -ItemType Directory -Path "$LogDir" | Out-Null }
    
    Write-Output "[$($env:USERNAME)]: $(get-date) - Deployment Started from: $env:COMPUTERNAME" | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
    Write-Output "[$($env:USERNAME)]: $(get-date) - Source Used: $SourcePath" | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force

    # --------------------------------------------- Create Computer Class and Test Connectivity ---------------------------------------------------------- #

    class Computer {
        [string]$Name
        [string]$Active
        [string]$Architecture
    }

    $Computers = @()

    foreach ($pc in $ComputerName) {
        
        $ComputerObj = New-Object -TypeName Computer
        $ComputerObj.Name = $pc

        $Active = Test-Connection -ComputerName $pc -Quiet -Count 1
        $ComputerObj.Active = $Active

        if ($Active -eq $true) {

            try {
                $Arch = get-wmiobject win32_operatingsystem -computer $ps -Credential $Credential -ErrorAction SilentlyContinue | select-object -ExpandProperty OSArchitecture
            }
            catch {
                $Arch = Invoke-Command -ComputerName $pc -Credential $Credential -ScriptBlock {$env:PROCESSOR_ARCHITECTURE} -ErrorAction SilentlyContinue
            }

        }
        else {$Arch = $null}
        
        $ComputerObj.Architecture = $Arch
        
        $Computers += $ComputerObj

    }


    Write-Output "[$($env:USERNAME)]: $(get-date) - Computer Status: $(Out-String -InputObject $Computers)" | Out-File -FilePath "$LogDir\0_ComputerStatus.log" -Append -Force
    Write-Verbose -Message "[$($env:USERNAME)]: $(get-date) - Computer Status: $(Out-String -InputObject $Computers)"

    $ActiveComputers = $Computers | Where-Object {$_.Active -eq "True"}
    $InactiveComputers = $Computers | Where-Object {$_.Active -eq "False"}

    Write-Output "[$($env:USERNAME)]: $(get-date) - The App will be installed only in Active Computers. Find inactive computers on log file on: 0_InactiveComputers.log" | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
    Write-Verbose "[$($env:USERNAME)]: $(get-date) - The App will be installed only Active Computers. Find inactive computers on log file on: 0_InactiveComputers.log"

    Write-Output "$(Out-String -InputObject $InactiveComputers.name)" | Out-File -FilePath "$LogDir\0_InactiveComputers.log" -Force

    if ($ActiveComputers -eq $null) {

        Write-Output "[$($env:USERNAME)]: $(get-date) - Error: No Active Computers found. Exiting script." | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
        Write-Verbose -Message "[$($env:USERNAME)]: $(get-date) - Error: No Active Computers found. Exiting script."
        exit

    }

    $colItems = (Get-ChildItem $SourceDir -recurse | Measure-Object -property length -sum)
    $SourceDirSize = "{0:N2}" -f ($colItems.sum / 1MB) + " MB"

    Write-Output "[$($env:USERNAME)]: $(get-date) - Source Directory Size to be copied: $SourceDirSize" | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
    Write-Verbose "[$($env:USERNAME)]: $(get-date) - Source Directory Size to be copied: $SourceDirSize"

    # --------------------------------------------- Copy Package to Computers -------------------------------------------------------------- #

    foreach ($pc in $ActiveComputers) {
        
        $DriveName = $pc.Name.Replace('-', '')

        try {
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root "\\$($pc.name)\C$" -Credential $Credential -ErrorAction Stop -ErrorVariable DriveErr | Out-Null
        }
        catch {
            Write-Output "[$($env:USERNAME)]: $(get-date) - Failed to create Drive on $($pc.name). Delpoyment failed. See Error: $(Out-String -InputObject $DriveErr)" | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
            Write-Verbose "[$($env:USERNAME)]: $(get-date) - Failed to create Drive on $($pc.name). Deployment failed. See Error: $(Out-String -InputObject $DriveErr)"
        }
        
        $Destination = $DriveName + ":\_DE_temp"

        Write-Output "[$($env:USERNAME)]: $(get-date) - Copying package to $($pc.name)"  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
        Write-Verbose "[$($env:USERNAME)]: $(get-date) - Copying package to $($pc.name)"

        Invoke-Command -ComputerName $pc.Name -Credential $Credential -ScriptBlock {
            New-Item -Path "C:\_DE_temp" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        }

        if ($pc.Architecture -eq 'AMD64') {

            try {
                Copy-WithProgress -Source $SourceDirx64 -Destination $Destination -ErrorAction Stop
            }
            catch {
                Write-Output "[$($env:USERNAME)]: $(get-date) - Copying package to $($pc.name) failed. Deployment failed."  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
                Write-Verbose "[$($env:USERNAME)]: $(get-date) - Copying package to $($pc.name) failed. Deployemnt failed."
            }
        
        }
        elseif ($pc.Architecture -eq 'x86') {

            try {
                Copy-WithProgress -Source $SourceDirx86 -Destination $Destination -ErrorAction Stop
            }
            catch {
                Write-Output "[$($env:USERNAME)]: $(get-date) - Copying package to $($pc.name) failed"  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
                Write-Verbose "[$($env:USERNAME)]: $(get-date) - Copying package to $($pc.name) failed"
            }

        }

        Remove-PSDrive -Name $DriveName

    }

    # --------------------------------------------- Start installation on Computers -------------------------------------------------------------- #

    Invoke-Command -ComputerName $ActiveComputers.Name -Credential $Credential -ScriptBlock {
        
        Set-Location -Path "C:\_DE_temp"

        foreach ($Cmd in $using:Command) {

            Start-Sleep -s 1
            Start-Process cmd -ArgumentList "/c","$Cmd" -NoNewWindow -Wait
            Start-Sleep -s 1

        }

        cmd /c "takeown /f C:\_DE_temp"
        Remove-Item -Path "C:\_DE_temp\*" -Exclude "*.log" -Recurse -Force

    } -AsJob -JobName $JobName

    Write-Output "[$($env:USERNAME)]: $(get-date) - Installation on all computers started"  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
    Write-Verbose "[$($env:USERNAME)]: $(get-date) - Installation on all computers started"
    
    Monitor-Jobs -jobName $JobName

    # --------------------------------------------- Copy all logs to source folder -------------------------------------------------------------- #

    Write-Output "[$($env:USERNAME)]: $(get-date) - Installation on all computers finished. Copying logs to $SourcePath"  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
    Write-Verbose "[$($env:USERNAME)]: $(get-date) - Installation on all computers finished. Copying logs to $SourcePath"

    foreach ($pc in $ActiveComputers) {
        
        $DriveName = $pc.Name.Replace('-', '')
        Try{
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root "\\$($pc.name)\C$" -Credential $Credential -ErrorAction Stop -ErrorVariable DriveErr | Out-Null
        }
        catch {
            Write-Output "[$($env:USERNAME)]: $(get-date) - Failed to create Drive on $($pc.name). Delpoyment failed. See Error: $(Out-String -InputObject $DriveErr)" | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
            Write-Verbose "[$($env:USERNAME)]: $(get-date) - Failed to create Drive on $($pc.name). Deployment failed. See Error: $(Out-String -InputObject $DriveErr)"
        }

        $logloc = $DriveName + ":\_DE_temp"

        try {
            Copy-Item -Path ($logloc + "\*.*") -Destination "$LogDir" -ErrorAction Stop -Verbose -ErrorVariable CopyErr
        }
        catch {
            Write-Output "[$($env:USERNAME)]: $(get-date) - $($ps.name) log copy failed. See Error: $CopyErr"  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
            Write-Verbose "[$($env:USERNAME)]: $(get-date) - $($ps.name) log copy failed. See Deployment Log for Details"
        }
        
        Remove-PSDrive -Name $DriveName

    }

    Write-Output "[$($env:USERNAME)]: $(get-date) - Finished copying logs"  | Out-File -FilePath "$LogDir\0_PsDeployLog.log" -Append -Force
    Write-Verbose "[$($env:USERNAME)]: $(get-date) - Finished copying logs"

}

$params = @{
    ComputerName = @()
    SourcePath = ""
    Command = @("install.cmd")
    JobName = "Install-app"
    Credential = (Get-Credential -Message "Please provide your `"Administrator`" credentials:")
}

Deploy-Package @params -verbose