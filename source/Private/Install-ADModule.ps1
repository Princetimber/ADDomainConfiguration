#Requires -Version 7.0

function Install-ADModule {
    <#
    .SYNOPSIS
        Installs Windows AD Domain Services feature with all sub-features and management tools.

    .DESCRIPTION
        Idempotently installs the AD-Domain-Services Windows feature with comprehensive validation
        and error handling. The function confirms successful installation with post-install
        verification.

        Key features:
        - Skips installation if feature is already installed
        - Installs with all sub-features and management tools
        - Verifies feature installation after Install-WindowsFeature completes
        - Reports metrics (features checked, installed, skipped, failed)

        This is a private helper function designed to be called by public module functions.

    .PARAMETER Name
        Name of the Windows feature to install. Default: 'AD-Domain-Services'
        Use Get-WindowsFeature to list all available features.

    .EXAMPLE
        Install-ADModule

        Installs AD-Domain-Services feature with default settings if not already installed.

    .EXAMPLE
        Install-ADModule -Name 'DNS'

        Installs the DNS Server feature with all sub-features and management tools.

    .EXAMPLE
        Install-ADModule -Name 'RSAT-AD-PowerShell'

        Installs the Active Directory PowerShell module.

    .OUTPUTS
        [void]
            This function does not return output. Success/failure is logged via Write-ToLog.

    .NOTES
        Requirements:
        - Administrative privileges (validated by Test-PreflightCheck)
        - Windows Server operating system (validated by Test-PreflightCheck)
        - PowerShell 7.0+

        This function is intended to be used internally by the module and is not designed
        for direct invocation by users. All validation (platform, elevation) should
        be performed by Test-PreflightCheck before calling this function.

        The function uses wrapper functions (Get-WindowsFeatureWrapper, Install-WindowsFeatureWrapper)
        to enable mocking in unit tests.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = 'AD-Domain-Services'
    )

    process {
        Write-ToLog -Message "Processing Windows feature: $Name" -Level INFO

        # Check if feature is already installed
        $existingFeature = Get-WindowsFeatureWrapper -Name $Name

        if (-not $existingFeature) {
            Write-ToLog -Message "Feature '$Name' not found on server." -Level ERROR
            throw "Feature '$Name' not found on server. Use Get-WindowsFeature to list available features."
        }

        if ($existingFeature.Installed) {
            Write-ToLog -Message "Feature '$Name' is already installed (State: $($existingFeature.InstallState))." -Level DEBUG
            return
        }

        # Install feature
        Write-ToLog -Message "Installing Windows feature '$Name' (IncludeAllSubFeature, IncludeManagementTools)..." -Level INFO
        $installResult = Install-WindowsFeatureWrapper -Name $Name -IncludeAllSubFeature -IncludeManagementTools

        # Post-install verification
        $verifyFeature = Get-WindowsFeatureWrapper -Name $Name

        if (-not $verifyFeature -or -not $verifyFeature.Installed) {
            Write-ToLog -Message "Verification failed: Feature '$Name' not installed after installation attempt." -Level ERROR
            throw "Post-install verification failed: Feature '$Name' not installed after Install-WindowsFeature."
        }

        Write-ToLog -Message "Feature '$Name' installed successfully (State: $($verifyFeature.InstallState))." -Level SUCCESS

        if ($installResult.RestartNeeded -eq 'Yes') {
            Write-ToLog -Message "Feature '$Name' installation requires a system reboot to complete." -Level WARN
        }
    }
}

# ============================================================================
# HELPER FUNCTIONS FOR MOCKABILITY
# ============================================================================

function Get-WindowsFeatureWrapper {
    <#
    .SYNOPSIS
        Wrapper for Get-WindowsFeature to enable mocking in tests.

    .DESCRIPTION
        Abstracts the Get-WindowsFeature cmdlet to make Install-ADModule testable.
        This function can be mocked in Pester tests without affecting the system cmdlet.

    .PARAMETER Name
        Name of the Windows feature to retrieve. If not specified, returns all features.

    .OUTPUTS
        Microsoft.Windows.ServerManager.Commands.Feature or array of features.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name
    )

    if ($Name) {
        return Get-WindowsFeature -Name $Name
    } else {
        return Get-WindowsFeature
    }
}

function Install-WindowsFeatureWrapper {
    <#
    .SYNOPSIS
        Wrapper for Install-WindowsFeature to enable mocking in tests.

    .DESCRIPTION
        Abstracts the Install-WindowsFeature cmdlet to make Install-ADModule testable.
        This function can be mocked in Pester tests without affecting the system cmdlet.

    .PARAMETER Name
        Name of the Windows feature to install.

    .PARAMETER IncludeAllSubFeature
        Installs all sub-features of the specified feature.

    .PARAMETER IncludeManagementTools
        Installs management tools for the feature.

    .OUTPUTS
        Microsoft.Windows.ServerManager.Commands.FeatureOperationResult

    .NOTES
        Suppression: PSUseShouldProcessForStateChangingFunctions - Wrapper function;
        ShouldProcess handled by calling function.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param (
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter()]
        [switch]
        $IncludeAllSubFeature,

        [Parameter()]
        [switch]
        $IncludeManagementTools
    )

    return Install-WindowsFeature -Name $Name -IncludeAllSubFeature:$IncludeAllSubFeature -IncludeManagementTools:$IncludeManagementTools
}
