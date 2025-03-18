<#
.SYNOPSIS
Finds the top 20 largest folders on a selected drive and visualizes the progress in a web browser.

.DESCRIPTION
This script starts a local web server, launches a browser to display a progress interface,
prompts the user to select a drive, scans the drive (excluding specified paths),
and updates the browser with the progress and the top 20 largest folders found.

.NOTES
Author: Gemini (Google AI Assistant)
Date: 2025-03-18
#>
param()

# --- Configuration ---
$port = 8080
$url = "http://localhost:$port/"
$excludePathsBase = @(
    "\Program Files\Windows Defender Advanced Threat Protection*",
    "\Windows\CSC*",
    "\Windows\System32\config\BFS*",
    "\Windows\System32\LogFiles\WMI\RtBackup*",
    "\Windows\System32\WebThreatDefSvc*"
)
$topN = 20

# --- Embedded HTML ---
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Folder Size Scan</title>
    <style>
        body { font-family: sans-serif; }
        #progress-container { width: 80%; background-color: #f3f3f3; border: 1px solid #ccc; }
        #progress-bar { background-color: #4CAF50; color: white; padding: 1px; text-align: center; height: 20px; width: 0%; }
        #status { margin-top: 10px; }
        #top-folders-container { margin-top: 20px; }
        #top-folders { list-style-type: none; padding: 0; }
        #top-folders li { margin-bottom: 5px; }
    </style>
</head>
<body>
    <h1>Scanning for Large Folders</h1>
    <div id="progress-container">
        <div id="progress-bar"></div>
    </div>
    <p id="status">Starting scan...</p>
    <div id="top-folders-container">
        <h2>Top $($topN) Largest Folders</h2>
        <ul id="top-folders"></ul>
    </div>
    <script>
        const eventSource = new EventSource('/events');
        const progressBar = document.getElementById('progress-bar');
        const statusElement = document.getElementById('status');
        const topFoldersList = document.getElementById('top-folders');
        const topNElement = document.querySelector('#top-folders-container h2');

        eventSource.onmessage = function(event) {
            const data = JSON.parse(event.data);
            if (data.progress !== undefined) {
                progressBar.style.width = data.progress + '%';
            }
            if (data.status) {
                statusElement.textContent = data.status;
            }
            if (data.topFolders) {
                topFoldersList.innerHTML = '';
                data.topFolders.forEach(folder => {
                    const li = document.createElement('li');
                    li.textContent = `${folder.Path} (${folder.SizeGB} GB)`;
                    topFoldersList.appendChild(li);
                });
            }
        };

        eventSource.onerror = function(error) {
            console.error("EventSource failed:", error);
            statusElement.textContent = "Error during scan.";
        };
    </script>
</body>
</html>
"@

# --- Web Server Logic ---
Add-Type -AssemblyName System

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()
Write-Host "Web server started at $url"

function Send-SSEMessage ($context, $data) {
    $response = $context.Response
    $response.ContentType = "text/event-stream"
    $response.AddHeader("Cache-Control", "no-cache")
    $response.AddHeader("Connection", "keep-alive")
    $outputStream = New-Object System.IO.StreamWriter($response.OutputStream)
    $outputStream.WriteLine("data: $($data | ConvertTo-Json)")
    $outputStream.WriteLine()
    $outputStream.Flush()
}

# Handle initial HTML request
$asyncResultHTML = $listener.BeginGetContext($null, $null)
Write-Host "Waiting for browser connection..."
$contextHTML = $listener.EndGetContext($asyncResultHTML)
$responseHTML = $contextHTML.Response
$responseHTML.ContentType = "text/html"
$bufferHTML = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
$responseHTML.ContentLength64 = $bufferHTML.Length
$responseHTML.OutputStream.Write($bufferHTML, 0, $bufferHTML.Length)
$responseHTML.Close()

# --- Main Script Logic ---
function Get-AvailableDrives {
    $Drives = Get-PSDrive | Where-Object {$_.Provider.Name -eq "FileSystem"}
    if ($Drives.Count -eq 0) {
        Send-SSEMessage $contextEvents @{ status = "No local drives found." }
        return $null
    }
    Send-SSEMessage $contextEvents @{ status = "Listing available drives..." }
    $driveList = @()
    for ($i = 0; $i -lt $Drives.Count; $i++) {
        $driveList += "$($i + 1). $($Drives[$i].Root)"
    }
    Send-SSEMessage $contextEvents @{ status = "Available Drives: $($driveList -join ', ')" }
    return $Drives
}

$AvailableDrives = Get-AvailableDrives
if ($AvailableDrives -eq $null) {
    $listener.Stop()
    exit
}

Send-SSEMessage $contextEvents @{ status = "Prompting for drive selection..." }
$DriveChoice = Read-Host "Enter the number of the drive you want to analyze"

while (($DriveChoice -notmatch "^\d+$") -or ($DriveChoice -lt 1) -or ($DriveChoice -gt $AvailableDrives.Count)) {
    Send-SSEMessage $contextEvents @{ status = "Invalid selection. Please enter a number from the list." }
    $DriveChoice = Read-Host "Enter the number of the drive you want to analyze"
}

$SelectedDrive = $AvailableDrives[$DriveChoice - 1].Root
Send-SSEMessage $contextEvents @{ status = "Selected drive: $SelectedDrive. Starting scan..." }

$ExcludePaths = $excludePathsBase | ForEach-Object { $SelectedDrive + $_ }
$totalSize = 0
$folderSizes = @{}
$processedFolders = 0

Get-ChildItem -Path $SelectedDrive -Directory -Recurse -Exclude $ExcludePaths -ErrorAction SilentlyContinue | ForEach-Object {
    $processedFolders++
    $currentFolder = $_.FullName
    Send-SSEMessage $contextEvents @{ status = "Processing folder: $currentFolder" }
    $size = (Get-ChildItem -Path $currentFolder -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Sum Length).Sum
    $folderSizes[$currentFolder] = $size
    $totalSize += $size # Not really used for progress, but could be
}

$sortedFolders = $folderSizes.GetEnumerator() | Sort-Object -Descending Value | Select-Object -First $topN

$topFoldersFormatted = @()
foreach ($folder in $sortedFolders) {
    $sizeGB = [Math]::Round($folder.Value / 1GB, 2)
    $topFoldersFormatted += @{ Path = $folder.Key; SizeGB = $sizeGB }
}

Send-SSEMessage $contextEvents @{ status = "Scan complete. Displaying top $($topN) folders."; progress = 100; topFolders = $topFoldersFormatted }
# --- Stop Web Server ---
$listener.Stop()
Write-Host "Web server stopped."

# --- Launch Browser ---
Start-Process $url