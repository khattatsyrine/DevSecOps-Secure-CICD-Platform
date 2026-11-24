# DevSecOps presentation preparation

## Opening explanation

The project follows one Spring Boot image from a reviewed Git commit through build, scans, runtime checks and a gated release. Democyber is a small Java workload with a greeting endpoint and limited Actuator exposure. The demonstration can show which commit produced an image, which checks ran against it, and which failures stop a release.

## Components and what to show

| Component | Role and integration | Demonstration |
| --- | --- | --- |
| Git and GitHub | The existing commit history records the implementation and Spring Boot 4 migration. GitHub Actions binds verification to the checked-out event SHA. | Open PR #2, show the migration and health-contract commits, then open the Verify job and its artifact. |
| Maven Wrapper, JUnit and JaCoCo | JDK 21 runs the build with a Java 17 bytecode target. Maven packages an executable JAR, runs the Spring integration tests and produces JaCoCo coverage for Sonar. | Run `.\mvnw.cmd -B -ntp clean verify` on Windows or `./mvnw -B -ntp clean verify` on Ubuntu. Explain the greeting, minimal health response and restricted Actuator test cases. |
| Gitleaks and SonarQube Cloud | Gitleaks scans committed history and retains redacted evidence. The official Sonar action exchanges GitHub OIDC for a short-lived project token, which goes only to the Maven scanner. CI waits for the Quality Gate. | Show the synthetic-secret rejection in PR #1 and the Sonar authentication and Quality Gate steps in PR #2. Describe any Sonar configuration error separately from a failing Quality Gate. |
| Docker, Trivy and the SBOM | Docker builds one candidate. Trivy checks that image archive for HIGH and CRITICAL vulnerabilities and emits a CycloneDX inventory. | Compare the hosted pre-migration and Boot 4 reports. Highlight the vulnerability policy, the SBOM, and the scanned image ID. |
| Compose, smoke checks and ZAP | Compose starts the same image in a disposable project. Smoke checks validate the HTTP contract and deny sensitive Actuator routes. ZAP passively checks responses to fixed GET requests on the disposable app. | Open the hosted runtime and ZAP artifacts. Point out the matching image ID, the passive scan scope and the Medium/High blocking threshold. |
| Prometheus and Grafana | Prometheus scrapes Actuator. Grafana displays provisioned dashboards and queries the live Prometheus data source. | Open the Democyber dashboard and show the target, HTTP requests, and JVM metrics. Explain why a live query adds evidence beyond dashboard provisioning. |
| Alertmanager and the receiver | Stopping the disposable app makes Prometheus fire `DemocyberDown`. Alertmanager routes the notification to a private test receiver. The runner checks the alert at each stage and restarts the app. | Show the receiver delivery line from a passing run. Use the delivery failure fixture from the demonstration matrix to show that a firing rule alone is insufficient. |
| GHCR publish job | Protected-main verification exports the tested image. A separate job validates the archive hash, source commit and image ID before publishing and records the registry digest. | Show the publish prerequisites and archive checks in the workflow. Use the local archive round trip as evidence of identity preservation and label hosted publishing as pending. |

## Suggested demo order

1. Start with the PR and hosted artifact. Identify the commit, the Trivy image ID, and the matching Compose image ID.
2. Start the local stack using the README, then show the greeting and Grafana dashboard. Use the disposable verification command for the outage and recovery demonstration.
3. Close by showing a negative test that actually failed and the publish conditions. Explain which prerequisites still block a real release.

## Script audit

The eight tracked scripts each serve an executed check or a reusable helper. The audit covers the two supported execution environments. PowerShell scripts use PowerShell 7.3 or newer. The host Node scripts use Node 22 or newer. The receiver runs inside the same Linux Node image under Docker on both platforms.

| Script | Why it stays | Windows and Ubuntu considerations |
| --- | --- | --- |
| `scripts/scan.ps1` | Runs Gitleaks or Trivy, retains sanitized reports and associates a passing scan with an image ID. | Uses Docker bind mounts and the same pinned scanner images. A Docker engine, readable checkout and Trivy database access are required. |
| `scripts/sonar.ps1` | Runs the pinned Maven scanner and fails when required inputs or the Quality Gate fail. | Selects `mvnw.cmd` on Windows and `mvnw` on Linux. Hosted credentials come from OIDC. Local use needs approved Sonar credentials. |
| `scripts/runtime.ps1` | Owns Compose setup, exact-image checks, ZAP, fault fixtures, recovery and cleanup. | Uses Docker Compose and host Node on both platforms. Set alternate published ports in the process environment before running it. |
| `scripts/export.ps1` | Checks scan/runtime evidence and commit identity, then saves an archive and SHA-256 metadata for publishing. | Uses Docker and PowerShell's file hash API. The hosted invocation is restricted to verified protected-main pushes. |
| `scripts/http.mjs` | Shares loopback URL validation, HTTP assertions and bounded polling between runtime checks. | Uses built-in Node APIs and works without npm dependencies. |
| `scripts/smoke.mjs` | Checks readiness, greeting, metrics and sensitive-path rejection from the host. | Uses local published ports and returns a nonzero exit when the contract fails. |
| `scripts/monitor.mjs` | Checks scrape health, actual dashboard panels and queries, firing alert state and webhook receipt. | Uses host Node and invokes Docker directly for the internal receiver query. |
| `monitoring/receiver.mjs` | Provides evidence that Alertmanager delivered a real webhook. | Runs as a non-root Linux container with a bounded request body and ephemeral state. Compose does not publish its port. |

Disposable Compose evidence now records success after the full run and cleanup. Each new scan or runtime invocation invalidates its prior reports so a failed rerun cannot leave a stale pass marker. A provisioned Grafana dashboard must contain panels.

## Likely questions

- **How is the released image tied to the scan?** The Compose image ID must match the scanned ID. The release transfer verifies the archive SHA-256 and loaded image ID. The registry digest identifies the published manifest.
- **Why upgrade to Spring Boot 4?** Trivy flagged two Spring MVC 6.2 findings after Jackson and Tomcat updates. The fixed public Framework line and supported Tomcat combination are available through Boot 4. The migration preserves the original endpoint contract.
- **Why keep separate verification and publishing jobs?** Only the publisher gets package write access. Verification has repository read access and a scoped OIDC permission for Sonar. A failed Verify job blocks publishing.
- **What does the ZAP result prove?** The application responded to the selected passive checks under the configured threshold. It is limited to those routes and passive rules.
- **What remains before release?** The review run passed the enforced Sonar Quality Gate. GitHub returned HTTP 403 for protection on private `main`, and the GHCR opt-in variable is unset. The protected-main release and registry digest remain unverified. PR #2 remains unmerged.

### Evidence to have open

- [PR #2 and commit history](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/pull/2)
- [Gitleaks negative fixture](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45201899354)
- [Spring Boot 4 scan, SBOM and runtime artifact](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45263551266/artifacts/14861528763)
- [Hosted audit and Sonar Quality Gate](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45370932041)
- [Architecture](architecture.md), [demo matrix](demonstration.md) and [implementation status](IMPLEMENTATION_STATUS.md)
