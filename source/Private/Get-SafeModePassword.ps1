#Requires -Version 7.0

function Get-SafeModePassword {
    <#
    .SYNOPSIS
        Retrieves the Safe Mode Administrator password securely.

    .DESCRIPTION
        Get-SafeModePassword is a security-sensitive helper function that obtains the
        Directory Services Restore Mode (DSRM) / Safe Mode Administrator password. The
        password can be provided via parameter or obtained through a secure interactive
        prompt.

        The function uses SecureString throughout to ensure the password is never exposed
        in plaintext. When prompting interactively, Read-Host -AsSecureString is used to
        prevent the password from being displayed on screen or captured in transcripts.

        Security Note: This function logs the action of obtaining the password but NEVER
        logs the password value itself. All password handling uses SecureString to maintain
        security best practices.

    .PARAMETER Password
        The Safe Mode Administrator password as a SecureString. If provided, this password
        is returned immediately without prompting the user. If not provided, the function
        will prompt the user interactively for the password.

    .OUTPUTS
        System.Security.SecureString
        Returns the Safe Mode Administrator password as a SecureString. The password is
        never exposed in plaintext.

    .EXAMPLE
        $password = Get-SafeModePassword

        Prompts the user interactively for the Safe Mode Administrator password and returns
        it as a SecureString.

    .EXAMPLE
        $securePass = ConvertTo-SecureString 'P@ssw0rd123!' -AsPlainText -Force
        $password = Get-SafeModePassword -Password $securePass

        Uses a pre-existing SecureString password without prompting the user. Useful for
        automation scenarios where the password is retrieved from a secure vault or
        credential store.

    .EXAMPLE
        $cred = Get-Credential -UserName 'SafeModeAdmin' -Message 'Enter Safe Mode password'
        $password = Get-SafeModePassword -Password $cred.Password

        Obtains the password from a PSCredential object and passes it to the function,
        avoiding an interactive prompt.

    .NOTES
        Requirements:
        - PowerShell 7.0+

        Security Considerations:
        - This function handles sensitive credentials and follows security best practices:
          - Uses SecureString exclusively (never plaintext)
          - Prompts securely with Read-Host -AsSecureString
          - Logs actions only, NEVER logs password values
          - Returns SecureString to prevent accidental exposure

        - When automating, retrieve passwords from secure sources:
          - Azure Key Vault
          - Microsoft.PowerShell.SecretManagement
          - Credential Manager
          - Never hardcode passwords in scripts

        This function is intended to be used internally by the module for obtaining the
        Safe Mode Administrator password required during domain controller promotion.

        The function uses Read-HostWrapper internally to enable mocking in unit tests.
    #>
    [CmdletBinding()]
    [OutputType([SecureString])]
    param (
        [Parameter(Position = 0)]
        [SecureString]
        $Password
    )

    if ($Password) {
        Write-ToLog -Message "Safe Mode password provided via parameter (secure)" -Level DEBUG
        return $Password
    }

    Write-ToLog -Message "Prompting user for Safe Mode Administrator password" -Level INFO

    try {
        $securePassword = Read-HostWrapper -Prompt "Enter Safe Mode Administrator password" -AsSecureString

        if (-not $securePassword) {
            throw "Safe Mode password cannot be empty"
        }

        Write-ToLog -Message "Safe Mode password obtained from interactive prompt (secure)" -Level DEBUG
        return $securePassword
    } catch {
        Write-ToLog -Message "Failed to obtain Safe Mode password: $($_.Exception.Message)" -Level ERROR
        throw "Failed to obtain Safe Mode Administrator password. User may have cancelled the operation or provided invalid input."
    }
}

# Helper function for mockability in tests
function Read-HostWrapper {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingReadHost', '',
        Justification = 'Wrapper function for Read-Host to enable mocking in unit tests. Read-Host is required for secure password prompts.')]
    param(
        [Parameter(Mandatory)]
        [string]
        $Prompt,

        [Parameter()]
        [switch]
        $AsSecureString
    )

    return Read-Host -Prompt $Prompt -AsSecureString:$AsSecureString
}