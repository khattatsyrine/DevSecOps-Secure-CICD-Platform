# Demonstration matrix

See [implementation status](IMPLEMENTATION_STATUS.md) for observed results. Use temporary local Git history or reviewed test branches for negative cases. Keep those branches unmerged.

| Scenario | Observable result |
| --- | --- |
| Valid same-repository PR | Verify passes and Publish to GHCR skips. |
| Committed synthetic credential | Gitleaks fails with the synthetic rule and a sanitized report. Use a throwaway repository and the policy's fixture format. |
| Known vulnerable candidate | Trivy reports HIGH or CRITICAL findings and fails before Compose and publishing. Use a disposable historical image purely for static analysis. |
| Controlled code quality issue | Sonar Quality Gate fails. Use a disposable PR and a project gate with a known coverage condition. |
| App unavailable | Set `APP_PORT` to an unused local port and run `node scripts/smoke.mjs`. The readiness check exits nonzero. |
| API security regression | Serve an intentionally different HTTP contract in a disposable fixture. Returning HTTP 200 at `/actuator/env` must fail the smoke test. |
| Prometheus scrape disrupted | Run `./scripts/runtime.ps1 -ImageId $id -FailureFixture Scrape`. The fixture waits for up=0 and the healthy metrics check fails. |
| Receiver unavailable | Run `./scripts/runtime.ps1 -ImageId $id -FailureFixture Delivery`. The alert fires and the receiver proof fails. |
| Approved protected main | Verify passes and GHCR receives the checked image. The job records the registry digest and source commit. |
| Failed main verification | Publish to GHCR is skipped. |
| Local Compose | App, Prometheus, Grafana and Alertmanager respond. The receiver proof records a firing notification. |
| Image preservation | Inspect runtime evidence, release JSON and the registry manifest. The local scanned, container and loaded image IDs match. The registry manifest configuration digest matches the configuration in the archive. |
