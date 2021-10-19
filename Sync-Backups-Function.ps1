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
        [Parameter(Mandatory = $false, ParameterSetName = 'BatchJob')]
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
                Write-Verbose ("Recieved JobsPath: " + $JobsPath)
                Write-Verbose ("Recieved $($Filter.Count) Filter$(if ($Filter.Count -ne 1) {"s"}): " + ($Filter -join ', '))

                if ($JobsPath.EndsWith(".ffs_batch") -and $Filter -eq "*.ffs_batch") {
                    $Filter = $JobsPath
                    $JobsPath = ".\"
                    Write-Verbose "Swapped `$JobPath and `$Filter"
                }

                $JobsPathS = [System.Collections.ArrayList]@()
                for ($i=0; $i -lt $Filter.Count; $i++) {
                    $Pattern = $Filter[$i]
                    if ($Pattern -notmatch '\.ffs_batch'){
                        $Pattern = "$Pattern.ffs_batch"
                    }
                    Write-Verbose ("Adding job task: " + $Pattern)
                    $full_path = Join-Path $JobsPath $Pattern
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
                $filenameS = [System.Collections.ArrayList]@()
                foreach ($d in $Destination | Where-Object {$_ -ne $Source } | Select-Object -Unique) {
                    $xml_string = $xml_template -f $SyncType, $Source, $d
                    $xml = [xml]$xml_string
                    $save_file_name = "Custom_Sync_Job_" + ((Get-Date -f "o") -replace ":", ".") + ".ffs_batch"
                    $full_save_file_name = Join-Path $env:TEMP $save_file_name
                    $xml.Save($full_save_file_name)
                    Write-Verbose ("Created job file: " + $full_save_file_name)
                    $filenameS.Add($save_file_name) | Out-Null
                    if (-not (Test-Path $full_save_file_name)) {
                        Write-Host "Error: Job file did not create successfully." -ForegroundColor Red
                    }
                }
                Write-Verbose "Function recursively calling itself."
                Free-File-Sync -JobsPath $env:TEMP -Filter $filenameS -SyncType $SyncType -ShowLogs:$ShowLogs -Verbose:$VerbosePreference
            }
        }
    }
    
    Process {
        if ($PSCmdlet.ParameterSetName -eq 'BuildAJob') {
            return
        }
        Write-Verbose "Doing... `"Get-ChildItem $JobsPathS -ErrorAction Stop | Select-Object -ExpandProperty FullName -Unique`""

        $JobFiles = try {
            Get-ChildItem $JobsPathS -ErrorAction Stop | Select-Object -ExpandProperty FullName -Unique
        } catch {
            $null
        }
        if (-not ($JobFiles -and $JobsPathS)) {
            Write-Host "No jobs found.  Exiting." -ForegroundColor Red
            return
        }

        $jobs = [System.Collections.ArrayList]@()
        foreach ($filename in $JobFiles) {
            Write-Verbose ("Found job file: " + (Split-Path $filename -Leaf).split(".")[0])
            [xml]$xml = Get-Content $filename #-ErrorAction Stop
            $job = @{
                Name     = (Split-Path $filename -Leaf).split(".")[0];
                jobPath  = $filename;
                From     = $xml.FreeFileSync.FolderPairs.Pair.Left;
                To       = $xml.FreeFileSync.FolderPairs.Pair.Right;
                Tries    = 0;
                Complete = $false
            }
            $jobs.Add($job) | Out-Null
        }

        $i = 1
        foreach ($job in $jobs) {
            Write-Host "Processing Job $i : " $job.Name -ForegroundColor Cyan
            Write-Host "Syncing from : " $job.From
            Write-Host "To           : " $job.To
            if (-not (Test-Path $job.From)) {
                Write-Host "Source path does not exist." -F Red
                Continue
            }
            $shouldProcess = "$($job.From) -> $($job.To)"
            if ($SyncType -eq 'TwoWay') {
                $shouldProcess = $shouldProcess.Replace("->", "<->")
            }
            if ($PSCmdlet.ShouldProcess($shouldProcess,"$SyncType Sync")) {
                $process = Start-Process $ffs -ArgumentList "`"$($job.jobPath)`"" -Wait -PassThru
            }

            $msgColor = "Yellow"
            $msg = switch ($process.ExitCode) {
                0 { "Sync completed successfully"; $msgColor = "Green" }
                1 { "Synchronization completed with warnings" }
                2 { "Synchronization completed with errors" }
                3 { "Synchronization was aborted" }
                default { "Unknown exit code '$($process.ExitCode)'"; $msgColor = "Red" }
            }
            Write-Host $msg -ForegroundColor $msgColor

            $logFilePath = Join-Path $logPath "$($job.Name)*.html"
            $logFile = Get-ChildItem $logFilePath -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($logFile -and ($process.ExitCode -or $ShowLogs)) {
                Start-Process $logFile
            }

            $i++
            Write-Host
        }
    }
    
    End {
        if ($PSCmdlet.ParameterSetName -eq 'BuildAJob') {
            foreach ($filename in $filenameS) {
                Write-Verbose "Removing job file: $filename"
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
