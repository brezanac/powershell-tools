<#
.SYNOPSIS
    Performs a backup of a single Microsoft SQL database with additional features.

.DESCRIPTION
    Performs backup of a single Microsoft SQL database.
    Ideal for running through Task scheduler (calls all required assemblies).
    Provides an option to securely store the email login as an encrypted string.
    Has the ability to send email notifications through SMTP on failure.
    Preserves only a specified number of latest backups.

.PARAMETER server
    The Microsoft SQL server instance on which the back up will be performed.

.PARAMETER path
    Path to the location where the backup will be stored.

.PARAMETER dbname
    Name of the database to back up.

.PARAMETER minFreeSpaceGB
    Minimum amount of free space in GB required to proceed with the backup.

.PARAMETER maxNrBackups
    Maximum number of latest backups to preserve in the backup destination.

.PARAMETER disableEmailNotifications
    If specified, no email notifications will be sent on failure.

.PARAMETER generateEmailAuth
    If specified, the script will switch role to generating and storing an 
    encrypted version of the SMTP authentication file. No backup will be performed.

.PARAMETER emailAuthPath
    Path to the external file where the SMTP authentication will be stored.

.INPUTS
    None. No piped input is accepted.

.OUTPUTS
    System.String. Standard notifications output.

.EXAMPLE
    Backup-Msql-Database -generateEmailAuth

.EXAMPLE
    Backup-Msql-Database -generateEmailAuth -emailAuthPath ".\credentials"

.EXAMPLE
    Backup-Msql-Database -server example.com\SQLEXPRESS -path C:\Backup -dbname "Database"

.EXAMPLE
    Backup-Msql-Database -dbname "Database" -minFreeSpace 10 -maxNrBackups 20
#>

# Default parameters.
param(
    [string] $server = 'localhost',
    [string] $path = '.\backup',
    [string] $dbname = 'Database',
    [int] $minFreeSpaceGB = 10,
    [int] $maxNrBackups = 15,
    [switch] $disableEmailNotifications,
    [switch] $generateEmailAuth,
    [string] $emailAuthPath = '.\auth'
)

# Email settings.
$email = @{
    from = 'Notifications System <notifications@example.com>'
    to = 'Development <dev@example.com>'
    smtp_server = 'smtp.example.com'
    smtp_username = 'notifications@example.com'
    smtp_port = 587
}

# Output format for displaying error messages.
$colorsError = @{
    ForegroundColor = "White"
    BackgroundColor = "DarkRed"
}

# Output format for displaying notices.
$colorsNotice = @{
    ForegroundColor = "Black"
    BackgroundColor = "White"
}

# If the -generateEmailAuth switch is supplied, switching the script role to generate and store an encrypted email login.
if($PSBoundParameters['generateEmailAuth']) {
    Write-Host "[NOTICE] Generating an email auth file for `"$($email.'from')`"" @colorsNotice
    Read-Host "Enter password" -AsSecureString | ConvertFrom-SecureString | Out-File $emailAuthPath

    if (-not (Test-Path($emailAuthPath))) {
        Write-Host "[ERROR] Unable to write the email auth file!" @colorsError 
        break
    }

    Write-Host "[NOTICE] Email auth file generated successfully." @colorsNotice
    Write-Host "Please rerun the cmdlet without -generateEmailAuth to perfrom backup."
    break
}

# If -disableEmailNotifications is not provided it's expected for the email auth file to already exist.
if (-not $PSBoundParameters['disableEmailNotifications'] -and -not (Test-Path($emailAuthPath))) {
    Write-Host "[ERROR] Unable to locate the email authentication at `"${emailAuthPath}`"." @colorsError
    Write-Host 'Run again with -generateEmailAuth to create one or -disableEmailNotifications to disable notifications.'
    break
}

# Checking if requested database exists.
# Following assembly is required if the script is run through Task scheduler!
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
$srv = New-Object 'Microsoft.SqlServer.Management.SMO.Server' $server
if(-not [bool]($srv.Databases.Name -match "^${dbname}$")){
    Write-Host "[ERROR] Database `"${dbname}`" does not exist on server ${server}!" @colorsError
    break
}

# Testing if backup path exists and if not one will be made.
if (-not (Test-Path "${path}${dbname}")) {
    New-Item -ItemType Directory -Path "${path}${dbname}";
}

# Retrieving the drive letter of the specified backup path.
$driveLetterTest = $path -match '^([a-z]):'
if ($driveLetterTest) {
    $driveLetter = $matches[1]
}

# Sending an email notification if the amount of available free space is lower than $minFreeSpaceGB.
$freeSpace = [math]::Round((Get-PSDrive $driveLetter | Select-Object -ExpandProperty Free) / 1GB, 2)
if (-not $PSBoundParameters['disableEmailNotifications'] -and ($freeSpace -lt $minFreeSpaceGB)) {
    $auth = Get-Content $emailAuthPath | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential $email.'smtp_username', $auth
    $subject = "[WARNING] Daily SQL Backup failed on ${server}!"
    
    $body = "Server: ${server}`n"
    $body += "Database: ${dbname}`n"
    $body += "Date/Time: $(Get-Date -f 'dd.MM.yyyy hh:mm:ss')`n"
    $body += "Reason: Available free space (${freeSpace} GB) is bellow set minimum (${minFreeSpaceGB} GB)!"
    
    Send-MailMessage -From $email.'from' -to $email.'to'  -Subject $subject -Body $body -SmtpServer $email.'smtp_server' -port $email.'smtp_port' -UseSsl -Credential $credentials
    break
}

# Performing the actual backup.
$filename = "${path}${dbname}\${dbname}_$(Get-Date -f 'yyyyMMdd_hhmmss').bak"
Backup-SqlDatabase -ServerInstance $server -Database $dbname -BackupFile $filename

# Making sure to only keep a specified ($maxNrBackups) number of backups.
$nrBackups = Get-ChildItem "${path}${dbname}\*.bak" | Measure-Object | ForEach-Object{$_.Count}
if($nrBackups -gt $maxNrBackups) {
    Get-ChildItem "${path}${dbname}\*.bak" | Sort-Object CreationTime | Select-Object -First ($nrBackups - $maxNrBackups) | Remove-Item
}