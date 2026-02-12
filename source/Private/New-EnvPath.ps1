#Requires -Version 7.0

function New-EnvPath {
    <#
    .SYNOPSIS
        Joins a base path and a child path into a single file system path.

    .DESCRIPTION
        Wraps Join-Path to provide a consistent, testable interface for path operations
        within the module. Does not modify the file system.

    .PARAMETER Path
        The base directory path.

    .PARAMETER ChildPath
        The child path component to append.

    .OUTPUTS
        System.String

    .EXAMPLE
        New-EnvPath -Path 'C:\Windows' -ChildPath 'NTDS'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Does not change system state; only constructs a path string.')]
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

    return Join-Path -Path $Path -ChildPath $ChildPath
}
