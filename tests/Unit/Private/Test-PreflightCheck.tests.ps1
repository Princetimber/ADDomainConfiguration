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

Describe 'Test-PreflightCheck' -Tag 'Unit' {

    BeforeEach {
        InModuleScope -ModuleName $script:dscModuleName {
            Mock Write-ToLog -MockWith {}
        }
    }

    Context 'When running on non-Windows platform' -Skip:($IsWindows) {
        It 'Should return false when $IsWindows is false' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-WindowsFeatureWrapper -MockWith { return $null }

                $result = Test-PreflightCheck
                $result | Should -Contain $false
            }
        }

        It 'Should log a platform check failure message' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-WindowsFeatureWrapper -MockWith { return $null }

                Test-PreflightCheck

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Message -like '*Platform check failed*' -and $Level -eq 'ERROR'
                }
            }
        }
    }

    Context 'When validating MinDiskGB parameter' {
        It 'Should throw when MinDiskGB is less than 1' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Test-PreflightCheck -MinDiskGB 0 } | Should -Throw
            }
        }

        It 'Should throw when MinDiskGB is greater than 1000' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Test-PreflightCheck -MinDiskGB 1001 } | Should -Throw
            }
        }

        It 'Should throw when MinDiskGB is negative' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Test-PreflightCheck -MinDiskGB -5 } | Should -Throw
            }
        }
    }

    Context 'When verifying function metadata' {
        It 'Should have CmdletBinding attribute' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name Test-PreflightCheck
                $cmd.CmdletBinding | Should -BeTrue
            }
        }

        It 'Should have OutputType of bool' {
            InModuleScope -ModuleName $script:dscModuleName {
                $cmd = Get-Command -Name Test-PreflightCheck
                $cmd.OutputType.Type.Name | Should -Contain 'Boolean'
            }
        }
    }
}
