<#
.SYNOPSIS
Syncs data from PowerShell using FreeFileSync software.

.DESCRIPTION
This is PowerShell wrapper for the Open Source software FreeFileSync using it's command-line interface.
Get FFS at https://freefilesync.org/

2021-10-16
by Diego Reategui

.INPUTS
Will take strings for in any of the following combinations.
Filter (ie. filename(s))
JobsPath (folder path) and Filter
Source (folder path) and Destination (folder path)

.OUTPUTS
Will output one of four completion notes.
"Synchronization completed successfully";
"Synchronization completed with warnings";
"Synchronization completed with errors";
"Synchronization was aborted"

Non-success completion notes will also open logs for the user's review.

.NOTES
-Filter  and  -Destination
Wildcards (*) accepted
Will accept an array

.EXAMPLE
PS C:\> Free-File-Sync -JobsPath 'C:\Users\username\OneDrive\Desktop\Sync Configs\' -Filter desktop_sync.ffs_batch
Processing Job 1 :  desktop_sync
Syncing from :  C:\Users\username\Desktop
To           :  C:\Users\username\OneDrive\Desktop
Sync completed successfully!

# Execute pre-made FFS batch job files programmatically.

.EXAMPLE
PS C:\> Free-File-Sync -Source "$env:USERPROFILE\Desktop" -Destination "$env:OneDrive\Desktop" -WhatIf
Syncing from :  C:\Users\username\Desktop
To           :  C:\Users\username\OneDrive\Desktop
What if: Performing the operation "Update Sync" on target "C:\Users\username\Desktop -> C:\Users\username\OneDrive\Desktop".

# Explicitely specify source and destination paths.

.EXAMPLE
PS C:\> Free-File-Sync -Source "$env:USERPROFILE\Desktop" -Destination "$env:OneDrive\Desktop",".\thisfolder" -WhatIf

Processing Job 1 :  Custom_Sync_Job_2021-10-14T20
Syncing from :  C:\Users\username\Desktop
To           :  C:\Users\username\OneDrive\Desktop
What if: Performing the operation "Update Sync" on target "C:\Users\username\Desktop -> C:\Users\username\OneDrive\Desktop".

Processing Job 2 :  Custom_Sync_Job_2021-10-14T20
Syncing from :  C:\Users\username\Desktop
To           :  .\thisfolder
What if: Performing the operation "Update Sync" on target "C:\Users\username\Desktop -> .\thisfolder".

# Specify multiple destination paths.
# Beware that syncs will be executed in a serial fashion in case you use a SyncType that changes the source contents.


#>
function Free-File-Sync {
    [CmdletBinding(SupportsShouldProcess = $True, DefaultParameterSetName = 'BatchJob')]
    param (
        [Parameter(ParameterSetName = 'BatchJob', Position = 0)]
        [string]   $JobsPath = ".\",
        [Parameter(ParameterSetName = 'BatchJob', Position = 1)]
        [string[]] $Filter  = @("*.ffs_batch"),

        [Parameter(Mandatory = $true, ParameterSetName = 'BuildAJob', Position = 0)]
        [string]   $Source,
        [Parameter(Mandatory = $true, ParameterSetName = 'BuildAJob', Position = 1)]
        [string[]] $Destination,
        [Parameter(Mandatory = $false, ParameterSetName = 'BuildAJob')]
        [ValidateSet('TwoWay', 'Mirror', 'Update')] # Haven't implemented 'Custom' formatting yet.
        [string]  $SyncType = "Update",

        [switch] $ShowLogs
    )
    Begin {
        $ffs="C:\Program Files\FreeFileSync\FreeFileSync.exe"
        if (-not (Test-Path $ffs)) {
            Write-Host "FreeFileSync not found." -ForegroundColor Red
            Write-Host "You can donwload it from https://freefilesync.org/"
            return
        }
        $logPath = "$env:APPDATA\FreeFileSync\Logs\"
        if (-not (Test-Path $logPath)) {
            Write-Warning "Log path not found. Any errors generated will be unable to be displayed."
        }
        switch ($PSCmdlet.ParameterSetName) {
            'BatchJob' 
            {
                # Using pre-made job batch file.
                Write-Verbose ("Recieved JobsPath: " + $JobsPath)
                Write-Verbose ("Recieved $($Filter.Count) Filter$(if ($Filter.Count -ne 1) {"s"}): " + ($Filter -join ', '))

                # if not array, turn into array @()
                if (-not ($Filter -is [array])) {
                    $Filter = @($Filter)
                }

                # if $Filter is default value (Ie. it was unused) AND a batch file name was provided in $JobsPath
                if ($Filter -eq @("*.ffs_batch") -and $JobsPath.EndsWith(".ffs_batch")) {
                    $Filter = @(Split-Path $JobsPath -Leaf)
                    if (-not ($JobsPath = Split-Path $JobsPath)) {
                        $JobsPath = '.'
                    }
                    Write-Verbose "Distributed `$JobPath into `$JobPath '$JobsPath' and `$Filter '$($Filter -join ', ')"
                }

                $JobsPathS = [System.Collections.ArrayList]@()
                
                # Validate paths, either full path in $Filter or combination of $JobsPath and $Filter
                foreach ($path in $Filter) {
                    $full_path = 
                    if ([System.IO.Path]::IsPathRooted($path)) {
                        # full path (might or might not have file name)
                        $path
                    }
                    else {
                        # partial path or file name

                        # add extension if not there
                        if ($path -notmatch '\.ffs_batch$'){
                            $path = "$path.ffs_batch"
                        }
                        Join-Path $JobsPath $path
                    }

                    if (-not (Test-Path $full_path)) {
                        Write-Warning "File does not exist.  '$full_path'"
                        Continue
                    }
                    Write-Verbose ("Adding job task: " + (Split-Path $full_path -Leaf))
                    $JobsPathS.add($full_path) | Out-Null
                }
            }

            'BuildAJob' 
            {
                # Have to build a job file, otherwise the FFS GUI will pop up and it won't proceed with the sync.
                Write-Verbose "Building sync job(s)."
                $xml_template = 
                '<?xml version="1.0" encoding="utf-8"?>
                <FreeFileSync XmlType="BATCH" XmlFormat="17">
                    <Compare>
                        <Variant>TimeAndSize</Variant>
                        <Symlinks>Exclude</Symlinks>
                        <IgnoreTimeShift/>
                    </Compare>
                    <Synchronize>
                        <Variant>{0}</Variant>
                        <DetectMovedFiles>false</DetectMovedFiles>
                        <DeletionPolicy>RecycleBin</DeletionPolicy>
                        <VersioningFolder Style="Replace"/>
                    </Synchronize>
                    <Filter>
                        <Include>
                            <Item>*</Item>
                        </Include>
                        <Exclude>
                            <Item>\System Volume Information\</Item>
                            <Item>\$Recycle.Bin\</Item>
                            <Item>\RECYCLER\</Item>
                            <Item>\RECYCLED\</Item>
                            <Item>*\desktop.ini</Item>
                            <Item>*\thumbs.db</Item>
                            <Item>\*\.wdmc\*</Item>
                        </Exclude>
                        <TimeSpan Type="None">0</TimeSpan>
                        <SizeMin Unit="None">0</SizeMin>
                        <SizeMax Unit="None">0</SizeMax>
                    </Filter>
                    <FolderPairs>
                        <Pair>
                            <Left>{1}</Left>
                            <Right>{2}</Right>
                        </Pair>
                    </FolderPairs>
                    <Errors Ignore="false" Retry="1" Delay="5"/>
                    <PostSyncCommand Condition="Completion"/>
                    <LogFolder/>
                    <EmailNotification Condition="Always"/>
                    <Batch>
                        <ProgressDialog Minimized="false" AutoClose="true"/>
                        <ErrorDialog>Show</ErrorDialog>
                        <PostSyncAction>None</PostSyncAction>
                    </Batch>
                </FreeFileSync>'
                $jobFileNameS = [System.Collections.ArrayList]@()
                foreach ($d in $Destination | Where-Object {$_ -ne $Source } | Select-Object -Unique) {
                    $xml_string = $xml_template -f $SyncType, $Source, $d
                    $xml = [xml]$xml_string
                    $save_file_name = "Custom_Sync_Job_" + ((Get-Date -f "o") -replace ":", ".") + ".ffs_batch"
                    $full_save_file_name = Join-Path $env:TEMP $save_file_name
                    $xml.Save($full_save_file_name)
                    Write-Verbose ("Created job file: " + $full_save_file_name)
                    $jobFileNameS.Add($save_file_name) | Out-Null
                    if (-not (Test-Path $full_save_file_name)) {
                        Write-Host "Error: Job file did not create successfully." -ForegroundColor Red
                    }
                }
                Write-Verbose "Function recursively calling itself."
                Free-File-Sync -JobsPath $env:TEMP -Filter $jobFileNameS -ShowLogs:$ShowLogs -Verbose:$VerbosePreference
            }
        }
    }
    
    Process {
        if ($PSCmdlet.ParameterSetName -eq 'BuildAJob') {
            return
        }
        
        if (-not $JobsPathS) {
            Write-Host "No valid paths recieved." -ForegroundColor Red
            return
        }

        Write-Verbose "Doing... `"Get-ChildItem $JobsPathS -ErrorAction Stop | Select-Object -ExpandProperty FullName -Unique`""

        $JobFiles = try {
            Get-ChildItem $JobsPathS -ErrorAction Stop | Select-Object -ExpandProperty FullName -Unique
        } catch {
            $null
        }
        if ($PSCmdlet.ParameterSetName -eq 'BatchJob' -and -not $JobFiles) {
            Write-Host "No jobs found.  Exiting." -ForegroundColor Red
            return
        }
        elseif ($JobFiles.Count -gt 5) {
            Write-Warning "Beware an unexpectedly large number of job files ($($JobFiles.Count)) were found."
            foreach ($Name in $JobFiles) {
                Write-Host $Name.split("\")[-1] -ForegroundColor DarkGray
            }
            Write-Host "Sync jobs will continue in 10 seconds..." #-ForegroundColor DarkGray
            Start-Sleep 11
            Write-Host
        }

        $sync_Jobs = [System.Collections.ArrayList]@()
        foreach ($filename in $JobFiles) {
            Write-Verbose ("Found job file: " + (Split-Path $filename -Leaf).split(".")[0])
            [xml]$xml = Get-Content $filename #-ErrorAction Stop
            $job = @{
                Name     = (Split-Path $filename -Leaf).split(".")[0];
                jobPath  = $filename;
                From     = $xml.FreeFileSync.FolderPairs.Pair.Left -join ', ';
                To       = $xml.FreeFileSync.FolderPairs.Pair.Right -join ', ';
                Tries    = 0;
                Complete = $false
            }
            $sync_Jobs.Add($job) | Out-Null
        }

        $i = 1
        foreach ($job in $sync_Jobs) {
            Write-Host "Processing Job $(($i++)) : " $job.Name -ForegroundColor Cyan
            Write-Host "Syncing from : " $job.From
            Write-Host "To           : " $job.To
            if (-not (Test-Path $job.From)) {
                Write-Host "Source path does not exist.`n" -F Red
                Continue
            }
            $should_process_message = "$($job.From) -> $($job.To)"
            if ($SyncType -eq 'TwoWay') {
                $should_process_message = $should_process_message.Replace("->", "<->")
            }
            if ($PSCmdlet.ShouldProcess($should_process_message,"$SyncType Sync")) {
                $_process = Start-Process $ffs -ArgumentList "`"$($job.jobPath)`"" -Wait -PassThru
            }
            else {
                Write-Host
                Continue
            }

            $message_color = "Yellow"
            $completion_message = switch ($_process.ExitCode) {
                0 { "Sync completed successfully"; $message_color = "Green" }
                1 { "Synchronization completed with warnings" }
                2 { "Synchronization completed with errors" }
                3 { "Synchronization was aborted" }
                default { "Unknown exit code '$($_process.ExitCode)'"; $message_color = "Red" }
            }
            Write-Host $completion_message -ForegroundColor $message_color

            $logFilePath = Join-Path $logPath "$($job.Name)*.html"
            $logFile = Get-ChildItem $logFilePath -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($logFile -and ($_process.ExitCode -or $ShowLogs)) {
                Start-Process $logFile
            }

            Write-Host
        }
    }
    
    End {
        if ($PSCmdlet.ParameterSetName -eq 'BuildAJob') {
            foreach ($filename in $jobFileNameS) {
                Write-Verbose "Removing temp job file: $filename"
                try {
                    Remove-Item (Join-Path $env:TEMP $filename) -ErrorAction Stop -WhatIf:$false
                }
                catch {
                    Write-Warning "Error: Failed to remove temp job file $filename"
                }
            }
        }
    }
}
