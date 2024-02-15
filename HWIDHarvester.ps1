##################################################################################################################################
##################################################################################################################################                                                                                                                       
#
# HWIDHarvester
# 2024 Simon Tucker
#                                                                                                                                
##################################################################################################################################
##################################################################################################################################

param (
    [string] $mode
)

if ($mode) {
    $mode = $mode.ToLower()
    $mode = $mode.Trim()
}

. .\env.ps1

# Define the URL to upload the file to
$url = 'https://europe-west2-saiit-operations.cloudfunctions.net/IntuneHWIDHarvester' + "?token=${TOKEN}"

$installRegistryItems = @(
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WhileTech';
        Keys = @(
            @{ Name = 'HWIDHarvested'; Value = 1; Type = 'QWORD'}
        )
    }
    # Add more path entries as needed
)

$testRegistryItems = @(
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WhileTech';
        Keys = @(
            @{ Name = 'HWIDHarvested'; Value = 1}
        )
    }
    # Add more path entries as needed
)

# Specify the path to the CSV file you want to upload
$serial = (Get-CimInstance win32_bios).SerialNumber
$dateTime = Get-Date -Format "yyyyMMdd-HHmm"
$workingDir = "C:\ProgramData\WhileTech"
$tempDir = "${workingDir}\temp"
$filePath = "${tempDir}\HWID.csv"
$logDir = "${workingDir}\logs"


function Log {
    param (
        [string] $message,
        [string] $color
    )

    if (!$color) {
        $color = "Cyan"
    }

    if ($logPath) {
        $message | Out-File -FilePath $logPath -Append
    }
    Write-Host $message -ForegroundColor $color
}

function Ensure-Path {
    param (
        [string] $dir
    )

    # Check if directory exists and if not create
    if (-not (Test-Path $dir)) {
        Log "$dir does not exist"
        Log "Creating..."
        New-Item -Path $dir -ItemType Directory -Force -ErrorAction SilentlyContinue
    }
}

function Update-Registry ($installRegistryItems) {
    if (($installRegistryItems -and $installRegistryItems.Length -gt 0)) {

        foreach ($item in $installRegistryItems) {

            if (-not (Test-Path $item.Path)) {
                New-Item -Path $item.Path -ItemType Directory
            }

            foreach ($key in $item.Keys) {

                if (-not (Get-ItemProperty -Path $item.Path -Name $key.Name -ErrorAction SilentlyContinue)) {
                    New-ItemProperty -Path $item.Path -Name $key.Name -Value $key.Value -PropertyType $key.Type -Force *> $null
                } 
                else {
                    Set-ItemProperty -Path $item.Path -Name $key.Name -Value $key.Value *> $null
                }
            }
        }
    }
}

function Is-Installed {

    $detectedColor = 'Green'
    $notDetectedColor = 'Red'

    if ($testRegistryItems -and $testRegistryItems.Length -gt 0) {
        Log "Testing testRegistryItems..."
        foreach ($item in $testRegistryItems) {
            if (Test-Path $item.Path) {
                foreach ($key in $item.Keys) {
                    Log "Testing Path: $($item.Path), Name: $($key.Name), Value: $($key.Value)"
                    try {
                        $value = Get-ItemProperty -Path $item.Path -Name $key.Name -ErrorAction Stop
                        $keyName = $key.Name
                        Log "Testing: $($value.$keyName) -ne $($key.Value))"
                        if ($value.$keyName -ne $key.Value) {
                            Log "Not equal" $notDetectedColor
                            return $false
                        }
                    } 
                    catch {
                        Log "Error: $_" $notDetectedColor
                        return $false
                    }
                }
            }
            else {
                Log "Path $item.Path does Not exist" $notDetectedColor
                return $false
            }
        }
        Log 'All test registry keys passed' Green
        return $true
    } 
    Log 'No test registry keys provided' Red
    return $false
}

Ensure-Path $logDir
Ensure-Path $tempDir

if ($mode -eq 'install') {
    $logPath = "${logDir}\HWIDHarvesterInstall.log"
    Log 'Getting hardware ID...'
    Log 'Setting security protocol...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Log 'Setting environment path...'
    $env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
    Log 'Installing Nugent...'
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -Confirm:$false > $null
    Log 'Setting executionpolicy to RemoteSigned...'
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
    Log 'Installing Get-WindowsAutopilotInfo Powershell script...'
    Install-Script -Name Get-WindowsAutopilotInfo -Force -Scope CurrentUser -Confirm:$false > $null
    Log 'Finding script absolute path...'
    $scriptPath = Get-InstalledScript -Name Get-WindowsAutopilotInfo | Select-Object -ExpandProperty InstalledLocation
    Log 'Executing...'
    & "$scriptPath\Get-WindowsAutopilotInfo.ps1" -OutputFile $filePath *> $null

    # Read the CSV content with UTF-8 encoding
    Log 'Reading HWID file content...'
    $fileContent = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)

    # Convert the body to a byte array
    Log 'Converting to bytes...'
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)

    # Prepare the headers
    $headers = @{
        'Content-Type' = 'text/csv; charset=utf-8'
    }

    # Perform the request
    Log 'Making POST request...'
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $bodyBytes
        # Display the response
        $status = $response.status
        $message = $response.message
        if ($status -eq 'success') {
            Log "Success: file created /w ID: ${message}" Green
            Update-Registry ($installRegistryItems)
            Exit 0
        }
        else {
            Log "Error: ${message}" Red
        }
    }
    catch {
        Log "Error: $_" Red
    }
}
else {
    $logPath = "${logDir}\HWIDHarvesterDetect.log"
    if (Is-Installed) {
        Log 'HWIDHarvester detected' Green
        Exit 0
    }
    else {
        Log 'HWIDHarvester NOT detected' Red
    }
}

Exit 1