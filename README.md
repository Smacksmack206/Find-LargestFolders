# Find-LargeFolders

This PowerShell script helps you quickly identify the top 20 largest folders on a selected drive. It provides a user-friendly way to choose which drive to analyze and allows for excluding specific directories to avoid permission errors or irrelevant results.

It's fusterating when using Windows and you have to jump through hoops to identfy what is taking up the most storage without 3rd party solutions.

## Features

* **Dynamic Drive Listing:** Automatically detects and lists available local drives.
* **User-Friendly Drive Selection:** Allows you to choose the drive to analyze from a numbered list.
* **Recursive Search:** Scans all subfolders within the selected drive.
* **Exclusion of Specific Folders:** Includes a predefined list of common system folders that often cause "Access Denied" errors, which you can easily customize.
* **Top 20 Results:** Displays the 20 largest folders found, sorted by size.
* **Clear Output:** Presents the folder paths and their sizes in gigabytes in a formatted table.

## Prerequisites

* Windows operating system.
* PowerShell (version 3.0 or later, which is typically included in modern versions of Windows).

## Usage

1.  **Save the Script:**
    * Copy the entire script code provided below.
    * Open a plain text editor (like Notepad).
    * Paste the code into the editor.
    * Save the file with a `.ps1` extension (e.g., `Find-LargeFolders.ps1`). Choose a location you can easily access, like your Documents folder.

    ```powershell
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
    ```

2.  **Open PowerShell:** Open a PowerShell window.

3.  **Navigate to the Script's Directory:** Use the `cd` command to navigate to the folder where you saved the `Find-LargeFolders.ps1` file. For example:

    ```powershell
    cd Documents
    ```

4.  **Run the Script:** Execute the script by typing the following command and pressing Enter:

    ```powershell
    .\Find-LargeFolders.ps1
    ```

5.  **Select a Drive:** The script will display a numbered list of available drives. Enter the number corresponding to the drive you want to analyze and press Enter.

6.  **View Results:** The script will then scan the selected drive and display a table showing the top 20 largest folders and their sizes in gigabytes.

## Excluding Folders

The script includes a predefined list of folders in the `$ExcludePaths` variable that are commonly protected and might cause "Access Denied" errors. You can customize this list by:

1.  Opening the `Find-LargeFolders.ps1` file in a text editor.
2.  Locating the `$ExcludePaths` section:

    ```powershell
    # Paths to exclude
    $ExcludePaths = @(
        "$SelectedDrive\Program Files\Windows Defender Advanced Threat Protection*",
        "$SelectedDrive\Windows\CSC*",
        "$SelectedDrive\Windows\System32\config\BFS*",
        "$SelectedDrive\Windows\System32\LogFiles\WMI\RtBackup*",
        "$SelectedDrive\Windows\System32\WebThreatDefSvc*"
    )
    ```

3.  **Add or remove paths** from this array. Make sure to enclose each path in double quotes. You can use wildcards (`*`) at the end of a path to exclude the entire directory and its subdirectories.
4.  Save the changes to the file.

## Permissions

* **Standard User Permissions:** You can run this script with your regular user account. However, you might encounter "Access Denied" errors for certain protected system folders, and their sizes won't be included in the results.
* **Run as Administrator:** To analyze protected system folders as well, you can run PowerShell as an administrator (right-click on the PowerShell icon and select "Run as administrator" before running the script). This will grant the script higher privileges. Be cautious when running scripts with administrator privileges.

## Limitations

* The script only displays the top 20 largest folders. You can modify the `Select-Object -First 20` part of the script to show a different number of results if needed.
* The accuracy of the results depends on the permissions of the user running the script. Folders that the user doesn't have read access to will be skipped.
* Scanning very large drives with many files and folders can take some time to complete.

## Contributing

While this is a personal script, if you have suggestions or improvements, feel free to fork the repository and submit a pull request.

## License

[Optional: Add a license here if you intend to distribute the script under a specific license, e.g., MIT License]
