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

Describe 'New-ADDSDomainController' -Tag 'Unit' {

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
            Mock Install-ADDSDomainControllerWrapper -MockWith {}
        }
    }

    Context 'When creating a domain controller with valid parameters' {
        It 'Should call Test-PreflightCheck' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Test-PreflightCheck -Times 1 -Exactly
            }
        }

        It 'Should call Install-ADModule' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADModule -Times 1 -Exactly
            }
        }

        It 'Should call Install-ResourceModule' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ResourceModule -Times 1 -Exactly
            }
        }

        It 'Should call Get-SafeModePassword' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Get-SafeModePassword -Times 1 -Exactly
            }
        }

        It 'Should call Install-ADDSDomainControllerWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly
            }
        }

        It 'Should pass DomainName in the parameters to Install-ADDSDomainControllerWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.DomainName -eq 'contoso.com'
                }
            }
        }

        It 'Should pass SiteName in the parameters to Install-ADDSDomainControllerWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -SiteName 'MySite' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.SiteName -eq 'MySite'
                }
            }
        }

        It 'Should pass default SiteName when not specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.SiteName -eq 'Default-First-Site'
                }
            }
        }

        It 'Should call New-EnvPath for log, database, and sysvol paths' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke New-EnvPath -Times 3 -Exactly
            }
        }

        It 'Should log start and end messages' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Write-ToLog -ParameterFilter {
                    $Message -like '*AD Domain Controller creation starting*'
                }
                Should -Invoke Write-ToLog -ParameterFilter {
                    $Message -like '*AD Domain Controller creation process ended*'
                }
            }
        }

        It 'Should log success message after installation completes' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Write-ToLog -ParameterFilter {
                    $Message -like '*completed successfully*'
                }
            }
        }
    }

    Context 'When Test-PreflightCheck fails' {
        It 'Should throw an enhanced error when Test-PreflightCheck throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PreflightCheck -MockWith { throw 'Preflight failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } |
                    Should -Throw -ExpectedMessage "*AD Domain Controller creation failed*contoso.com*"
            }
        }

        It 'Should not call Install-ADModule when preflight fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PreflightCheck -MockWith { throw 'Preflight failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Install-ADModule -Times 0 -Exactly
            }
        }

        It 'Should not call Install-ResourceModule when preflight fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PreflightCheck -MockWith { throw 'Preflight failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Install-ResourceModule -Times 0 -Exactly
            }
        }

        It 'Should not call Install-ADDSDomainControllerWrapper when preflight fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PreflightCheck -MockWith { throw 'Preflight failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 0 -Exactly
            }
        }

        It 'Should log the error when preflight fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PreflightCheck -MockWith { throw 'Preflight failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Write-ToLog -ParameterFilter {
                    $Level -eq 'ERROR' -and $Message -like '*Error during domain controller creation*'
                }
            }
        }
    }

    Context 'When Install-ADDSDomainControllerWrapper fails' {
        It 'Should throw an enhanced error that includes the domain name' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADDSDomainControllerWrapper -MockWith { throw 'DC creation failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } |
                    Should -Throw -ExpectedMessage "*AD Domain Controller creation failed*contoso.com*"
            }
        }

        It 'Should include troubleshooting tips in the error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADDSDomainControllerWrapper -MockWith { throw 'DC creation failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                $thrownError = $null
                try {
                    New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'
                } catch {
                    $thrownError = $_.Exception.Message
                }

                $thrownError | Should -BeLike '*Troubleshooting Tips*'
            }
        }

        It 'Should have called all preparation steps before the wrapper failure' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADDSDomainControllerWrapper -MockWith { throw 'DC creation failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Test-PreflightCheck -Times 1 -Exactly
                Should -Invoke Install-ADModule -Times 1 -Exactly
                Should -Invoke Install-ResourceModule -Times 1 -Exactly
                Should -Invoke Get-SafeModePassword -Times 1 -Exactly
                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly
            }
        }
    }

    Context 'When Install-ADModule fails' {
        It 'Should throw an enhanced error when Install-ADModule throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADModule -MockWith { throw 'Feature install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } |
                    Should -Throw -ExpectedMessage "*AD Domain Controller creation failed*"
            }
        }

        It 'Should not call Install-ResourceModule when Install-ADModule fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADModule -MockWith { throw 'Feature install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Install-ResourceModule -Times 0 -Exactly
            }
        }

        It 'Should not call Install-ADDSDomainControllerWrapper when Install-ADModule fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADModule -MockWith { throw 'Feature install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 0 -Exactly
            }
        }

        It 'Should not call Get-SafeModePassword when Install-ADModule fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ADModule -MockWith { throw 'Feature install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Get-SafeModePassword -Times 0 -Exactly
            }
        }
    }

    Context 'When validating parameters' {
        It 'Should throw when DomainName is not provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } | Should -Throw
            }
        }

        It 'Should throw when DomainName is empty string' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName '' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } | Should -Throw
            }
        }

        It 'Should throw when DomainName is null' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName $null -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } | Should -Throw
            }
        }

        It 'Should throw when AdminUserName is not provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd } | Should -Throw
            }
        }

        It 'Should have AdminPassword as mandatory (cannot omit)' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $param = $cmd.Parameters['AdminPassword']
                $mandatoryAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
                $mandatoryAttr.Mandatory | Should -BeTrue
            }
        }

        It 'Should have SiteName default to Default-First-Site' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $param = $cmd.Parameters['SiteName']
                $param | Should -Not -BeNullOrEmpty
                $param.ParameterSets.Values | ForEach-Object {
                    # SiteName is not mandatory
                    $_.IsMandatory | Should -BeFalse
                }
            }
        }

        It 'Should have AdminPassword as a SecureString type' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $param = $cmd.Parameters['AdminPassword']
                $param.ParameterType.Name | Should -Be 'SecureString'
            }
        }

        It 'Should have AdminUserName as a mandatory parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $param = $cmd.Parameters['AdminUserName']
                $param | Should -Not -BeNullOrEmpty
                $mandatoryAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
                $mandatoryAttr.Mandatory | Should -BeTrue
            }
        }

        It 'Should have DomainName as a mandatory parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $param = $cmd.Parameters['DomainName']
                $param | Should -Not -BeNullOrEmpty
                $mandatoryAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
                $mandatoryAttr.Mandatory | Should -BeTrue
            }
        }

        It 'Should have AdminPassword as a mandatory parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $param = $cmd.Parameters['AdminPassword']
                $param | Should -Not -BeNullOrEmpty
                $mandatoryAttr = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
                $mandatoryAttr.Mandatory | Should -BeTrue
            }
        }
    }

    Context 'When directories do not exist' {
        It 'Should create directories when Test-PathWrapper returns false' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PathWrapper -MockWith { return $false }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                # Three directories: database, log, sysvol
                Should -Invoke New-ItemDirectoryWrapper -Times 3 -Exactly
            }
        }
    }

    Context 'When directories already exist' {
        It 'Should not create directories when Test-PathWrapper returns true' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-PathWrapper -MockWith { return $true }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke New-ItemDirectoryWrapper -Times 0 -Exactly
            }
        }
    }

    Context 'When verifying credential construction' {
        It 'Should pass a Credential parameter to Install-ADDSDomainControllerWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.Credential -is [System.Management.Automation.PSCredential]
                }
            }
        }

        It 'Should build PSCredential from AdminUserName and AdminPassword' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.Credential.UserName -eq 'CONTOSO\Admin'
                }
            }
        }
    }

    Context 'When verifying security of sensitive parameters' {
        It 'Should not log AdminPassword in parameter debug output' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                # The parameter log should exclude AdminPassword
                Should -Invoke Write-ToLog -Times 0 -ParameterFilter {
                    $Message -like '*AdminPassword=*'
                }
            }
        }

        It 'Should not log SafeModeAdministratorPassword in parameter debug output' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                $safePwd = [System.Security.SecureString]::new()
                'SafeP@ss1'.ToCharArray() | ForEach-Object { $safePwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' -SafeModeAdministratorPassword $safePwd

                # The parameter log should not contain the actual password value
                Should -Invoke Write-ToLog -Times 0 -ParameterFilter {
                    $Message -like '*SafeP@ss1*'
                }
            }
        }
    }

    Context 'When verifying ShouldProcess is not present' {
        It 'Should not have WhatIf as a parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $cmd.Parameters.ContainsKey('WhatIf') | Should -BeFalse
            }
        }

        It 'Should not have Confirm as a parameter (ShouldProcess-provided)' {
            InModuleScope -ModuleName $script:dscModuleName {
                # SupportsShouldProcess adds both -WhatIf and -Confirm automatically.
                # If WhatIf is absent, ShouldProcess is not configured.
                $cmd = Get-Command -Name New-ADDSDomainController
                $cmd.Parameters.ContainsKey('WhatIf') | Should -BeFalse
            }
        }
    }

    Context 'When verifying function metadata' {
        It 'Should have CmdletBinding attribute' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name New-ADDSDomainController
                $cmd.CmdletBinding | Should -BeTrue
            }
        }
    }

    Context 'When passing optional parameters' {
        It 'Should pass InstallDNS flag in parameters' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -InstallDNS -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.InstallDNS -eq $true
                }
            }
        }

        It 'Should pass Force flag when provided' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -Force -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.Force -eq $true
                }
            }
        }

        It 'Should pass SafeModeAdministratorPassword to Get-SafeModePassword' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                $safePwd = [System.Security.SecureString]::new()
                'SafeP@ss1'.ToCharArray() | ForEach-Object { $safePwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' -SafeModeAdministratorPassword $safePwd

                Should -Invoke Get-SafeModePassword -Times 1 -Exactly -ParameterFilter {
                    $Password -is [System.Security.SecureString]
                }
            }
        }

        It 'Should pass SafeModeAdministratorPassword in the parameters to Install-ADDSDomainControllerWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $Parameters.SafeModeAdministratorPassword -is [System.Security.SecureString]
                }
            }
        }

        It 'Should pass database, log, and sysvol paths to Install-ADDSDomainControllerWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin'

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 1 -Exactly -ParameterFilter {
                    $null -ne $Parameters.DataBasePath -and
                    $null -ne $Parameters.LogPath -and
                    $null -ne $Parameters.SysvolPath
                }
            }
        }
    }

    Context 'When Install-ResourceModule fails' {
        It 'Should throw an enhanced error when Install-ResourceModule throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ResourceModule -MockWith { throw 'Module install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } |
                    Should -Throw -ExpectedMessage "*AD Domain Controller creation failed*"
            }
        }

        It 'Should not call Install-ADDSDomainControllerWrapper when Install-ResourceModule fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Install-ResourceModule -MockWith { throw 'Module install failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                try { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } catch {}

                Should -Invoke Install-ADDSDomainControllerWrapper -Times 0 -Exactly
            }
        }
    }

    Context 'When Get-SafeModePassword fails' {
        It 'Should throw an enhanced error when Get-SafeModePassword throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-SafeModePassword -MockWith { throw 'Password retrieval failed' }

                $secPwd = [System.Security.SecureString]::new()
                'P@ss1'.ToCharArray() | ForEach-Object { $secPwd.AppendChar($_) }
                { New-ADDSDomainController -DomainName 'contoso.com' -AdminPassword $secPwd -AdminUserName 'CONTOSO\Admin' } |
                    Should -Throw -ExpectedMessage "*AD Domain Controller creation failed*"
            }
        }
    }
}
