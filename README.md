# DevSecOps Secure CI/CD Platform

Democyber is a Java 17 Spring Boot workload with a single greeting endpoint. The platform uses a Windows 11 Docker Desktop/WSL2 stack, GitHub-hosted Actions, SonarQube Cloud, and GitHub Container Registry (GHCR). See [architecture](docs/architecture.md), [demonstration](docs/demonstration.md), and [observed status](docs/IMPLEMENTATION_STATUS.md).

## Local Docker stack

Use Docker Desktop in Linux container mode, JDK 21, Git, Node.js 22 or later, and PowerShell 7.3 or later. Set a unique Grafana password in a local copy of `.env.example` named `.env`. Existing Grafana data retains its original administrator password if the file changes later.

```powershell
.\mvnw.cmd -B -ntp clean verify
docker build --tag democyber:local .
docker compose up -d --no-build
node scripts/smoke.mjs
```

Use [Democyber](http://localhost:8080/), [Prometheus](http://localhost:9090/targets), [Grafana](http://localhost:3000/d/democyber), and [Alertmanager](http://localhost:9093/). Grafana's initial username is `admin`. All published ports bind to loopback. Stop the stack with `docker compose down`. Named volumes retain local data.

## Disposable verification

Use a clean working tree so the source scan, build input, and release commit describe the same version. Build a local candidate with a unique tag. Keep the normal local stack stopped during disposable verification or set alternate ports in the process environment.

```powershell
$env:APP_IMAGE = "democyber:local-verify"
./scripts/scan.ps1 -Mode Source
.\mvnw.cmd -B -ntp clean verify
./scripts/sonar.ps1
docker build --provenance=false --sbom=false --tag $env:APP_IMAGE .
$id = docker image inspect --format '{{.Id}}' $env:APP_IMAGE
./scripts/scan.ps1 -Mode Image -ImageId $id
./scripts/runtime.ps1 -ImageId $id
```

A local Sonar run requires `SONAR_TOKEN`, `SONAR_ORGANIZATION`, and `SONAR_PROJECT_KEY` in the process environment. Use your approved secret store for the token. On Linux, run Maven with `./mvnw`. The other commands are the same inside PowerShell 7. Security and runtime results go to the ignored `evidence/` directory. The runtime check creates and removes a separate Compose project and exercises a controlled outage to verify alert delivery.

## GitHub setup

Import the repository in [SonarQube Cloud](https://sonarcloud.io/) as a CI-based analysis project with PR analysis enabled. Disable automatic analysis for that project. Enable secretless GitHub Actions analysis for the SonarQube Cloud organization and bind this repository to the project. In CI the official authentication action resolves the project and organization and gives the Maven scanner a short-lived token through a step output. Set the optional `SONAR_PROJECT_KEY` Actions variable if the repository is bound to multiple projects. Set `SONAR_REGION=us` for a US project.

Protect `main` with a required PR, approval, branch up-to-date checks, and the **Verify** job from **Secure CI** as a required status. Restrict direct pushes, force pushes, deletions, and bypass. Require code-owner review of the workflow and verification code as supported by the repository. Only set the Actions variable `GHCR_PUBLISH_ENABLED=true` after confirming these settings and GHCR package access. Publishing also checks GitHub's protected-ref flag.

Fork PRs run with read-only permissions and without Sonar credentials. GitHub limits OIDC to the verification job on trusted events. After review, a maintainer can cherry-pick the reviewed changes to a branch in this repository and open a replacement PR. The replacement runs the Quality Gate with credentials. Merge eligibility stays blocked on the fork PR.

## Troubleshooting

- **Docker engine access** — Start Docker Desktop and confirm `docker version` shows a Linux server. A named-pipe error under a sandbox may require permission for that process.
- **Registry or database timeout** — Retry after verifying registry and advisory database access. The Trivy cache under `.tools/` can be reused. Required scanner errors fail verification.
- **Port already in use** — Stop your local stack or set the `APP_PORT`, `PROMETHEUS_PORT`, `GRAFANA_PORT`, and `ALERTMANAGER_PORT` environment variables for the disposable run. Internal container ports stay fixed.
- **Unhealthy monitoring** — Inspect Compose logs, confirm `app:8080` is the Prometheus target and `prometheus:9090` is the Grafana datasource. The alert delivery test polls the receiver over the Compose network.
- **Blocked release** — Confirm the push was to protected `main`, Verify succeeded, and `GHCR_PUBLISH_ENABLED` is set. Review the workflow artifact and registry digest in the job summary.
