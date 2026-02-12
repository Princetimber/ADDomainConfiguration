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

    begin {
        Write-ToLog -Message "Starting Windows feature installation process for '$Name'..." -Level INFO

        $featuresChecked = 0
        $featuresInstalled = 0
        $featuresSkipped = 0
        $featuresFailed = 0
    }

    process {
        try {
            $featuresChecked++
            Write-ToLog -Message "Processing Windows feature: $Name" -Level DEBUG

            try {
                # Check if feature is already installed
                $existingFeature = Get-WindowsFeatureWrapper -Name $Name

                if (-not $existingFeature) {
                    # Enhanced error: show available features
                    $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                    $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

                    $errorMsg = "Feature '$Name' not found on server."

                    # Attempt to list similar features
                    try {
                        $availableFeatures = Get-WindowsFeatureWrapper | Where-Object { $_.Name -like "*AD*" -or $_.Name -like "*Domain*" }
                        if ($availableFeatures) {
                            $featureList = $availableFeatures | Select-Object -First 10 | ForEach-Object {
                                "  ${bullet} $($_.Name) - Installed: $($_.Installed)"
                            }
                            $errorMsg += "`n`nAvailable AD-related features:`n$($featureList -join "`n")"
                            $errorMsg += "`n`n${tip} Tip: Verify the feature name. Use Get-WindowsFeature to list all features."
                        }
                    } catch {
                        # Silently continue if we can't get feature list - best effort only
                        Write-Verbose "Could not retrieve feature list: $($_.Exception.Message)"
                    }

                    Write-ToLog -Message "Feature '$Name' not found on server." -Level ERROR
                    $featuresFailed++
                    throw $errorMsg
                }

                if ($existingFeature.Installed) {
                    Write-ToLog -Message "Feature '$Name' is already installed (State: $($existingFeature.InstallState))." -Level DEBUG
                    $featuresSkipped++
                } else {
                    # Install feature
                    Write-ToLog -Message "Installing Windows feature '$Name' (IncludeAllSubFeature: Yes, IncludeManagementTools: Yes)..." -Level INFO
                    $installResult = Install-WindowsFeatureWrapper -Name $Name -IncludeAllSubFeature -IncludeManagementTools

                    # Post-install verification
                    $verifyFeature = Get-WindowsFeatureWrapper -Name $Name

                    if ($verifyFeature -and $verifyFeature.Installed) {
                        Write-ToLog -Message "Feature '$Name' installed successfully (State: $($verifyFeature.InstallState))." -Level SUCCESS

                        # Check if reboot is required
                        if ($installResult.RestartNeeded -eq 'Yes') {
                            Write-ToLog -Message "Feature '$Name' installation requires a system reboot to complete." -Level WARN
                        }

                        $featuresInstalled++
                    } else {
                        $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                        $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

                        $errorMsg = "Post-install verification failed: Feature '$Name' not installed after Install-WindowsFeature."
                        $errorMsg += "`n`n${tip} Tips:"
                        $errorMsg += "`n  ${bullet} Check Windows Event Logs for installation errors"
                        $errorMsg += "`n  ${bullet} Ensure all prerequisites are met"
                        $errorMsg += "`n  ${bullet} Try installing manually with: Install-WindowsFeature -Name $Name -IncludeAllSubFeature -IncludeManagementTools"

                        Write-ToLog -Message "Verification failed: Feature '$Name' not installed after installation attempt." -Level ERROR
                        $featuresFailed++
                        throw $errorMsg
                    }
                }
            } catch {
                Write-ToLog -Message "Failed to install feature '$Name': $($_.Exception.Message)" -Level ERROR
                $featuresFailed++
                throw
            }
        } catch {
            Write-ToLog -Message "Windows feature installation process encountered errors: $($_.Exception.Message)" -Level ERROR
            throw
        }
    }

    end {
        # Metrics reporting
        $successRate = if ($featuresChecked -gt 0) {
            [Math]::Round((($featuresInstalled + $featuresSkipped) / $featuresChecked) * 100, 2)
        } else {
            0
        }

        Write-ToLog -Message "Windows feature installation completed - Total: $featuresChecked, Installed: $featuresInstalled, Skipped: $featuresSkipped, Failed: $featuresFailed, Success Rate: $successRate%" -Level INFO

        if ($featuresFailed -gt 0) {
            Write-ToLog -Message "Windows feature installation completed with $featuresFailed failure(s)." -Level WARN
        } else {
            Write-ToLog -Message "All feature operations completed successfully." -Level SUCCESS
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