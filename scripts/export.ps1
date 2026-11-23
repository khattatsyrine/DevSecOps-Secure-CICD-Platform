#Requires -Version 7.3
param(
    [Parameter(Mandatory)][ValidatePattern('^sha256:[a-f0-9]{64}$')][string]$ImageId,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-Location (Join-Path $PSScriptRoot '..')
if ((Get-Content evidence/scanned-image-id.txt -Raw).Trim() -cne $ImageId) {
    throw 'The exported image lacks a matching passing scan.'
}
if ((Get-Content evidence/runtime.txt -TotalCount 1) -cne "Compose image ID $ImageId") {
    throw 'The exported image lacks a matching runtime.'
}
if ((git rev-parse HEAD) -cne $Commit) { throw 'The checked-out commit differs from the release commit.' }
if ((docker image inspect --format '{{.Id}}' $env:APP_IMAGE) -cne $ImageId) {
    throw 'The verified local tag changed.'
}
New-Item -ItemType Directory -Force evidence/release | Out-Null
docker image save --output evidence/release/image.tar $env:APP_IMAGE
[ordered]@{
    sourceCommit = $Commit
    imageId = $ImageId
    archiveSha256 = (Get-FileHash evidence/release/image.tar -Algorithm SHA256).Hash.ToLowerInvariant()
} | ConvertTo-Json | Set-Content evidence/release/metadata.json -Encoding utf8
