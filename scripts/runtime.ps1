#Requires -Version 7.3
param(
    [Parameter(Mandatory)][ValidatePattern('^sha256:[a-f0-9]{64}$')][string]$ImageId,
    [ValidateSet('None', 'Scrape', 'Delivery')][string]$FailureFixture = 'None'
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-Location (Join-Path $PSScriptRoot '..')
$root = (Get-Location).Path
if (-not $env:APP_IMAGE) { throw 'APP_IMAGE is required.' }
$project = 'democyber-verify-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$previousProject = $env:COMPOSE_PROJECT_NAME
$previousPassword = $env:GRAFANA_ADMIN_PASSWORD
$zap = "$project-zap"
$zapCreated = $false
New-Item -ItemType Directory -Force evidence | Out-Null
foreach ($report in 'evidence/runtime.txt', 'evidence/zap-passive.json') {
    if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report }
}

try {
    $env:COMPOSE_PROJECT_NAME = $project
    $env:GRAFANA_ADMIN_PASSWORD = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    docker compose config --quiet
    docker compose pull --policy missing prometheus alertmanager grafana receiver
    docker compose run --rm --no-deps --entrypoint /bin/promtool prometheus check config /etc/prometheus/prometheus.yml
    docker compose run --rm --no-deps --entrypoint /bin/amtool alertmanager check-config /etc/alertmanager/alertmanager.yml
    docker compose run --rm --no-deps --entrypoint /bin/promtool `
        --volume "${root}/monitoring:/rules:ro" --workdir /rules prometheus test rules rule-tests.yml

    docker compose up -d --no-build --pull never
    $container = docker compose ps --all --quiet app
    if (!$container) { throw 'Compose did not create an app container.' }
    $runningId = docker inspect --format '{{.Image}}' $container
    if ($runningId -cne $ImageId) { throw 'Compose image ID differs from the scanned image.' }
    try {
        node scripts/smoke.mjs
    } catch {
        docker compose logs --no-color app
        throw
    }

    docker create --name $zap --network "${project}_default" `
        --mount "type=bind,source=$root/security/zap.yml,target=/zap/plan.yml,readonly" `
        ghcr.io/zaproxy/zaproxy:2.17.0@sha256:9624669db72f54d86c4b46a7064518bd9bf79d8c61a4c31befa9923489f328af zap.sh -cmd -autorun /zap/plan.yml | Out-Null
    $zapCreated = $true
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        docker start -a $zap
        $zapStart = $LASTEXITCODE
        docker cp "${zap}:/tmp/zap-passive.json" evidence/zap-passive.json
        $zapCopy = $LASTEXITCODE
    } finally {
        $PSNativeCommandUseErrorActionPreference = $true
    }
    $zapExit = docker inspect --format '{{.State.ExitCode}}' $zap
    if ($zapStart -ne 0 -or $zapExit -ne '0' -or $zapCopy -ne 0) {
        throw "ZAP passive verification failed (start $zapStart, policy $zapExit, report $zapCopy)."
    }

    if ($FailureFixture -eq 'Scrape') {
        docker compose stop app
        node scripts/monitor.mjs scrape-down
    }
    node scripts/monitor.mjs metrics
    if ($FailureFixture -eq 'Delivery') { docker compose stop receiver }
    docker compose stop app
    node scripts/monitor.mjs alert
    docker compose start app
    node scripts/smoke.mjs
    if ((docker inspect --format '{{.Image}}' (docker compose ps -q app)) -cne $ImageId) {
        throw 'Image ID changed after restart.'
    }
} finally {
    try {
        if ($zapCreated) { docker rm -f $zap | Out-Null }
    } finally {
        try {
            docker compose down --volumes --remove-orphans
        } finally {
            $env:COMPOSE_PROJECT_NAME = $previousProject
            $env:GRAFANA_ADMIN_PASSWORD = $previousPassword
        }
    }
}

@(
    "Compose image ID $runningId"
    'Prometheus metrics and Grafana dashboard/query passed'
    'Prometheus firing, Alertmanager active, and delivered webhook verified'
) | Set-Content evidence/runtime.txt
