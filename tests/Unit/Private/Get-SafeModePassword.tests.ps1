#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-ADDSForest'

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', '..', 'source'
    $manifestPath = Join-Path -Path $sourcePath -ChildPath "$script:dscModuleName.psd1"

    Import-Module -Name $manifestPath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Get-SafeModePassword' -Tag 'Unit' {

    Context 'When password is provided via parameter' {
        It 'Should return the provided password directly' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog

                $testPassword = [System.Security.SecureString]::new()
                'TestPass'.ToCharArray() | ForEach-Object { $testPassword.AppendChar($_) }
                $result = Get-SafeModePassword -Password $testPassword

                $result | Should -Be $testPassword
            }
        }

        It 'Should return a SecureString type' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog

                $testPassword = [System.Security.SecureString]::new()
                'SecureTest'.ToCharArray() | ForEach-Object { $testPassword.AppendChar($_) }
                $result = Get-SafeModePassword -Password $testPassword

                $result | Should -BeOfType [SecureString]
            }
        }

        It 'Should log a DEBUG message when password is provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog

                $testPassword = [System.Security.SecureString]::new()
                'LogTest'.ToCharArray() | ForEach-Object { $testPassword.AppendChar($_) }
                Get-SafeModePassword -Password $testPassword

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Safe Mode password provided via parameter (secure)' -and $Level -eq 'DEBUG'
                }
            }
        }

        It 'Should not call Read-HostWrapper when password is provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Read-HostWrapper

                $testPassword = [System.Security.SecureString]::new()
                'NoPrompt'.ToCharArray() | ForEach-Object { $testPassword.AppendChar($_) }
                Get-SafeModePassword -Password $testPassword

                Should -Invoke Read-HostWrapper -Times 0 -Exactly
            }
        }
    }

    Context 'When no password is provided and interactive prompt succeeds' {
        It 'Should call Read-HostWrapper to prompt the user' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $mockPassword = [System.Security.SecureString]::new()
                'PromptedPass'.ToCharArray() | ForEach-Object { $mockPassword.AppendChar($_) }
                Mock Read-HostWrapper { return $mockPassword }

                Get-SafeModePassword

                Should -Invoke Read-HostWrapper -Times 1 -Exactly -ParameterFilter {
                    $Prompt -eq 'Enter Safe Mode Administrator password' -and $AsSecureString -eq $true
                }
            }
        }

        It 'Should return the password from the interactive prompt' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $mockPassword = [System.Security.SecureString]::new()
                'InteractivePass'.ToCharArray() | ForEach-Object { $mockPassword.AppendChar($_) }
                Mock Read-HostWrapper { return $mockPassword }

                $result = Get-SafeModePassword

                $result | Should -Be $mockPassword
            }
        }

        It 'Should return a SecureString type from interactive prompt' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $mockPassword = [System.Security.SecureString]::new()
                'TypeCheck'.ToCharArray() | ForEach-Object { $mockPassword.AppendChar($_) }
                Mock Read-HostWrapper { return $mockPassword }

                $result = Get-SafeModePassword

                $result | Should -BeOfType [SecureString]
            }
        }

        It 'Should log INFO before prompting and DEBUG after obtaining password' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $mockPassword = [System.Security.SecureString]::new()
                'LogCheck'.ToCharArray() | ForEach-Object { $mockPassword.AppendChar($_) }
                Mock Read-HostWrapper { return $mockPassword }

                Get-SafeModePassword

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Prompting user for Safe Mode Administrator password' -and $Level -eq 'INFO'
                }
                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Safe Mode password obtained from interactive prompt (secure)' -and $Level -eq 'DEBUG'
                }
            }
        }
    }

    Context 'When Read-HostWrapper returns null or empty' {
        It 'Should throw when Read-HostWrapper returns null' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Read-HostWrapper { return $null }

                { Get-SafeModePassword } | Should -Throw '*Failed to obtain Safe Mode Administrator password*'
            }
        }
    }

    Context 'When Read-HostWrapper throws an exception' {
        It 'Should throw a meaningful error message' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Read-HostWrapper { throw 'User cancelled the prompt' }

                { Get-SafeModePassword } | Should -Throw '*Failed to obtain Safe Mode Administrator password*'
            }
        }

        It 'Should log an ERROR when the prompt fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Read-HostWrapper { throw 'Simulated prompt failure' }

                try { Get-SafeModePassword } catch { $null = $_ <# Expected error in test #> }

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'ERROR' -and $Message -like 'Failed to obtain Safe Mode password:*'
                }
            }
        }

        It 'Should include guidance about cancellation or invalid input in the error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Read-HostWrapper { throw 'Simulated failure' }

                { Get-SafeModePassword } | Should -Throw '*cancelled the operation or provided invalid input*'
            }
        }
    }
}
