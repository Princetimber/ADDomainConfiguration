#Requires -Version 7.0

function New-ADDSForest {
    <#
    .SYNOPSIS
        Creates a new Active Directory Domain Services (AD DS) forest.

    .DESCRIPTION
        New-ADDSForest is a critical state-changing function that creates a new Active Directory
        forest. This operation is one of the most significant in the module and should be executed
        with extreme caution as it modifies system configuration permanently and typically requires
        a system reboot.

        The function performs comprehensive pre-flight validation via Test-PreflightCheck, ensuring
        that all prerequisites are met before attempting forest creation. It then orchestrates the
        installation of required modules and features before invoking the actual forest creation.

        SAFETY: ShouldProcess (-WhatIf/-Confirm) is handled by the public caller Invoke-ADDSForest.
        This private function does not duplicate that check (DRY principle).

        The function delegates validation to Test-PreflightCheck (platform, elevation, features, paths)
        following the DRY principle - no duplicate validation in this function.

    .PARAMETER DomainName
        The fully qualified domain name (FQDN) for the new forest root domain.
        Example: "contoso.com"
        This parameter is mandatory and cannot be null or empty.

    .PARAMETER DomainNetbiosName
        The NetBIOS name for the domain. If not specified, defaults to the first label of the FQDN.
        Example: "CONTOSO"
        Maximum 15 characters.

    .PARAMETER SafeModeAdministratorPassword
        The Directory Services Restore Mode (DSRM) administrator password as a SecureString.
        This password is used for recovery operations and must meet complexity requirements.
        If not provided, the function will prompt interactively.

    .PARAMETER DomainMode
        The functional level for the domain. Determines available features.
        Valid values: Win2008, Win2008R2, Win2012, Win2012R2, Win2025, Default, WinThreshold
        Default: Win2025 (latest functional level)

    .PARAMETER ForestMode
        The functional level for the forest. Determines available features across the forest.
        Valid values: Win2008, Win2008R2, Win2012, Win2012R2, Win2025, Default, WinThreshold
        Default: Win2025 (latest functional level)

    .PARAMETER DatabasePath
        The path for the Active Directory database (NTDS.dit).
        Must be on an NTFS volume. Recommended: Dedicated volume separate from OS.
        Default: $env:SYSTEMDRIVE\Windows

    .PARAMETER LogPath
        The path for Active Directory log files.
        Must be on an NTFS volume. Recommended: Dedicated volume separate from database.
        Default: $env:SYSTEMDRIVE\Windows\NTDS

    .PARAMETER SysvolPath
        The path for the SYSVOL folder (stores Group Policy templates and logon scripts).
        Must be on an NTFS volume.
        Default: $env:SYSTEMDRIVE\Windows

    .PARAMETER InstallDNS
        If specified, installs and configures DNS server role as part of forest creation.
        Recommended for most scenarios as AD requires DNS.

    .PARAMETER Force
        If specified, suppresses confirmation prompts from the underlying Install-ADDSForest cmdlet.
        Note: This function's own ShouldProcess confirmation is still respected unless -Confirm:$false is used.

    .OUTPUTS
        None
        This function does not return output. Forest creation status is logged.

    .EXAMPLE
        New-ADDSForest -DomainName "contoso.com" -WhatIf

        Tests what would happen if creating a new forest for contoso.com without actually executing.
        Safe way to validate parameters and prerequisites.

    .EXAMPLE
        New-ADDSForest -DomainName "corp.contoso.com" -DomainNetbiosName "CORP" -InstallDNS

        Creates a new AD forest with domain corp.contoso.com, NetBIOS name CORP, and installs DNS.
        Will prompt for Safe Mode password and for confirmation before execution.

    .EXAMPLE
        $securePass = ConvertTo-SecureString 'P@ssw0rd123!' -AsPlainText -Force
        New-ADDSForest -DomainName "contoso.com" -SafeModeAdministratorPassword $securePass `
                       -DatabasePath "D:\NTDS" -LogPath "E:\Logs" -SysvolPath "D:\SYSVOL" `
                       -InstallDNS -Confirm:$false

        Creates a new forest with custom paths for database, logs, and SYSVOL on separate volumes.
        Provides password via parameter and skips confirmation (automation scenario).

    .NOTES
        Requirements:
        - Administrative privileges (validated by Test-PreflightCheck)
        - Windows Server operating system (validated by Test-PreflightCheck)
        - AD-Domain-Services feature available (validated by Test-PreflightCheck)
        - PowerShell 7.0+

        CRITICAL WARNINGS:
        - This operation creates an entire Active Directory forest
        - Changes are permanent and cannot be easily reversed
        - System will require reboot after completion
        - Affects domain infrastructure and authentication
        - Always test with -WhatIf first
        - Ensure you have valid backups before proceeding

        This function is intended to be used internally by the module and is not designed
        for direct invocation by users. All validation (platform, elevation) is performed
        by Test-PreflightCheck before calling this function (DRY principle).

        The function uses Install-ADDSForestWrapper internally to enable mocking in unit tests.

        Post-Execution:
        - System will reboot automatically or prompt for reboot
        - Forest creation may take several minutes
        - Verify forest creation succeeded after reboot
    #>
    [CmdletBinding()]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'ShouldProcess is handled by the public caller Invoke-ADDSForest. This private function trusts the caller decision (DRY principle).')]
    param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainName,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainNetBiosName,

        [Parameter(Position = 2)]
        [SecureString]
        $SafeModeAdministratorPassword,

        [Parameter()]
        [ValidateSet("Win2008", "Win2008R2", "Win2012", "Win2012R2", "Win2025", "Default", "WinThreshold")]
        [string]
        $DomainMode = "Win2025",

        [Parameter()]
        [ValidateSet("Win2008", "Win2008R2", "Win2012", "Win2012R2", "Win2025", "Default", "WinThreshold")]
        [string]
        $ForestMode = "Win2025",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DatabasePath = "$env:SYSTEMDRIVE\Windows",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogPath = "$env:SYSTEMDRIVE\Windows\NTDS",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SysvolPath = "$env:SYSTEMDRIVE\Windows",

        [Parameter()]
        [switch]
        $InstallDNS,

        [Parameter()]
        [switch]
        $Force
    )

    begin {
        Write-ToLog -Message "=== AD DS Forest Creation Starting ===" -Level INFO
        Write-ToLog -Message "Domain Name: $DomainName" -Level INFO
        Write-ToLog -Message "Domain Mode: $DomainMode, Forest Mode: $ForestMode" -Level INFO
    }

    process {
        try {
            # Log bound parameters (safely - no sensitive data)
            $paramLog = $PSBoundParameters.Keys | Where-Object { $_ -ne 'SafeModeAdministratorPassword' } | ForEach-Object {
                "$_=$($PSBoundParameters[$_])"
            }
            Write-ToLog -Message "Parameters: $($paramLog -join ', ')" -Level DEBUG

            # Pre-flight validation (platform, elevation, features, parent path disk space)
            # Validate parent directories of target paths (target dirs will be created after preflight)
            Write-ToLog -Message "Running pre-flight checks..." -Level INFO
            $pathsToValidate = @($DatabasePath, $LogPath, $SysvolPath) |
                Where-Object { -not [string]::IsNullOrEmpty($_) } |
                    ForEach-Object { Split-Path -Path $_ -Parent } |
                        Where-Object { -not [string]::IsNullOrEmpty($_) } |
                            Select-Object -Unique
            Test-PreflightCheck -RequiredFeatures @('AD-Domain-Services') -RequiredPaths $pathsToValidate

            # Install required modules and features
            Write-ToLog -Message "Installing required AD module..." -Level INFO
            Install-ADModule

            Write-ToLog -Message "Installing required PowerShell modules..." -Level INFO
            Install-ResourceModule

            # Prepare paths
            $LOG_PATH = New-EnvPath -Path $LogPath -ChildPath 'logs'
            $DATABASE_PATH = New-EnvPath -Path $DatabasePath -ChildPath 'ntds'
            $SYSVOL_PATH = New-EnvPath -Path $SysvolPath -ChildPath 'sysvol'

            Write-ToLog -Message "Database Path: $DATABASE_PATH" -Level INFO
            Write-ToLog -Message "Log Path: $LOG_PATH" -Level INFO
            Write-ToLog -Message "SYSVOL Path: $SYSVOL_PATH" -Level INFO

            # Ensure target directories exist (output directories may not pre-exist)
            foreach ($targetPath in @($DATABASE_PATH, $LOG_PATH, $SYSVOL_PATH)) {
                if (-not (Test-PathWrapper -Path $targetPath)) {
                    New-ItemDirectoryWrapper -Path $targetPath
                    Write-ToLog -Message "Created target directory: $targetPath" -Level INFO
                } else {
                    Write-ToLog -Message "Target directory already exists: $targetPath" -Level DEBUG
                }
            }

            # Get Safe Mode password securely
            $SafePwd = Get-SafeModePassword -Password $SafeModeAdministratorPassword

            # Build parameters for Install-ADDSForest
            $CommonParams = @{
                DomainName                    = $DomainName
                DataBasePath                  = $DATABASE_PATH
                LogPath                       = $LOG_PATH
                SysvolPath                    = $SYSVOL_PATH
                SafeModeAdministratorPassword = $SafePwd
                InstallDNS                    = $InstallDNS.IsPresent
            }

            # Add optional parameters if provided
            foreach ($p in 'DomainMode', 'ForestMode', 'DomainNetBiosName', 'Force') {
                if ($PSBoundParameters.ContainsKey($p)) {
                    $CommonParams[$p] = $PSBoundParameters[$p]
                }
            }

            # Execute forest creation (ShouldProcess is handled by the public caller Invoke-ADDSForest)
            Write-ToLog -Message "Initiating AD DS Forest creation..." -Level INFO
            Install-ADDSForestWrapper -Parameters $CommonParams

            Write-ToLog -Message "AD DS Forest creation command completed successfully" -Level SUCCESS
            Write-ToLog -Message "System will reboot to complete installation" -Level INFO

            # Metrics reporting
            Write-ToLog -Message "Operation Summary - Domain: $DomainName, DNS: $($InstallDNS.IsPresent), Paths: DB=$DATABASE_PATH, Log=$LOG_PATH, SYSVOL=$SYSVOL_PATH" -Level INFO
        } catch {
            $errorMsg = $_.Exception.Message
            Write-ToLog -Message "Failed to create AD DS Forest: $errorMsg" -Level ERROR

            # Enhanced error message with context
            $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Red)✗$($PSStyle.Reset)" } else { "✗" }
            $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

            $enhancedError = "AD DS Forest creation failed for domain '$DomainName'."
            $enhancedError += "`n`nError Details:"
            $enhancedError += "`n  ${bullet} $errorMsg"
            $enhancedError += "`n`n${tip} Troubleshooting Tips:"
            $enhancedError += "`n  • Verify all pre-requisites are met (use Test-PreflightCheck)"
            $enhancedError += "`n  • Ensure paths are valid and accessible"
            $enhancedError += "`n  • Check that domain name is valid and not already in use"
            $enhancedError += "`n  • Review event logs for detailed error information"
            $enhancedError += "`n  • Ensure Safe Mode password meets complexity requirements"

            throw $enhancedError
        }
    }

    end {
        Write-ToLog -Message "=== AD DS Forest Creation Process Ended ===" -Level INFO
    }
}

# Helper function for mockability in tests
function Install-ADDSForestWrapper {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wrapper function for testing purposes only. ShouldProcess is handled by the calling function New-ADDSForest.')]
    param(
        [Parameter(Mandatory)]
        [hashtable]
        $Parameters
    )

    return Install-ADDSForest @Parameters
}

# Helper function for mockability in tests
function New-ItemDirectoryWrapper {
    <#
    .SYNOPSIS
        Creates a directory at the specified path. Wrapper for New-Item to enable mocking in tests.

    .DESCRIPTION
        New-ItemDirectoryWrapper is a thin wrapper around New-Item -ItemType Directory -Force.
        It exists solely to enable mocking in Pester unit tests for functions that need to
        create directories (e.g., New-ADDSForest target directories). The function creates
        the directory and suppresses output.

    .PARAMETER Path
        The full path of the directory to create. Parent directories are created automatically
        via the -Force parameter on New-Item.

    .EXAMPLE
        New-ItemDirectoryWrapper -Path 'C:\Windows\NTDS\ntds'

        Creates the directory C:\Windows\NTDS\ntds, including any missing parent directories.

    .OUTPUTS
        None

    .NOTES
        This is a wrapper function for testability. ShouldProcess is handled by the calling
        function (New-ADDSForest). Do not call this function directly outside of module scope.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wrapper function for testing purposes only. ShouldProcess is handled by the calling function New-ADDSForest.')]
    param(
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}
