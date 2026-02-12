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

Describe 'Install-ResourceModule' -Tag 'Unit' {

    BeforeEach {
        InModuleScope -ModuleName $script:dscModuleName {
            # Mock Write-ToLog to suppress all log output during tests
            Mock Write-ToLog -MockWith {}

            # Mock Get-PSResourceRepository to return a valid PSGallery by default
            Mock Get-PSResourceRepository -MockWith {
                return [PSCustomObject]@{
                    Name     = 'PSGallery'
                    Uri      = 'https://www.powershellgallery.com/api/v2'
                    Trusted  = $false
                    Priority = 50
                }
            }

            # Mock wrapper functions with safe defaults
            Mock Get-ModuleWrapper -MockWith { return $null }
            Mock Set-PSResourceRepositoryWrapper -MockWith {}
            Mock Install-PSResourceWrapper -MockWith {}
        }
    }

    Context 'When PSGallery repository is not found' {
        It 'Should throw when Get-PSResourceRepository returns null' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-PSResourceRepository -MockWith { return $null }

                { Install-ResourceModule -Name @('TestModule') } | Should -Throw -ExpectedMessage '*PSGallery not found*'
            }
        }

        It 'Should throw when Get-PSResourceRepository throws an error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-PSResourceRepository -MockWith { throw 'Repository access error' }

                { Install-ResourceModule -Name @('TestModule') } | Should -Throw
            }
        }
    }

    Context 'When module is already installed' {
        It 'Should skip installation for an already-installed module' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-ModuleWrapper -MockWith {
                    return [PSCustomObject]@{
                        Name    = 'TestModule'
                        Version = [version]'1.0.0'
                    }
                }

                Install-ResourceModule -Name @('TestModule')

                Should -Invoke Get-ModuleWrapper -Times 1 -Exactly
                Should -Invoke Install-PSResourceWrapper -Times 0 -Exactly
                Should -Invoke Set-PSResourceRepositoryWrapper -Times 1 -Exactly
            }
        }
    }

    Context 'When module is not installed and installation succeeds' {
        It 'Should install the module and verify post-install' {
            InModuleScope -ModuleName $script:dscModuleName {
                $script:getModuleCallCount = 0
                Mock Get-ModuleWrapper -MockWith {
                    $script:getModuleCallCount++
                    if ($script:getModuleCallCount -eq 1) {
                        # First call: module not installed
                        return $null
                    } else {
                        # Second call: module installed after install
                        return [PSCustomObject]@{
                            Name    = 'TestModule'
                            Version = [version]'1.0.0'
                        }
                    }
                }

                Install-ResourceModule -Name @('TestModule')

                Should -Invoke Get-ModuleWrapper -Times 2 -Exactly
                Should -Invoke Install-PSResourceWrapper -Times 1 -Exactly
            }
        }

        It 'Should set PSGallery as trusted before installing' {
            InModuleScope -ModuleName $script:dscModuleName {
                $script:getModuleCallCount = 0
                Mock Get-ModuleWrapper -MockWith {
                    $script:getModuleCallCount++
                    if ($script:getModuleCallCount -eq 1) {
                        return $null
                    } else {
                        return [PSCustomObject]@{
                            Name    = 'TestModule'
                            Version = [version]'1.0.0'
                        }
                    }
                }

                Install-ResourceModule -Name @('TestModule')

                Should -Invoke Set-PSResourceRepositoryWrapper -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'PSGallery' -and $Trusted -eq $true
                }
            }
        }
    }

    Context 'When post-install verification fails' {
        It 'Should throw when module is not found after installation' {
            InModuleScope -ModuleName $script:dscModuleName {
                # Get-ModuleWrapper always returns null (module never appears)
                Mock Get-ModuleWrapper -MockWith { return $null }

                { Install-ResourceModule -Name @('TestModule') } | Should -Throw -ExpectedMessage '*not found*'
            }
        }
    }

    Context 'When using default module names' {
        It 'Should default to SecretManagement and Az.KeyVault' {
            InModuleScope -ModuleName $script:dscModuleName {
                # All modules already installed to avoid throw
                Mock Get-ModuleWrapper -MockWith {
                    return [PSCustomObject]@{
                        Name    = $Name
                        Version = [version]'1.0.0'
                    }
                }

                Install-ResourceModule

                Should -Invoke Get-ModuleWrapper -Times 2 -Exactly
                Should -Invoke Get-ModuleWrapper -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'Microsoft.PowerShell.SecretManagement'
                }
                Should -Invoke Get-ModuleWrapper -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'Az.KeyVault'
                }
            }
        }
    }

    Context 'When accepting custom module names' {
        It 'Should accept a single custom module name' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-ModuleWrapper -MockWith {
                    return [PSCustomObject]@{
                        Name    = 'CustomModule'
                        Version = [version]'2.0.0'
                    }
                }

                Install-ResourceModule -Name @('CustomModule')

                Should -Invoke Get-ModuleWrapper -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'CustomModule'
                }
            }
        }

        It 'Should accept multiple custom module names' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-ModuleWrapper -MockWith {
                    return [PSCustomObject]@{
                        Name    = $Name
                        Version = [version]'1.0.0'
                    }
                }

                Install-ResourceModule -Name @('ModuleA', 'ModuleB', 'ModuleC')

                Should -Invoke Get-ModuleWrapper -Times 3 -Exactly
            }
        }
    }

    Context 'When handling multiple modules with mixed states' {
        It 'Should skip installed module and install missing module' {
            InModuleScope -ModuleName $script:dscModuleName {
                $mockCallTracker = @{}
                Mock Get-ModuleWrapper -MockWith {
                    if ($Name -eq 'AlreadyInstalled') {
                        return [PSCustomObject]@{
                            Name    = 'AlreadyInstalled'
                            Version = [version]'1.0.0'
                        }
                    }

                    # For NeedsInstall: first call returns null, second returns module
                    if ($Name -eq 'NeedsInstall') {
                        if (-not $mockCallTracker.ContainsKey('NeedsInstall')) {
                            $mockCallTracker['NeedsInstall'] = $true
                            return $null
                        } else {
                            return [PSCustomObject]@{
                                Name    = 'NeedsInstall'
                                Version = [version]'1.0.0'
                            }
                        }
                    }

                    return $null
                }

                Install-ResourceModule -Name @('AlreadyInstalled', 'NeedsInstall')

                # AlreadyInstalled: 1 call (check), NeedsInstall: 2 calls (check + verify)
                Should -Invoke Get-ModuleWrapper -Times 3 -Exactly
                # Only NeedsInstall should trigger installation
                Should -Invoke Install-PSResourceWrapper -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'NeedsInstall'
                }
                # Only NeedsInstall should trigger Set-PSResourceRepositoryWrapper
                Should -Invoke Set-PSResourceRepositoryWrapper -Times 1 -Exactly
            }
        }
    }

    Context 'When Install-PSResourceWrapper throws' {
        It 'Should propagate the installation error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-ModuleWrapper -MockWith { return $null }
                Mock Install-PSResourceWrapper -MockWith { throw 'Network error during install' }

                { Install-ResourceModule -Name @('FailModule') } | Should -Throw
            }
        }
    }
}
