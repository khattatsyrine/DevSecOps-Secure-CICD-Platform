#Requires -Version 7.3
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-Location (Join-Path $PSScriptRoot '..')

foreach ($name in 'SONAR_TOKEN', 'SONAR_ORGANIZATION', 'SONAR_PROJECT_KEY') {
    if (-not [Environment]::GetEnvironmentVariable($name)) {
        throw "$name is required for the SonarQube Cloud Quality Gate."
    }
}
$sonarHost = switch ($env:SONAR_REGION) {
    { [string]::IsNullOrEmpty($_) -or $_ -eq 'eu' } { 'https://sonarcloud.io' }
    'us' { 'https://sonarqube.us' }
    'au' { 'https://sonarqube.au' }
    default { throw 'SONAR_REGION must be eu, us, or au.' }
}
$wrapper = if ($IsWindows) { './mvnw.cmd' } else { './mvnw' }
& $wrapper -B -ntp 'org.sonarsource.scanner.maven:sonar-maven-plugin:5.9.0.7382:sonar' `
    "-Dsonar.organization=$env:SONAR_ORGANIZATION" "-Dsonar.projectKey=$env:SONAR_PROJECT_KEY" `
    "-Dsonar.host.url=$sonarHost" '-Dsonar.qualitygate.wait=true' '-Dsonar.qualitygate.timeout=300'
