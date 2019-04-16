# Backup-Msql-Database

A simple Powershell script to back up a single Microsoft SQL database, with some additional useful features that make automation easier.

It's ideal for scheduling regular backups through Windows Task scheduler.

## Features

* Support for backing up a single Microsoft SQL database.
* Support for sending email notifications through SMTP on failures.
* Option to limit the number of preserved backups.
* Option to abort backup if the minimum allowed amount of free space is reached.
* Support for generating and storing an encrypted SMTP authentication file.
* Detailed output for all operations.

## Requirements

This tool has the following requirements:

* **Powershell** - this is kind of a no-brainer ([Powershell](https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-6))
* Access to an SMTP server in case email notifications are used.
* Obviously a running Microsoft SQL Server instance.

## Usage

### Important prerequisites ###

If you are going to use email notifications, which are enabled by default, you **need** to first generate an encrypted authentication file which will be used for accessing the SMTP server by providing the `-generateEmailAuth` switch as parameter and supplying the password for the SMTP user.

Authentication files are **NOT** transferable between machines! You **MUST** generate one on the machine where the script will be executed!

```
Backup-Msql-Database.ps1 -generateEmailAuth
```

You can overide the default path for the authentication file (`.\auth`) with the `emailAuthPath` parameter.

```
Backup-Msql-Database.ps1 -generateEmailAuth -emailAuthPath 'path\to\authentication\file'
```

If you do not want to use email notifications at all you can simply provide the `-disableEmailNotifications` switch.

```
Backup-Msql-Database.ps1 -disableEmailNotifications
```

### Basic usage ###

You can use the script without specifying any parameters by simply adjusting the default parameter values in the script itself.

```
Backup-Msql-Database.ps1
```

Optionally you can specify or overide all the configuration options with the ones specified in the following section.

## Configuration

List of options that can be changed directly in the script or supplied as parameters during execution.

| Property | Type | Default value | Description |
| --- | --- | --- | --- |
| **server** | *string* | 'localhost' | The Microsoft SQL server instance on which the back up will be performed. |
| **path** | *string* | '.\backup' | Path to the location where the backup will be stored. |
| **minFreeSpaceGB** | *int* | 10 | Minimum amount of free space in GB required in order to proceed with the backup. |
| **maxNrBackups** | *int* | 15 | Maximum number of latest backups to preserve in the backup destination. |
| **disableEmailNotifications** | *boolean* | $false | If specified, no email notifications will be sent on failure. |
| **generateEmailAuth** | *boolean* | $false | If specified, the script will switch role to generating and storing an encrypted version of the SMTP authentication file. No backup will be performed. |
| **emailAuthPath** | *string* | '.\auth' | Path to the external file where the SMTP authentication will be stored. |

## Examples

Generating a new SMTP authentication file. No backup will be performed.

```
Backup-Msql-Database -generateEmailAuth
```

Generating a new SMTP authentication file and storing it in `.\credentials`.

```
Backup-Msql-Database -generateEmailAuth -emailAuthPath ".\credentials"
```

Backing up database `Database` from Microsoft SQL server instance at `example.com\SQLEXPRESS` and storing it at `C:\Backup`.

```
Backup-Msql-Database -server example.com\SQLEXPRESS -path C:\Backup -dbname "Database"
```

Backing up database `Database` from Microsoft SQL server instance at `localhost` (default parameter value) and storing it at `.\backup` (default parameter value). 

The backup process will be aborted if there is less than 10GB of available space and an email notification will be sent (there is no `disableEmailNotifications` switch specified).

The script will also allow a maximum number of `20` recent backups to become preserved instead of the default parameter value of `15`.

```
Backup-Msql-Database -dbname "Database" -minFreeSpace 10 -maxNrBackups 20
```

## License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.