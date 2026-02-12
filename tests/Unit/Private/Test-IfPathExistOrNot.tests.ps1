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

Describe 'Test-IfPathExistOrNot' -Tag 'Unit' {

    Context 'When all paths exist' {
        It 'Should complete silently for a single existing path' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $true }

                { Test-IfPathExistOrNot -Paths '/tmp/existing' } | Should -Not -Throw
            }
        }

        It 'Should complete silently for multiple existing paths' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $true }

                { Test-IfPathExistOrNot -Paths @('/tmp/path1', '/tmp/path2', '/tmp/path3') } | Should -Not -Throw
            }
        }

        It 'Should verify each path with Test-PathWrapper' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $true }

                Test-IfPathExistOrNot -Paths @('/path/a', '/path/b')

                Should -Invoke Test-PathWrapper -Times 2 -Exactly
            }
        }

        It 'Should log SUCCESS when all paths validated' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $true }

                Test-IfPathExistOrNot -Paths @('/tmp/valid')

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'SUCCESS' -and $Message -like 'All*path(s) validated successfully'
                }
            }
        }
    }

    Context 'When a single path is missing' {
        It 'Should throw when the only path does not exist' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $false }

                { Test-IfPathExistOrNot -Paths '/tmp/nonexistent' } | Should -Throw '*Path validation failed*1 of 1 path(s) not found*'
            }
        }

        It 'Should throw when one of multiple paths is missing' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper {
                    param($Path)
                    if ($Path -eq '/tmp/missing') { return $false }
                    return $true
                }

                { Test-IfPathExistOrNot -Paths @('/tmp/exists', '/tmp/missing') } | Should -Throw '*Path validation failed*1 of 2 path(s) not found*'
            }
        }
    }

    Context 'When multiple paths are missing (batch validation)' {
        It 'Should report all missing paths in a single error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $false }

                { Test-IfPathExistOrNot -Paths @('/tmp/miss1', '/tmp/miss2', '/tmp/miss3') } | Should -Throw '*3 of 3 path(s) not found*'
            }
        }

        It 'Should include missing path names in the error message' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper {
                    param($Path)
                    if ($Path -eq '/tmp/good') { return $true }
                    return $false
                }

                $errorThrown = $false
                $errorMessage = ''
                try {
                    Test-IfPathExistOrNot -Paths @('/tmp/good', '/tmp/bad1', '/tmp/bad2')
                } catch {
                    $errorThrown = $true
                    $errorMessage = $_.Exception.Message
                }

                $errorThrown | Should -BeTrue
                $errorMessage | Should -BeLike '*2 of 3 path(s) not found*'
                $errorMessage | Should -BeLike '*Missing paths*'
                $errorMessage | Should -BeLike '*/tmp/bad1*'
                $errorMessage | Should -BeLike '*/tmp/bad2*'
            }
        }
    }

    Context 'When validating parameters' {
        It 'Should throw on null Paths parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Test-IfPathExistOrNot -Paths $null } | Should -Throw
            }
        }

        It 'Should throw on empty string Paths parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Test-IfPathExistOrNot -Paths '' } | Should -Throw
            }
        }
    }

    Context 'When Test-PathWrapper throws an exception' {
        It 'Should treat the path as missing when Test-PathWrapper throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { throw 'Access denied' }

                { Test-IfPathExistOrNot -Paths '/tmp/inaccessible' } | Should -Throw '*Path validation failed*1 of 1 path(s) not found*'
            }
        }

        It 'Should log an ERROR when Test-PathWrapper throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { throw 'Permission error' }

                try { Test-IfPathExistOrNot -Paths '/tmp/error-path' } catch { $null = $_ <# Expected error in test #> }

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'ERROR' -and $Message -like "Error checking path '/tmp/error-path':*"
                }
            }
        }

        It 'Should continue checking remaining paths after one throws' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper {
                    param($Path)
                    if ($Path -eq '/tmp/error') { throw 'Simulated error' }
                    return $true
                }

                try {
                    Test-IfPathExistOrNot -Paths @('/tmp/error', '/tmp/ok')
                } catch { $null = $_ <# Expected error in test #> }

                Should -Invoke Test-PathWrapper -Times 2 -Exactly
            }
        }
    }

    Context 'When logging path validation progress' {
        It 'Should log INFO at the start of validation' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $true }

                Test-IfPathExistOrNot -Paths @('/tmp/a', '/tmp/b')

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'INFO' -and $Message -eq 'Starting path validation for 2 path(s)'
                }
            }
        }

        It 'Should log DEBUG for each verified path' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $true }

                Test-IfPathExistOrNot -Paths @('/tmp/first', '/tmp/second')

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'DEBUG' -and $Message -eq 'Path verified: /tmp/first'
                }
                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'DEBUG' -and $Message -eq 'Path verified: /tmp/second'
                }
            }
        }

        It 'Should log ERROR for each missing path' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PathWrapper { return $false }

                try { Test-IfPathExistOrNot -Paths @('/tmp/gone') } catch { $null = $_ <# Expected error in test #> }

                Should -Invoke Write-ToLog -Times 1 -Exactly -ParameterFilter {
                    $Level -eq 'ERROR' -and $Message -eq 'Path not found: /tmp/gone'
                }
            }
        }
    }
}
