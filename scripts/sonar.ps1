#Requires -Version 7.3
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-Location (Join-Path $PSScriptRoot '..')

foreach ($name in 'SONAR_TOKEN', 'SONAR_ORGANIZATION', 'SONAR_PROJECT_KEY') {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        throw "$name is required for the SonarQube Cloud Quality Gate."
    }
}
$wrapper = if ($IsWindows) { './mvnw.cmd' } else { './mvnw' }
& $wrapper -B -ntp 'org.sonarsource.scanner.maven:sonar-maven-plugin:5.9.0.7382:sonar' `
    "-Dsonar.organization=$env:SONAR_ORGANIZATION" "-Dsonar.projectKey=$env:SONAR_PROJECT_KEY" `
    '-Dsonar.host.url=https://sonarcloud.io' '-Dsonar.qualitygate.wait=true' '-Dsonar.qualitygate.timeout=300'
