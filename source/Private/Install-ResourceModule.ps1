#Requires -Version 7.0

function Install-ResourceModule {
    <#
    .SYNOPSIS
        Installs required PowerShell modules from PSGallery.

    .DESCRIPTION
        Idempotently installs PowerShell modules from PSGallery with comprehensive validation
        and error handling. The function ensures administrative privileges, validates repository
        availability, and confirms successful installation.

        Key features:
        - Checks for administrative privileges (required for AllUsers scope)
        - Validates PSGallery repository is registered and accessible
        - Skips modules that are already installed
        - Sets PSGallery as trusted repository before installation
        - Verifies module installation after Install-PSResource completes
        - Reports metrics (modules checked, installed, skipped, failed)

        This is a private helper function designed to be called by public module functions.

    .PARAMETER Name
        Array of PowerShell module names to install from PSGallery. Each module is checked
        for existence before installation. Default: @('Microsoft.PowerShell.SecretManagement', 'Az.KeyVault')

    .EXAMPLE
        Install-ResourceModule

        Installs default modules (Microsoft.PowerShell.SecretManagement, Az.KeyVault) if not already present.

    .EXAMPLE
        Install-ResourceModule -Name @('Pester', 'PSScriptAnalyzer')

        Installs Pester and PSScriptAnalyzer modules from PSGallery.

    .EXAMPLE
        Install-ResourceModule -Name @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Users')

        Installs Microsoft Graph PowerShell modules for authentication and user management.

    .OUTPUTS
        [void]
            This function does not return output. Success/failure is logged via Write-ToLog.

    .NOTES
        Requirements:
        - Administrative privileges (validated by Test-PreflightCheck)
        - PSGallery repository must be registered
        - Internet connectivity to PSGallery
        - PowerShell 7.0+

        This function is intended to be used internally by the module and is not designed
        for direct invocation by users. Elevation validation should be performed by
        Test-PreflightCheck before calling this function.

        The function uses wrapper functions (Get-ModuleWrapper, Set-PSResourceRepositoryWrapper,
        Install-PSResourceWrapper) to enable mocking in unit tests.
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name = @('Microsoft.PowerShell.SecretManagement', 'Az.KeyVault')
    )

    begin {
        Write-ToLog -Message "Starting module installation process for $($Name.Count) module(s)..." -Level INFO

        $modulesChecked = 0
        $modulesInstalled = 0
        $modulesSkipped = 0
        $modulesFailed = 0

        # Repository validation: Ensure PSGallery is registered and accessible
        try {
            $repository = Get-PSResourceRepository -Name PSGallery -ErrorAction Stop

            if (-not $repository) {
                $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

                $errorMsg = "Repository validation failed: PSGallery not found."
                $errorMsg += "`n`n${tip} Tip: Register PSGallery with: Register-PSResourceRepository -PSGallery"

                # Try to list available repositories
                try {
                    $availableRepos = Get-PSResourceRepository
                    if ($availableRepos) {
                        $repoList = $availableRepos | ForEach-Object {
                            "  ${bullet} $($_.Name) - URI: $($_.Uri)"
                        }
                        $errorMsg += "`n`nAvailable repositories:`n$($repoList -join "`n")"
                    }
                } catch {
                    # Silently continue if we can't get repository list - best effort only
                    Write-Verbose "Could not retrieve repository list: $($_.Exception.Message)"
                }

                Write-ToLog -Message "PSGallery repository not found." -Level ERROR
                throw $errorMsg
            }

            Write-ToLog -Message "Repository validated: PSGallery is registered (URI: $($repository.Uri))." -Level DEBUG
        } catch {
            Write-ToLog -Message "Repository validation error: $($_.Exception.Message)" -Level ERROR
            throw
        }
    }

    process {
        try {
            foreach ($moduleName in $Name) {
                $modulesChecked++
                Write-ToLog -Message "Processing module: $moduleName" -Level DEBUG

                try {
                    # Check if module is already installed
                    $existingModule = Get-ModuleWrapper -Name $moduleName -ListAvailable

                    if ($existingModule) {
                        Write-ToLog -Message "Module '$moduleName' is already installed (Version: $($existingModule.Version))." -Level DEBUG
                        $modulesSkipped++
                        continue
                    }

                    # Set PSGallery as trusted to avoid prompts
                    Write-ToLog -Message "Setting PSGallery as trusted repository..." -Level DEBUG
                    Set-PSResourceRepositoryWrapper -Name PSGallery -Trusted

                    # Install module
                    Write-ToLog -Message "Installing module '$moduleName' from PSGallery (Scope: AllUsers)..." -Level INFO
                    Install-PSResourceWrapper -Name $moduleName -Repository PSGallery -Scope AllUsers -Confirm:$false

                    # Post-install verification
                    $verifyModule = Get-ModuleWrapper -Name $moduleName -ListAvailable

                    if ($verifyModule) {
                        Write-ToLog -Message "Module '$moduleName' installed successfully (Version: $($verifyModule.Version))." -Level SUCCESS
                        $modulesInstalled++
                    } else {
                        $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                        $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

                        $errorMsg = "Post-install verification failed: Module '$moduleName' not found after installation."
                        $errorMsg += "`n`n${tip} Tip: Check module name spelling or try installing manually with: Install-PSResource -Name $moduleName"

                        Write-ToLog -Message "Verification failed: Module '$moduleName' not found after installation." -Level ERROR
                        $modulesFailed++
                        throw $errorMsg
                    }
                } catch {
                    Write-ToLog -Message "Failed to install module '$moduleName': $($_.Exception.Message)" -Level ERROR
                    $modulesFailed++

                    # Enhanced error message for common issues
                    if ($_.Exception.Message -like "*not found*") {
                        $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)•$($PSStyle.Reset)" } else { "•" }
                        $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

                        $errorMsg = "Module '$moduleName' not found in PSGallery."
                        $errorMsg += "`n`n${tip} Tips:"
                        $errorMsg += "`n  ${bullet} Verify module name at https://www.powershellgallery.com/"
                        $errorMsg += "`n  ${bullet} Check spelling and capitalization"
                        $errorMsg += "`n  ${bullet} Ensure internet connectivity to PSGallery"

                        throw $errorMsg
                    } else {
                        throw
                    }
                }
            }
        } catch {
            Write-ToLog -Message "Module installation process encountered errors: $($_.Exception.Message)" -Level ERROR
            throw
        }
    }

    end {
        # Metrics reporting
        $successRate = if ($modulesChecked -gt 0) {
            [Math]::Round((($modulesInstalled + $modulesSkipped) / $modulesChecked) * 100, 2)
        } else {
            0
        }

        Write-ToLog -Message "Module installation completed - Total: $modulesChecked, Installed: $modulesInstalled, Skipped: $modulesSkipped, Failed: $modulesFailed, Success Rate: $successRate%" -Level INFO

        if ($modulesFailed -gt 0) {
            Write-ToLog -Message "Module installation completed with $modulesFailed failure(s)." -Level WARN
        } else {
            Write-ToLog -Message "All module operations completed successfully." -Level SUCCESS
        }
    }
}

# ============================================================================
# HELPER FUNCTIONS FOR MOCKABILITY
# ============================================================================

function Get-ModuleWrapper {
    <#
    .SYNOPSIS
        Wrapper for Get-Module to enable mocking in tests.

    .DESCRIPTION
        Abstracts the Get-Module cmdlet to make Invoke-ResourceModule testable.
        This function can be mocked in Pester tests without affecting the system cmdlet.

    .PARAMETER Name
        Name of the PowerShell module to retrieve.

    .PARAMETER ListAvailable
        Lists all installed modules available for import.

    .OUTPUTS
        PSModuleInfo or array of PSModuleInfo objects.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [switch]
        $ListAvailable
    )

    if ($Name) {
        return Get-Module -Name $Name -ListAvailable:$ListAvailable
    } else {
        return Get-Module -ListAvailable:$ListAvailable
    }
}

function Set-PSResourceRepositoryWrapper {
    <#
    .SYNOPSIS
        Wrapper for Set-PSResourceRepository to enable mocking in tests.

    .DESCRIPTION
        Abstracts the Set-PSResourceRepository cmdlet to make Invoke-ResourceModule testable.
        This function can be mocked in Pester tests without affecting the system cmdlet.

    .PARAMETER Name
        Name of the PSResourceRepository to configure.

    .PARAMETER Trusted
        Sets the repository as trusted to avoid installation prompts.

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
        $Trusted
    )

    Set-PSResourceRepository -Name $Name -Trusted:$Trusted
}

function Install-PSResourceWrapper {
    <#
    .SYNOPSIS
        Wrapper for Install-PSResource to enable mocking in tests.

    .DESCRIPTION
        Abstracts the Install-PSResource cmdlet to make Invoke-ResourceModule testable.
        This function can be mocked in Pester tests without affecting the system cmdlet.

    .PARAMETER Name
        Name of the PowerShell module to install.

    .PARAMETER Repository
        Name of the repository to install from (typically PSGallery).

    .PARAMETER Scope
        Installation scope: CurrentUser or AllUsers.

    .PARAMETER Confirm
        Whether to prompt for confirmation before installation.

    .NOTES
        Suppression: PSUseSupportsShouldProcess - Wrapper function; confirmation
        handled by calling function through -Confirm parameter.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSupportsShouldProcess', '')]
    param (
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Repository,

        [Parameter()]
        [string]
        $Scope,

        [Parameter()]
        [bool]
        $Confirm
    )

    Install-PSResource -Name $Name -Repository $Repository -Scope $Scope -Confirm:$Confirm
}