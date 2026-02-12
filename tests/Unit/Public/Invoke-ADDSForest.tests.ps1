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

Describe 'Invoke-ADDSForest' -Tag 'Unit' {

    BeforeAll {
        # Mock Write-ToLog globally to suppress all logging output
        Mock -ModuleName $script:dscModuleName -CommandName Write-ToLog -MockWith {}
        # Mock the private New-ADDSForest so no real AD operations happen
        Mock -ModuleName $script:dscModuleName -CommandName New-ADDSForest -MockWith {}
    }

    Context 'Parameter validation' {

        It 'Should throw when DomainName is null' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Invoke-ADDSForest -DomainName $null -Confirm:$false } | Should -Throw
            }
        }

        It 'Should throw when DomainName is empty string' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Invoke-ADDSForest -DomainName '' -Confirm:$false } | Should -Throw
            }
        }

        It 'Should throw when DomainMode is invalid' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Invoke-ADDSForest -DomainName 'contoso.com' -DomainMode 'Invalid' -Confirm:$false } | Should -Throw
            }
        }

        It 'Should throw when ForestMode is invalid' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Invoke-ADDSForest -DomainName 'contoso.com' -ForestMode 'Invalid' -Confirm:$false } | Should -Throw
            }
        }

        It 'Should accept valid DomainMode values' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $validModes = @('Win2008', 'Win2008R2', 'Win2012', 'Win2012R2', 'Win2025', 'Default', 'WinThreshold')
                foreach ($mode in $validModes) {
                    { Invoke-ADDSForest -DomainName 'contoso.com' -DomainMode $mode -Confirm:$false } | Should -Not -Throw
                }
            }
        }

        It 'Should accept valid ForestMode values' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $validModes = @('Win2008', 'Win2008R2', 'Win2012', 'Win2012R2', 'Win2025', 'Default', 'WinThreshold')
                foreach ($mode in $validModes) {
                    { Invoke-ADDSForest -DomainName 'contoso.com' -ForestMode $mode -Confirm:$false } | Should -Not -Throw
                }
            }
        }
    }

    Context 'SupportsShouldProcess' {

        It 'Should have SupportsShouldProcess attribute' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name Invoke-ADDSForest
                $cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
                $cmd.Parameters.ContainsKey('Confirm') | Should -BeTrue
            }
        }

        It 'Should not call New-ADDSForest when -WhatIf is specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -WhatIf

                Should -Invoke New-ADDSForest -Times 0 -Exactly
            }
        }
    }

    Context 'When calling New-ADDSForest with basic parameters' {

        It 'Should call New-ADDSForest with DomainName, DomainMode, and ForestMode' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $DomainMode -eq 'Win2025' -and
                    $ForestMode -eq 'Win2025'
                }
            }
        }
    }

    Context 'When calling New-ADDSForest with optional parameters' {

        It 'Should pass DomainNetBiosName when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -DomainNetBiosName 'CONTOSO' -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $DomainNetBiosName -eq 'CONTOSO'
                }
            }
        }

        It 'Should pass SafeModeAdministratorPassword when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $securePass = [System.Security.SecureString]::new()
                'TestPass'.ToCharArray() | ForEach-Object { $securePass.AppendChar($_) }
                Invoke-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $securePass -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $null -ne $SafeModeAdministratorPassword
                }
            }
        }

        It 'Should pass DatabasePath when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -DatabasePath 'D:\NTDS' -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $DatabasePath -eq 'D:\NTDS'
                }
            }
        }

        It 'Should pass SysvolPath when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -SysvolPath 'D:\SYSVOL' -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $SysvolPath -eq 'D:\SYSVOL'
                }
            }
        }

        It 'Should pass LogPath when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -LogPath 'E:\Logs' -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $LogPath -eq 'E:\Logs'
                }
            }
        }

        It 'Should pass custom DomainMode and ForestMode when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -DomainMode 'Win2012R2' -ForestMode 'Win2012' -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $DomainMode -eq 'Win2012R2' -and
                    $ForestMode -eq 'Win2012'
                }
            }
        }
    }

    Context 'When InstallDNS switch is specified' {

        It 'Should pass InstallDNS to New-ADDSForest' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -InstallDNS -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $InstallDNS -eq $true
                }
            }
        }

        It 'Should not pass InstallDNS when switch is not specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    (-not $InstallDNS)
                }
            }
        }
    }

    Context 'When Force switch is specified' {

        It 'Should pass Force to New-ADDSForest' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -Force -Confirm:$false

                Should -Invoke New-ADDSForest -Times 1 -Exactly -ParameterFilter {
                    $DomainName -eq 'contoso.com' -and
                    $Force -eq $true
                }
            }
        }

        It 'Should log a warning when Force is specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -Force -Confirm:$false

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Force specified - suppressing confirmation prompts' -and
                    $Level -eq 'WARN'
                }
            }
        }
    }

    Context 'When PassThru is specified' {

        It 'Should return a PSCustomObject' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -PassThru -Confirm:$false

                $result | Should -BeOfType [PSCustomObject]
            }
        }

        It 'Should return object with correct DomainName' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -PassThru -Confirm:$false

                $result.DomainName | Should -Be 'contoso.com'
            }
        }

        It 'Should return object with correct ForestMode and DomainMode defaults' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -PassThru -Confirm:$false

                $result.ForestMode | Should -Be 'Win2025'
                $result.DomainMode | Should -Be 'Win2025'
            }
        }

        It 'Should return object with Status of Completed' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -PassThru -Confirm:$false

                $result.Status | Should -Be 'Completed'
            }
        }

        It 'Should return object with Timestamp' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -PassThru -Confirm:$false

                $result.Timestamp | Should -BeOfType [datetime]
            }
        }

        It 'Should return object with InstallDNS reflecting the switch state' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $resultWithDns = Invoke-ADDSForest -DomainName 'contoso.com' -InstallDNS -PassThru -Confirm:$false
                $resultWithoutDns = Invoke-ADDSForest -DomainName 'contoso.com' -PassThru -Confirm:$false

                $resultWithDns.InstallDNS | Should -BeTrue
                $resultWithoutDns.InstallDNS | Should -BeFalse
            }
        }

        It 'Should default DomainNetBiosName from FQDN when not specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -PassThru -Confirm:$false

                $result.DomainNetBiosName | Should -Be 'CONTOSO'
            }
        }

        It 'Should use provided DomainNetBiosName when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -DomainNetBiosName 'MYNETBIOS' -PassThru -Confirm:$false

                $result.DomainNetBiosName | Should -Be 'MYNETBIOS'
            }
        }

        It 'Should return object with custom DomainMode and ForestMode when specified' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -DomainMode 'Win2012R2' -ForestMode 'Win2012' -PassThru -Confirm:$false

                $result.DomainMode | Should -Be 'Win2012R2'
                $result.ForestMode | Should -Be 'Win2012'
            }
        }
    }

    Context 'When PassThru is not specified' {

        It 'Should not return any output' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $result = Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false

                $result | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Error handling' {

        It 'Should throw an enhanced error message when New-ADDSForest fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith { throw 'Simulated AD DS failure' }
                Mock Write-ToLog -MockWith {}

                { Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false } |
                    Should -Throw -ExpectedMessage "*Failed to create AD DS forest 'contoso.com'*"
            }
        }

        It 'Should log the error when New-ADDSForest fails' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith { throw 'Simulated AD DS failure' }
                Mock Write-ToLog -MockWith {}

                try {
                    Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false
                } catch {
                    $null = $_ <# Expected error in test #>
                }

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'ERROR' -and
                    $Message -like 'Forest creation failed:*'
                }
            }
        }
    }

    Context 'Logging behavior' {

        It 'Should log the start of the operation' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Starting Invoke-ADDSForest operation' -and
                    $Level -eq 'INFO'
                }
            }
        }

        It 'Should log the target domain name' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Target domain: contoso.com' -and
                    $Level -eq 'INFO'
                }
            }
        }

        It 'Should log the completion of the operation' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                Invoke-ADDSForest -DomainName 'contoso.com' -Confirm:$false

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Invoke-ADDSForest operation completed' -and
                    $Level -eq 'INFO'
                }
            }
        }

        It 'Should not log SafeModeAdministratorPassword in parameter summary' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-ADDSForest -MockWith {}
                Mock Write-ToLog -MockWith {}

                $securePass = [System.Security.SecureString]::new()
                'TestPass'.ToCharArray() | ForEach-Object { $securePass.AppendChar($_) }
                Invoke-ADDSForest -DomainName 'contoso.com' -SafeModeAdministratorPassword $securePass -Confirm:$false

                Should -Invoke Write-ToLog -Times 0 -Exactly -ParameterFilter {
                    $Message -like '*SafeModeAdministratorPassword*' -and
                    $Message -like '*Parameters:*'
                }
            }
        }
    }
}
