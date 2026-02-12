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

Describe 'New-EnvPath' -Tag 'Unit' {

    Context 'When joining a base path and child path' {
        It 'Should return the correctly joined path' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath -Path '/usr/local' -ChildPath 'bin'

                $expected = Join-Path -Path '/usr/local' -ChildPath 'bin'
                $result | Should -Be $expected
            }
        }

        It 'Should return a string type' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath -Path '/tmp' -ChildPath 'test'

                $result | Should -BeOfType [string]
            }
        }
    }

    Context 'When using Unix-style paths' {
        It 'Should join Unix root path with child directory' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath -Path '/usr' -ChildPath 'local'

                $expected = Join-Path -Path '/usr' -ChildPath 'local'
                $result | Should -Be $expected
            }
        }

        It 'Should join Unix path with nested child path' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath -Path '/var/log' -ChildPath 'myapp/output.log'

                $expected = Join-Path -Path '/var/log' -ChildPath 'myapp/output.log'
                $result | Should -Be $expected
            }
        }

        It 'Should handle Unix home directory paths' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath -Path '/home/user' -ChildPath '.config'

                $expected = Join-Path -Path '/home/user' -ChildPath '.config'
                $result | Should -Be $expected
            }
        }
    }

    Context 'When using Windows-style paths' {
        It 'Should join Windows drive path with child directory' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath -Path 'C:\Program Files' -ChildPath 'MyApp'

                $expected = Join-Path -Path 'C:\Program Files' -ChildPath 'MyApp'
                $result | Should -Be $expected
            }
        }

        It 'Should join Windows path with nested child path' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath -Path 'C:\Users\Admin' -ChildPath 'Documents\Config'

                $expected = Join-Path -Path 'C:\Users\Admin' -ChildPath 'Documents\Config'
                $result | Should -Be $expected
            }
        }
    }

    Context 'When validating parameters' {
        It 'Should throw on null Path parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                { New-EnvPath -Path $null -ChildPath 'child' } | Should -Throw
            }
        }

        It 'Should throw on empty Path parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                { New-EnvPath -Path '' -ChildPath 'child' } | Should -Throw
            }
        }

        It 'Should throw on null ChildPath parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                { New-EnvPath -Path '/tmp' -ChildPath $null } | Should -Throw
            }
        }

        It 'Should throw on empty ChildPath parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                { New-EnvPath -Path '/tmp' -ChildPath '' } | Should -Throw
            }
        }
    }

    Context 'When using positional parameters' {
        It 'Should accept Path as first positional parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath '/tmp' 'subdir'

                $expected = Join-Path -Path '/tmp' -ChildPath 'subdir'
                $result | Should -Be $expected
            }
        }

        It 'Should accept both parameters positionally in correct order' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = New-EnvPath '/opt' 'myapp'

                $expected = Join-Path -Path '/opt' -ChildPath 'myapp'
                $result | Should -Be $expected
            }
        }
    }

    Context 'When Join-Path throws an exception' {
        It 'Should throw a descriptive error message' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Join-Path { throw 'Simulated Join-Path failure' }

                { New-EnvPath -Path '/some/path' -ChildPath 'child' } | Should -Throw -ExpectedMessage "Failed to join paths '/some/path' and 'child':*"
            }
        }
    }
}
