#Requires -Version 7.0

function New-EnvPath {
    <#
    .SYNOPSIS
        Joins a base path and a child path into a single file system path.

    .DESCRIPTION
        New-EnvPath is a simple utility function that wraps PowerShell's Join-Path cmdlet
        to combine a base directory path with a child path component. This function provides
        a consistent interface for path joining operations within the module.

        The function is a pure utility wrapper and does not modify the file system or create
        directories. It simply constructs the path string using platform-appropriate path
        separators.

    .PARAMETER Path
        The base directory path. This is typically the root or parent directory.
        Cannot be null or empty.

    .PARAMETER ChildPath
        The child path component to append to the base path. This can be a file name,
        subdirectory, or relative path. Cannot be null or empty.

    .OUTPUTS
        System.String
        Returns a combined path string with platform-appropriate path separators.

    .EXAMPLE
        New-EnvPath -Path 'C:\Program Files' -ChildPath 'MyApp'

        Returns: C:\Program Files\MyApp

        Combines a Windows base path with a child directory name.

    .EXAMPLE
        New-EnvPath -Path '/usr/local' -ChildPath 'bin/myapp'

        Returns: /usr/local/bin/myapp

        Combines a Unix-style base path with a relative child path containing subdirectories.

    .EXAMPLE
        $configPath = New-EnvPath -Path $env:ProgramData -ChildPath 'MyModule\config.json'

        Combines an environment variable path with a nested child path to construct a
        configuration file location.

    .NOTES
        Requirements:
        - PowerShell 7.0+

        This function is intended to be used internally by the module and provides a
        consistent, testable interface for path operations.

        ScriptAnalyzer Suppression: PSUseShouldProcessForStateChangingFunctions is suppressed
        because despite the "New" verb, this function does not change system state - it only
        constructs and returns a path string. The "New" verb is appropriate for creating a
        new string object, not a file system resource.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Function does not change system state; only constructs a path string. The "New" verb creates a string object, not a file system resource.')]
    param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ChildPath
    )

    try {
        return Join-Path -Path $Path -ChildPath $ChildPath
    } catch {
        throw "Failed to join paths '$Path' and '$ChildPath': $($_.Exception.Message)"
    }
}