. .\env.ps1

# Define the URL to upload the file to
$url = 'https://europe-west2-saiit-operations.cloudfunctions.net/IntuneHWIDHarvester' + "?token=${TOKEN}"

# Specify the path to the CSV file you want to upload
$serial = (Get-CimInstance win32_bios).SerialNumber
$dateTime = Get-Date -Format "yyyyMMdd-HHmm"
$workingDir = "C:\ProgramData\WhileTech"
$tempDir = "${workingDir}\temp"
$filePath = "${tempDir}\HWID.csv"
$logDir = "${workingDir}\logs"
$logPath = "${logDir}\HWIDHarvester.log"

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

Ensure-Path $logDir
Log 'Log directory created...'
Log "Creating temporary directory.."
Ensure-Path $tempDir

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
    }
    else {
        Log "Error: ${message}" Red
    }

}
catch {
    Log "Error: $_" Red
    return $false
}


