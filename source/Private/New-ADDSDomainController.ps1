#Requires -Version 7.0

function New-ADDSDomainController {
    <#
    .SYNOPSIS
        Promotes a member server to a domain controller in an existing AD DS domain.

    .DESCRIPTION
        New-ADDSDomainController is a critical state-changing function that promotes a member server
        to a domain controller in an existing Active Directory domain. This operation is significant
        and should be executed with extreme caution as it modifies system configuration permanently
        and typically requires a system reboot.

        The function performs comprehensive pre-flight validation via Test-PreflightCheck, ensuring
        that all prerequisites are met before attempting domain controller promotion. It then
        orchestrates the installation of required modules and features before invoking the actual
        domain controller installation.

        SAFETY: ShouldProcess (-WhatIf/-Confirm) is handled by the public caller Invoke-ADDSDomainController.
        This private function does not duplicate that check (DRY principle).

        The function delegates validation to Test-PreflightCheck (platform, elevation, features, paths)
        following the DRY principle - no duplicate validation in this function.

    .PARAMETER DomainName
        The fully qualified domain name (FQDN) of the existing domain to join as a domain controller.
        Example: "contoso.com"
        This parameter is mandatory and cannot be null or empty.

    .PARAMETER SiteName
        The Active Directory site in which to place the new domain controller.
        Default: "Default-First-Site"
        This should match an existing AD site name.

    .PARAMETER AdminPassword
        The domain administrator password as a SecureString. Used together with AdminUserName
        to create a PSCredential for authenticating the domain controller promotion.

    .PARAMETER AdminUserName
        The domain administrator username in DOMAIN\User format.
        Example: "CONTOSO\Administrator"
        This parameter is mandatory and cannot be null or empty.

    .PARAMETER SafeModeAdministratorPassword
        The Directory Services Restore Mode (DSRM) administrator password as a SecureString.
        This password is used for recovery operations and must meet complexity requirements.
        If not provided, the function will prompt interactively via Get-SafeModePassword.

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
        If specified, installs and configures DNS server role as part of domain controller promotion.
        Recommended for most scenarios as AD requires DNS.

    .PARAMETER Force
        If specified, suppresses confirmation prompts from the underlying Install-ADDSDomainController cmdlet.
        Note: This function's own ShouldProcess confirmation is still respected unless -Confirm:$false is used.

    .OUTPUTS
        None
        This function does not return output. Domain controller promotion status is logged.

    .EXAMPLE
        New-ADDSDomainController -DomainName "contoso.com" -AdminUserName "CONTOSO\Administrator" -AdminPassword $securePass

        Promotes the server to a domain controller in the contoso.com domain using the specified credentials.
        Will prompt for Safe Mode password interactively.

    .EXAMPLE
        $adminPwd = ConvertTo-SecureString 'P@ssw0rd123!' -AsPlainText -Force
        $safePwd = ConvertTo-SecureString 'S@feM0de!' -AsPlainText -Force
        New-ADDSDomainController -DomainName "contoso.com" -AdminUserName "CONTOSO\Administrator" `
                                 -AdminPassword $adminPwd -SafeModeAdministratorPassword $safePwd -InstallDNS

        Promotes the server to a domain controller with DNS installation, providing all passwords via parameters.

    .EXAMPLE
        New-ADDSDomainController -DomainName "corp.contoso.com" -SiteName "BranchOffice" `
                                 -AdminUserName "CORP\Administrator" -AdminPassword $adminPwd `
                                 -DatabasePath "D:\NTDS" -LogPath "E:\Logs" -SysvolPath "D:\SYSVOL" `
                                 -InstallDNS -Force

        Promotes the server in the BranchOffice site with custom paths for database, logs, and SYSVOL
        on separate volumes. Suppresses confirmation prompts (automation scenario).

    .NOTES
        Requirements:
        - Administrative privileges (validated by Test-PreflightCheck)
        - Windows Server operating system (validated by Test-PreflightCheck)
        - AD-Domain-Services feature available (validated by Test-PreflightCheck)
        - PowerShell 7.0+

        CRITICAL WARNINGS:
        - This operation promotes a server to a domain controller in an existing domain
        - Changes are permanent and cannot be easily reversed
        - System will require reboot after completion
        - Affects domain infrastructure and authentication
        - Ensure you have valid backups before proceeding

        This function is intended to be used internally by the module and is not designed
        for direct invocation by users. All validation (platform, elevation) is performed
        by Test-PreflightCheck before calling this function (DRY principle).

        The function uses Install-ADDSDomainControllerWrapper internally to enable mocking in unit tests.

        Post-Execution:
        - System will reboot automatically or prompt for reboot
        - Domain controller promotion may take several minutes
        - Verify domain controller promotion succeeded after reboot
    #>
    [CmdletBinding()]
    [OutputType([void])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'ShouldProcess is handled by the public caller Invoke-ADDSForest. This private function trusts the caller decision (DRY principle).')]
    param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteName = "Default-First-Site",

        [Parameter(Position = 2, Mandatory)]
        [securestring]$AdminPassword,

        [Parameter(Position = 3, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AdminUserName,

        [Parameter(Position = 4)]
        [SecureString]
        $SafeModeAdministratorPassword,

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
        Write-ToLog -Message "===== AD Domain Controller creation starting =====" -Level INFO
        Write-ToLog -Message "Domain Name: $DomainName" -Level INFO
        Write-ToLog -Message "Site Name: $SiteName" -Level INFO
    }

    process {
        try {
            # Log bound parameters (Safely - no sensitive data)
            $paramLog = $PSBoundParameters.Keys | Where-Object { $_ -notin @('AdminPassword', 'SafeModeAdministratorPassword') } | ForEach-Object {
                "$_=$($PSBoundParameters[$_])"
            }
            Write-Tolog -Message "Parameters: $($paramLog -join ', ')" -Level DEBUG

            #Pre-flight validation (Platform, Elevation, features, parent path disk space etc.)
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

            #Create PSCredential object for domain admin (required by Install-ADDSDomainController)
            $DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($AdminUserName, $AdminPassword)

            # Get Safe Mode password securely
            $SafePwd = Get-SafeModePassword -Password $SafeModeAdministratorPassword

            # Build parameters to install domain controller
            $CommonParams = @{
                DomainName                    = $DomainName
                SiteName                      = $SiteName
                Credential                    = $DomainCredential
                SafeModeAdministratorPassword = $SafePwd
                InstallDNS                    = $InstallDNS.IsPresent
                DataBasePath                  = $DATABASE_PATH
                LogPath                       = $LOG_PATH
                SysvolPath                    = $SYSVOL_PATH
            }

            # add optional parameters if provided
            if ($PSBoundParameters.ContainsKey('Force')) {
                $CommonParams['Force'] = $PSBoundParameters['Force']
            }

            # Execute domain controller installation
            Write-ToLog -Message "Starting domain controller installation..." -Level INFO
            Install-ADDSDomainControllerWrapper -Parameters $CommonParams

            Write-ToLog -Message "Domain controller installation completed successfully." -Level INFO
            Write-ToLog -Message "The server will reboot automatically if the installation was successful." -Level INFO

            # Metrics reporting
            Write-ToLog -Message "Operation Summary: Domain Controller '$DomainName' created in site '$SiteName' with DNS: $($InstallDNS.IsPresent)" -Level INFO
        } catch {
            $errorMsg = $_.Exception.Message
            Write-ToLog -Message "Error during domain controller creation: $errorMsg" -Level ERROR

            # Enhanced error message with contextual information
            $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Red)✗$($PSStyle.Reset)" } else { "✗" }
            $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

            $enhancedError = "AD Domain Controller creation failed for the domain $($DomainName)."
            $enhancedError += "`n Error Details:"
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
        Write-ToLog -Message "===== AD Domain Controller creation process ended =====" -Level INFO
    }
}

# Helper function for mockability in tests
function Install-ADDSDomainControllerWrapper {
    <#
    .SYNOPSIS
        Wrapper for Install-ADDSDomainController to enable mocking in Pester tests.

    .DESCRIPTION
        Install-ADDSDomainControllerWrapper is a thin wrapper around the Install-ADDSDomainController
        cmdlet. It exists solely to enable mocking in Pester unit tests for New-ADDSDomainController.
        The function accepts a hashtable of parameters and splats them to the underlying cmdlet.

    .PARAMETER Parameters
        A hashtable containing the parameters to pass to Install-ADDSDomainController via splatting.
        Expected keys include: DomainName, SiteName, Credential, SafeModeAdministratorPassword,
        InstallDNS, DataBasePath, LogPath, SysvolPath, and optionally Force.

    .OUTPUTS
        None
        This function does not return output. The underlying cmdlet handles domain controller promotion.

    .NOTES
        This is a wrapper function for testability. ShouldProcess is handled by the calling
        function chain (Invoke-ADDSDomainController -> New-ADDSDomainController).
        Do not call this function directly outside of module scope.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wrapper function for testing purposes only. ShouldProcess is handled by the calling function New-ADDSDomainController.')]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )
    Install-ADDSDomainController @Parameters
}
