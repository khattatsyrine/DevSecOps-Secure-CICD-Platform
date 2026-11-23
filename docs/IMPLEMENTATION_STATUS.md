# Implementation status

Verification date: 2026-11-23 (Africa/Lagos). Source was inspected read-only under `Documents/DevsecOps`. The original was on `main` with an edited `application.properties` and an untracked generated file. The separate project has its own Git history and a private GitHub repository.

| Phase | Status | Observed evidence and remaining work |
| --- | --- | --- |
| 1. Local Docker | Verified | Docker Desktop 4.95.0, Engine 29.8.2, Compose 5.6.0, WSL 2 and JDK 21. Maven Wrapper built the application. A disposable Compose run verified HTTP and Actuator with UID/GID 10001 and a read-only root filesystem. The project removed its test containers and network. |
| 2. Functional tests | Verified | Maven ran three JUnit tests with zero failures. JaCoCo covered four application lines. Compose smoke passed. On an unavailable loopback port, the smoke script exited 1. |
| 3. Security gates | In progress | Gitleaks, Trivy, and CycloneDX policies are implemented. SonarQube Cloud project settings and analysis credentials are required. |
| 4. GitHub Actions | In progress | The private repository exists. Actionlint validated the workflow. Hosted runs and branch protection are pending. |
| 5. Compose and web checks | In progress | The HTTP contract passed against the local Compose app. Passive ZAP and scanned-image runtime acceptance are pending. Active API Scan coverage is outside the implemented gate. |
| 6. Monitoring | In progress | Prometheus, Grafana, Alertmanager and the receiver are configured. Runtime verification is pending. |
| 7. GHCR | Blocked | The separate publish job is implemented. A passing required verification run, verified protection rules, and a checked registry push remain. |
| 8. Full handover | Blocked | Architecture, reproducing steps and demonstration matrix are documented. Full acceptance depends on the unresolved checks above. |

Local evidence is written under ignored `evidence/`. Maven results are under `target/surefire-reports/` and `target/site/jacoco/`. GitHub Actions is configured to retain sanitized verification summaries and scanner reports and to record the published digest after a successful release.
