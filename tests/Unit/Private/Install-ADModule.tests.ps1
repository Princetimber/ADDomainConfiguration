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

Describe 'Install-ADModule' -Tag 'Unit' {
    BeforeAll {
        Mock -ModuleName $script:dscModuleName -CommandName Write-ToLog -MockWith {}
    }

    Context 'When feature is already installed' {
        It 'Should skip installation and not call Install-WindowsFeatureWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-WindowsFeatureWrapper -MockWith {
                    [PSCustomObject]@{
                        Name         = 'AD-Domain-Services'
                        Installed    = $true
                        InstallState = 'Installed'
                    }
                }
                Mock Install-WindowsFeatureWrapper

                Install-ADModule

                Should -Invoke Get-WindowsFeatureWrapper -Times 1 -Exactly
                Should -Invoke Install-WindowsFeatureWrapper -Times 0 -Exactly
            }
        }
    }

    Context 'When feature is not installed and installation succeeds' {
        It 'Should install the feature and pass post-install verification' {
            InModuleScope -ModuleName $script:dscModuleName {
                $script:getCallCount = 0
                Mock Get-WindowsFeatureWrapper -MockWith {
                    $script:getCallCount++
                    if ($script:getCallCount -eq 1) {
                        # First call: feature not yet installed
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $false
                            InstallState = 'Available'
                        }
                    } else {
                        # Second call (verification): feature now installed
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $true
                            InstallState = 'Installed'
                        }
                    }
                }

                Mock Install-WindowsFeatureWrapper -MockWith {
                    [PSCustomObject]@{
                        Success       = $true
                        RestartNeeded = 'No'
                        FeatureResult = @()
                    }
                }

                Install-ADModule

                Should -Invoke Install-WindowsFeatureWrapper -Times 1 -Exactly
                Should -Invoke Get-WindowsFeatureWrapper -Times 2 -Exactly
            }
        }
    }

    Context 'When feature is not found on the server' {
        It 'Should throw an error indicating the feature was not found' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-WindowsFeatureWrapper -MockWith {
                    return $null
                }
                Mock Install-WindowsFeatureWrapper

                { Install-ADModule } | Should -Throw -ExpectedMessage "*not found on server*"

                Should -Invoke Install-WindowsFeatureWrapper -Times 0 -Exactly
            }
        }
    }

    Context 'When post-install verification fails' {
        It 'Should throw an error indicating verification failed' {
            InModuleScope -ModuleName $script:dscModuleName {
                $script:getCallCount = 0
                Mock Get-WindowsFeatureWrapper -MockWith {
                    $script:getCallCount++
                    if ($script:getCallCount -eq 1) {
                        # First call: feature not yet installed
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $false
                            InstallState = 'Available'
                        }
                    } else {
                        # Second call (verification): feature still not installed
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $false
                            InstallState = 'Available'
                        }
                    }
                }

                Mock Install-WindowsFeatureWrapper -MockWith {
                    [PSCustomObject]@{
                        Success       = $true
                        RestartNeeded = 'No'
                        FeatureResult = @()
                    }
                }

                { Install-ADModule } | Should -Throw -ExpectedMessage "*Post-install verification failed*"

                Should -Invoke Install-WindowsFeatureWrapper -Times 1 -Exactly
            }
        }
    }

    Context 'When using default parameter value' {
        It "Should default the Name parameter to 'AD-Domain-Services'" {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-WindowsFeatureWrapper -MockWith {
                    [PSCustomObject]@{
                        Name         = 'AD-Domain-Services'
                        Installed    = $true
                        InstallState = 'Installed'
                    }
                }

                Install-ADModule

                Should -Invoke Get-WindowsFeatureWrapper -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'AD-Domain-Services'
                }
            }
        }
    }

    Context 'When specifying a custom feature name' {
        It 'Should pass the custom name to Get-WindowsFeatureWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-WindowsFeatureWrapper -MockWith {
                    [PSCustomObject]@{
                        Name         = 'DNS'
                        Installed    = $true
                        InstallState = 'Installed'
                    }
                }

                Install-ADModule -Name 'DNS'

                Should -Invoke Get-WindowsFeatureWrapper -Times 1 -Exactly -ParameterFilter {
                    $Name -eq 'DNS'
                }
            }
        }
    }

    Context 'When installation requires a reboot' {
        It 'Should log a reboot warning when RestartNeeded is Yes' {
            InModuleScope -ModuleName $script:dscModuleName {
                $script:getCallCount = 0
                Mock Get-WindowsFeatureWrapper -MockWith {
                    $script:getCallCount++
                    if ($script:getCallCount -eq 1) {
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $false
                            InstallState = 'Available'
                        }
                    } else {
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $true
                            InstallState = 'Installed'
                        }
                    }
                }

                Mock Install-WindowsFeatureWrapper -MockWith {
                    [PSCustomObject]@{
                        Success       = $true
                        RestartNeeded = 'Yes'
                        FeatureResult = @()
                    }
                }

                Mock Write-ToLog

                Install-ADModule

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -like '*requires a system reboot*' -and $Level -eq 'WARN'
                }
            }
        }
    }

    Context 'When installation does not require a reboot' {
        It 'Should not log a reboot warning when RestartNeeded is No' {
            InModuleScope -ModuleName $script:dscModuleName {
                $script:getCallCount = 0
                Mock Get-WindowsFeatureWrapper -MockWith {
                    $script:getCallCount++
                    if ($script:getCallCount -eq 1) {
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $false
                            InstallState = 'Available'
                        }
                    } else {
                        [PSCustomObject]@{
                            Name         = 'AD-Domain-Services'
                            Installed    = $true
                            InstallState = 'Installed'
                        }
                    }
                }

                Mock Install-WindowsFeatureWrapper -MockWith {
                    [PSCustomObject]@{
                        Success       = $true
                        RestartNeeded = 'No'
                        FeatureResult = @()
                    }
                }

                Mock Write-ToLog

                Install-ADModule

                Should -Invoke Write-ToLog -Times 0 -Exactly -ParameterFilter {
                    $Message -like '*requires a system reboot*' -and $Level -eq 'WARN'
                }
            }
        }
    }
}
