#Requires -Version 7.0




function Test-IfPathExistOrNot {
    <#
.SYNOPSIS
    Validates that all provided file system paths exist.

.DESCRIPTION
    Test-IfPathExistOrNot is a validation helper function that verifies the existence
    of one or more file system paths. Unlike fail-fast validation, this function uses
    batch validation to collect ALL missing paths before throwing an error, providing
    complete feedback in a single operation.

    The function logs each path validation attempt and provides detailed error messages
    showing which paths are missing and which exist (for context). This approach improves
    the user experience by allowing all path issues to be identified and resolved at once
    rather than requiring multiple iterations.

    This function is intended to be called early in module operations to ensure all
    required paths are available before proceeding with state-changing operations.

.PARAMETER Paths
    An array of file system paths to validate. Each path will be checked for existence.
    Cannot be null or empty. Paths can be files, directories, or other file system objects.

.OUTPUTS
    None
    The function throws a terminating error if any paths are missing, or completes silently
    if all paths exist.

.EXAMPLE
    Test-IfPathExistOrNot -Paths 'C:\Windows\System32'

    Validates that the System32 directory exists. Throws if the path doesn't exist.

.EXAMPLE
    Test-IfPathExistOrNot -Paths @('C:\Program Files', 'C:\Users', 'C:\Windows')

    Validates multiple critical Windows directories. If any are missing, all missing
    paths will be reported in a single error message.

.EXAMPLE
    $requiredPaths = @(
        'C:\ProgramData\MyApp\config.json',
        'C:\ProgramData\MyApp\logs',
        'C:\ProgramData\MyApp\data'
    )
    Test-IfPathExistOrNot -Paths $requiredPaths

    Validates that all required application paths exist before proceeding with operations.
    Uses batch validation to report all missing paths at once for efficient troubleshooting.

.NOTES
    Requirements:
    - PowerShell 7.0+

    This function is intended to be used internally by the module for validation purposes.
    It performs batch validation, collecting all missing paths before throwing, which provides
    better user experience than failing on the first missing path.

    The function uses Test-PathWrapper internally to enable mocking in unit tests.
#>

    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Paths
    )

    begin {
        Write-ToLog -Message "Starting path validation for $($Paths.Count) path(s)" -Level INFO
    }

    process {
        $missingPaths = @()
        $existingPaths = @()

        # Batch validation: collect all results before throwing
        foreach ($Path in $Paths) {
            try {
                if (Test-PathWrapper -Path $Path) {
                    Write-ToLog -Message "Path verified: $Path" -Level DEBUG
                    $existingPaths += $Path
                } else {
                    Write-ToLog -Message "Path not found: $Path" -Level ERROR
                    $missingPaths += $Path
                }
            } catch {
                Write-ToLog -Message "Error checking path '$Path': $($_.Exception.Message)" -Level ERROR
                $missingPaths += $Path
            }
        }

        # Report metrics
        $totalCount = $Paths.Count
        $existCount = $existingPaths.Count
        $missingCount = $missingPaths.Count
        $successRate = if ($totalCount -gt 0) { [Math]::Round(($existCount / $totalCount) * 100, 2) } else { 0 }

        Write-ToLog -Message "Path validation complete - Total: $totalCount, Exist: $existCount, Missing: $missingCount, Success Rate: $successRate%" -Level INFO

        # If any paths are missing, throw with full context
        if ($missingCount -gt 0) {
            $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Red)✗$($PSStyle.Reset)" } else { "✗" }
            $checkmark = if ($PSStyle) { "$($PSStyle.Foreground.Green)✓$($PSStyle.Reset)" } else { "✓" }
            $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }

            $errorMsg = "Path validation failed: $missingCount of $totalCount path(s) not found."

            # List missing paths
            $missingList = $missingPaths | ForEach-Object {
                "  ${bullet} $_"
            }
            $errorMsg += "`n`nMissing paths:`n$($missingList -join "`n")"

            # Show existing paths for context (if any)
            if ($existCount -gt 0) {
                $existingList = $existingPaths | ForEach-Object {
                    "  ${checkmark} $_"
                }
                $errorMsg += "`n`nExisting paths (for context):`n$($existingList -join "`n")"
            }

            # Add actionable tip
            $errorMsg += "`n`n${tip} Tip: Verify that the missing paths are correct and that the file system is accessible."

            throw $errorMsg
        }

        Write-ToLog -Message "All $totalCount path(s) validated successfully" -Level SUCCESS
    }
}

# Helper function for mockability in tests
function Test-PathWrapper {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wrapper function for testing purposes only; does not change state. Only queries path existence.')]
    param(
        [Parameter(Mandatory)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $PathType
    )

    if ($PathType) {
        return Test-Path -Path $Path -PathType $PathType
    } else {
        return Test-Path -Path $Path
    }
}