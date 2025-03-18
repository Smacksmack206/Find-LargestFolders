# Function to get a list of available drives
function Get-AvailableDrives {
    $Drives = Get-PSDrive | Where-Object {$_.Provider.Name -eq "FileSystem"}
    if ($Drives.Count -eq 0) {
        Write-Host "No local drives found."
        exit
    }
    Write-Host "Available Drives:"
    for ($i = 0; $i -lt $Drives.Count; $i++) {
        Write-Host "$($i + 1). $($Drives[$i].Root)"
    }
    return $Drives
}

# Get the list of available drives
$AvailableDrives = Get-AvailableDrives

# Prompt the user to select a drive
$DriveChoice = Read-Host "Enter the number of the drive you want to analyze"

# Validate the user's input
while (($DriveChoice -notmatch "^\d+$") -or ($DriveChoice -lt 1) -or ($DriveChoice -gt $AvailableDrives.Count)) {
    Write-Host "Invalid selection. Please enter a number from the list."
    $DriveChoice = Read-Host "Enter the number of the drive you want to analyze"
}

# Get the selected drive path
$SelectedDrive = $AvailableDrives[$DriveChoice - 1].Root

# Paths to exclude
$ExcludePaths = @(
    "$SelectedDrive\Program Files\Windows Defender Advanced Threat Protection*",
    "$SelectedDrive\Windows\CSC*",
    "$SelectedDrive\Windows\System32\config\BFS*",
    "$SelectedDrive\Windows\System32\LogFiles\WMI\RtBackup*",
    "$SelectedDrive\Windows\System32\WebThreatDefSvc*"
)

# Main script to find large folders
Get-ChildItem -Path $SelectedDrive -Directory -Recurse -Exclude $ExcludePaths -ErrorAction SilentlyContinue | ForEach-Object {
    $Size = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Sum Length).Sum
    [PSCustomObject]@{
        Path = $_.FullName
        SizeGB = [Math]::Round($Size / 1GB, 2)
    }
} | Sort-Object -Descending SizeGB | Select-Object -First 20 | Format-Table -AutoSize