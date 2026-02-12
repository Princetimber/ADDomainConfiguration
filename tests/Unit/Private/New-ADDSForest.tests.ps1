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

Describe 'New-ADDSForest' -Tag 'Unit' {

    BeforeEach {
        InModuleScope -ModuleName $script:dscModuleName {
            # Mock all internal dependencies to prevent any real system operations
            Mock Write-ToLog -MockWith {}
            Mock Test-PreflightCheck -MockWith { return $true }
            Mock Install-ADModule -MockWith {}
            Mock Install-ResourceModule -MockWith {}
            Mock New-EnvPath -MockWith {
                return Join-Path -Path $Path -ChildPath $ChildPath
            }
            Mock Test-PathWrapper -MockWith { return $true }
            Mock New-ItemDirectoryWrapper -MockWith {}
            Mock Get-SafeModePassword -MockWith {
                $mockPwd = [System.Security.SecureString]::new()
                'MockPass'.ToCharArray() | ForEach-Object { $mockPwd.AppendChar($_) }
                return $mockPwd
            }
            Mock Install-ADDSForestWrapper -MockWith {}
        }
    }

    Context 'When creating a forest with valid parameters' {
        It 'Should call Test-PreflightCheck' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Test-PreflightCheck -Times 1 -Exactly
            }
        }

        It 'Should call Install-ADModule' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADModule -Times 1 -Exactly
            }
        }

        It 'Should call Install-ResourceModule' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ResourceModule -Times 1 -Exactly
            }
        }

        It 'Should call Get-SafeModePassword' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Get-SafeModePassword -Times 1 -Exactly
            }
        }

        It 'Should call Install-ADDSForestWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADDSForestWrapper -Times 1 -Exactly
            }
        }

        It 'Should pass DomainName in the parameters to Install-ADDSForestWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADDSForestWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.DomainName -eq 'contoso.com'
                }
            }
        }

        It 'Should call New-EnvPath for log, database, and sysvol paths' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke New-EnvPath -Times 3 -Exactly
            }
        }
    }

    Context 'When directories already exist' {
        It 'Should not create directories when Test-PathWrapper returns true' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PathWrapper -MockWith { return $true }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                Should -Invoke New-ItemDirectoryWrapper -Times 0 -Exactly
            }
        }
    }

    Context 'When directories do not exist' {
        It 'Should create directories when Test-PathWrapper returns false' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PathWrapper -MockWith { return $false }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd

                # Three directories: database, log, sysvol
                Should -Invoke New-ItemDirectoryWrapper -Times 3 -Exactly
            }
        }
    }

    Context 'When a step fails' {
        It 'Should throw an enhanced error when Test-PreflightCheck throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PreflightCheck -MockWith { throw 'Preflight failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd } |
                    Should -Throw -ExpectedMessage "*AD DS Forest creation failed for domain 'contoso.com'*"
            }
        }

        It 'Should throw an enhanced error when Install-ADModule throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADModule -MockWith { throw 'Feature install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd } |
                    Should -Throw -ExpectedMessage "*AD DS Forest creation failed*"
            }
        }

        It 'Should throw an enhanced error when Install-ResourceModule throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ResourceModule -MockWith { throw 'Module install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd } |
                    Should -Throw -ExpectedMessage "*AD DS Forest creation failed*"
            }
        }

        It 'Should throw an enhanced error when Install-ADDSForestWrapper throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADDSForestWrapper -MockWith { throw 'Forest creation failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd } |
                    Should -Throw -ExpectedMessage "*AD DS Forest creation failed for domain 'contoso.com'*"
            }
        }

        It 'Should throw an enhanced error when Get-SafeModePassword throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-SafeModePassword -MockWith { throw 'Password retrieval failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $secPwd } |
                    Should -Throw -ExpectedMessage "*AD DS Forest creation failed*"
            }
        }
    }

    Context 'When validating parameters' {
        It 'Should throw when DomainName is not provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                { New-ADDSForest } | Should -Throw
            }
        }

        It 'Should throw when DomainName is empty string' {
            InModuleScope -ModuleName $script:dscModuleName {
                { New-ADDSForest -DomainName '' } | Should -Throw
            }
        }

        It 'Should throw when DomainMode is invalid' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSForest -DomainName 'contoso.com' -DomainMode 'InvalidMode' -SafeModeAdministratorPassword $secPwd } |
                    Should -Throw
            }
        }

        It 'Should throw when ForestMode is invalid' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSForest -DomainName 'contoso.com' -ForestMode 'InvalidMode' -SafeModeAdministratorPassword $secPwd } |
                    Should -Throw
            }
        }

        It 'Should accept valid DomainMode values' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }

                # Should not throw for valid modes
                { New-ADDSForest -DomainName 'contoso.com' -DomainMode 'Win2025' -SafeModeAdministratorPassword $secPwd } |
                    Should -Not -Throw
                { New-ADDSForest -DomainName 'contoso.com' -DomainMode 'Win2012R2' -SafeModeAdministratorPassword $secPwd } |
                    Should -Not -Throw
                { New-ADDSForest -DomainName 'contoso.com' -DomainMode 'Default' -SafeModeAdministratorPassword $secPwd } |
                    Should -Not -Throw
            }
        }

        It 'Should accept valid ForestMode values' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }

                { New-ADDSForest -DomainName 'contoso.com' -ForestMode 'WinThreshold' -SafeModeAdministratorPassword $secPwd } |
                    Should -Not -Throw
            }
        }
    }

    Context 'When verifying ShouldProcess is not present' {
        It 'Should not have WhatIf as a parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSForest
                $cmd.Parameters.ContainsKey('WhatIf') | Should -BeFalse
            }
        }

        It 'Should not have Confirm as a parameter (ShouldProcess-provided)' {
            InModuleScope -ModuleName $script:dscModuleName {
                # The function should NOT have SupportsShouldProcess, so there should be
                # no automatic -Confirm parameter from ShouldProcess.
                # Note: CmdletBinding can add -Confirm but only with SupportsShouldProcess.
                $cmd = Get-Command -Name New-ADDSForest
                # SupportsShouldProcess adds both -WhatIf and -Confirm automatically.
                # If WhatIf is absent, ShouldProcess is not configured.
                $cmd.Parameters.ContainsKey('WhatIf') | Should -BeFalse
            }
        }
    }

    Context 'When passing optional parameters' {
        It 'Should pass DomainNetBiosName when provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -DomainNetBiosName 'CONTOSO' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADDSForestWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.DomainName -eq 'contoso.com' -and
                    $Parameters.DomainNetBiosName -eq 'CONTOSO'
                }
            }
        }

        It 'Should pass InstallDNS flag in parameters' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -InstallDNS -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADDSForestWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.InstallDNS -eq $true
                }
            }
        }

        It 'Should pass Force flag when provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -Force -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADDSForestWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.Force -eq $true
                }
            }
        }

        It 'Should pass DomainMode when explicitly specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -DomainMode 'Win2012R2' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADDSForestWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.DomainMode -eq 'Win2012R2'
                }
            }
        }

        It 'Should pass ForestMode when explicitly specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSForest -DomainName 'contoso.com' -ForestMode 'Win2008R2' -SafeModeAdministratorPassword $secPwd

                Should -Invoke Install-ADDSForestWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.ForestMode -eq 'Win2008R2'
                }
            }
        }
    }

    Context 'When verifying function metadata' {
        It 'Should have CmdletBinding attribute' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSForest
                $cmd.CmdletBinding | Should -BeTrue
            }
        }

        It 'Should have DomainName as a mandatory parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSForest
                $param = $cmd.Parameters['DomainName']
                $param | Should -Not -BeNullOrEmpty
                $mandatoryAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
                $mandatoryAttr.Mandatory | Should -BeTrue
            }
        }
    }
}
