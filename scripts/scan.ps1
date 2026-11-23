#Requires -Version 7.3
param(
    [Parameter(Mandatory)][ValidateSet('Source', 'Image')][string]$Mode,
    [string]$ImageId,
    [string]$SourceDirectory = '.'
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-Location (Join-Path $PSScriptRoot '..')
$root = (Get-Location).Path
$evidence = (New-Item -ItemType Directory -Force evidence).FullName
$work = (New-Item -ItemType Directory -Force ".tools/scan-$([Guid]::NewGuid().ToString('N'))").FullName

try {
    if ($Mode -eq 'Source') {
        $source = (Resolve-Path -LiteralPath $SourceDirectory).Path
        $PSNativeCommandUseErrorActionPreference = $false
        try {
            docker run --rm --network none `
                -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/repo `
                --mount "type=bind,source=$source,target=/repo,readonly" `
                --mount "type=bind,source=$root/security/gitleaks.toml,target=/policy.toml,readonly" `
                --mount "type=bind,source=$work,target=/output" `
                ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f git --config /policy.toml --redact=100 --no-banner `
                --report-format json --report-path /output/gitleaks.json --exit-code 10 /repo *> "$work/gitleaks.log"
            $code = $LASTEXITCODE
        } finally {
            $PSNativeCommandUseErrorActionPreference = $true
        }
        $report = Join-Path $work 'gitleaks.json'
        if ($code -notin 0, 10 -or -not (Test-Path -LiteralPath $report)) {
            throw "Gitleaks execution failed (exit $code)."
        }
        $findings = @(Get-Content -LiteralPath $report -Raw | ConvertFrom-Json)
        $filtered = foreach ($finding in $findings) {
            if ($finding) {
                [ordered]@{ rule = $finding.RuleID; line = $finding.StartLine; commit = $finding.Commit }
            }
        }
        ConvertTo-Json -InputObject @($filtered) | Set-Content "$evidence/gitleaks.json" -Encoding utf8
        if ($code -eq 10) { throw 'Gitleaks rejected committed content. See evidence/gitleaks.json.' }
        'Gitleaks passed.'
        return
    }

    if ($ImageId -cnotmatch '^sha256:[a-f0-9]{64}$') { throw 'A local image ID is required.' }
    $archive = Join-Path $work 'candidate.tar'
    $cache = (New-Item -ItemType Directory -Force .tools/trivy-cache).FullName
    docker image save --output $archive $ImageId
    $mounts = @(
        '--mount', "type=bind,source=$work,target=/candidate,readonly",
        '--mount', "type=bind,source=$evidence,target=/evidence",
        '--mount', "type=bind,source=$cache,target=/root/.cache/trivy",
        '--mount', "type=bind,source=$root/security/.trivyignore,target=/policy/ignore,readonly"
    )
    $trivy = 'ghcr.io/aquasecurity/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb'
    docker run --rm @mounts $trivy image --timeout 10m --input /candidate/candidate.tar `
        --format cyclonedx --output /evidence/sbom.cdx.json
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        docker run --rm @mounts $trivy image --timeout 10m --input /candidate/candidate.tar --scanners vuln `
            --severity HIGH,CRITICAL --ignorefile /policy/ignore --exit-code 10 `
            --format json --output /evidence/trivy.json
        $code = $LASTEXITCODE
    } finally {
        $PSNativeCommandUseErrorActionPreference = $true
    }
    if ($code -eq 10) { throw 'Trivy rejected HIGH or CRITICAL findings. See evidence/trivy.json.' }
    if ($code -ne 0) { throw "Trivy execution failed (exit $code)." }
    "$ImageId" | Set-Content "$evidence/scanned-image-id.txt"
    'Trivy passed and CycloneDX SBOM generated.'
} finally {
    Get-ChildItem -LiteralPath $work -File | Remove-Item -Force
    Remove-Item -LiteralPath $work
}
