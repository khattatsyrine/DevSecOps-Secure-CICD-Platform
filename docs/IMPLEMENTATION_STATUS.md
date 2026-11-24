# Implementation status

Final verification completed on 2026-11-24 (Africa/Lagos). Democyber was inspected read-only, and the implementation and its Git history live in this separate repository.

| Phase | Verified result |
| --- | --- |
| 1. Local Docker | Windows 11 with Docker Desktop, WSL 2 and JDK 21 built and ran the Spring Boot workload. The disposable stack passed greeting, health and metrics checks. |
| 2. Functional tests | Maven passed all 3 integration tests. HTTP smoke checks passed on Windows and hosted Ubuntu and rejected a fixture that exposed `/actuator/env`. |
| 3. Security gates | Gitleaks, SonarQube Cloud OIDC and its enforced Quality Gate, and Trivy passed on protected `main`. The CycloneDX SBOM was retained. Trivy reported zero HIGH or CRITICAL findings. |
| 4. GitHub Actions | The public repository requires a PR and an up-to-date GitHub Actions `Verify` check on `main`. The rule has zero required reviewer approvals and no bypass actors. Force pushes and deletions are blocked. PR #2 passed before merging. |
| 5. Compose and web checks | Compose ran the image ID that Trivy scanned. Passive ZAP passed with one Low finding and zero Medium or High findings. |
| 6. Monitoring | Prometheus scraped HTTP and JVM metrics, Grafana queried its provisioned data source, and Alertmanager delivered a real webhook during a controlled outage. The app recovered on the same image. |
| 7. GHCR | `Verify` exported the checked image. The publisher validated the archive SHA-256 and loaded image ID, pushed the commit tag, and matched the registry manifest configuration to the archive. |
| 8. Full handover | The final Windows rerun and the hosted release passed. The [demonstration matrix](demonstration.md) links the positive and negative evidence. |

## Verified release

PR #2 merged at `b32213cad4afd5fce92f42807c6718b838e65d83`. The protected-main workflow passed both jobs. The Windows rerun passed all three Maven tests and the full disposable Compose, passive ZAP and monitoring suite. [PR #2](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/pull/2) · [Main ruleset](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/rules/27981880) · [Release run](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45388579014) · [Verification artifact](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45388579014/artifacts/14917128176)

Pull the verified image by its immutable manifest digest.

```powershell
docker pull ghcr.io/khattatsyrine/devsecops-secure-cicd-platform@sha256:42e7b36867c07e7e75595ab5f4dd1d952fa0954d002ed688752c321deb2d24f3
```

The scanned, running and loaded CI image ID was `sha256:0c32372bb9b88c90c819a36a322888637f918d99e0165dae7798207ae2e5f796`. An unauthenticated registry lookup by both commit tag and digest returned the same manifest. Its SHA-256 matched the published digest, and its configuration digest matched the CI image ID. Windows Docker Desktop pulled and ran that published manifest through the full Compose suite. Its containerd image store reports the manifest digest as the local image ID. [Release metadata](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45388579014/artifacts/14917898134)

Local evidence includes `evidence/final-windows-maven.txt`, `evidence/final-windows-runtime.txt`, `evidence/final-windows-zap.json` and `evidence/final-windows-released-runtime.txt`. The downloaded hosted reports, release metadata and manifest are under `evidence/protected-main-45388579014/`. GitHub workflow artifacts expire according to their configured retention.

## Earlier verification and resolved blockers

These entries record observations made before the verified release.

The run for [the first main push](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45198411176) recorded Gitleaks and Maven success, Sonar failure, and Publish to GHCR skipped. [The second main run](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45199035496) also built the candidate and attempted Trivy. Its verification artifact step succeeded, and publishing remained skipped.

Local evidence is under ignored `evidence/`. JUnit and JaCoCo results are under `target/surefire-reports/` and `target/site/jacoco/`. At that stage, SonarQube Cloud configuration and branch protection were outstanding. Staying on the Spring Boot 3.5 line would have required Spring Enterprise access for the Spring MVC fixes. Maven Central metadata lists 3.5.16 and 6.2.19 as the latest public Spring Boot 3.5 and Spring MVC 6.2 releases. Both vendor advisories list Spring Framework 6.2.20 under Enterprise Support and 7.0.9 as the first open-source fix. Trivy classifies both as CRITICAL. Spring Boot 4 uses the Spring Framework 7 and Tomcat 11 release lines, so it would be a coordinated migration. The Trivy policy remains unchanged. [Spring advisory 47884](https://spring.io/security/cve-2026-47884/) · [Spring advisory 47890](https://spring.io/security/cve-2026-47890/) · [Spring Boot 4 system requirements](https://docs.spring.io/spring-boot/4.0/system-requirements.html)

The [hosted Trivy artifact](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45199035496/artifacts/14831835276) contains the baseline SBOM and vulnerability report. The [synthetic PR workflow](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45201899354) recorded Gitleaks failure, evidence upload, and skipped publishing.

The [patched main run](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45249327074) passed source scanning, Maven and image build. Sonar and Trivy failed and publishing was skipped. The [patched verification artifact](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45249327074/artifacts/14855505739) contains the SBOM and the remaining CVE-2026-47884 and CVE-2026-47890 findings.

## Spring MVC finding review

The rerun on commit `84317c7` passed Gitleaks, Maven and the image build. Sonar and Trivy failed. Hosted Compose and GHCR publishing were skipped. [GitHub Actions run](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45252475265)

Trivy used GitHub Advisory Database severity and rated both findings Critical. Spring rates CVE-2026-47884 Medium and CVE-2026-47890 Low. Static review of the application found a single greeting REST handler and no application-defined XSLT view or server-sent event rendering. That limits the observed exposure in the demo and leaves the dependency findings subject to the existing release gate. [Spring advisory 47884](https://spring.io/security/cve-2026-47884/) · [Spring advisory 47890](https://spring.io/security/cve-2026-47890/)

A fresh Maven Central metadata check confirmed Spring Boot 3.5.16 and Spring MVC 6.2.19 as the latest public versions in their respective series. The compatible 6.2.20 fix requires Enterprise access. The public Framework 7 fix belongs on the Spring Boot 4 release line. [Spring Boot 3.5 requirements](https://docs.spring.io/spring-boot/3.5/system-requirements.html) · [Spring Boot 4 requirements](https://docs.spring.io/spring-boot/4.0/system-requirements.html)

## Spring Boot 4 migration

The migration PR targets Spring Boot 4.0.10 with Spring MVC 7.0.11 and Tomcat 11.0.27. The first Compose run identified Boot 4's default health probe groups in the response. Commit `2f64738` preserved the existing health response and added a regression assertion. The corrected build passed all three Maven tests and the full local Docker Compose run. [Migration PR](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/pull/2)

GitHub Actions passed Gitleaks, Maven, the image build, Trivy with zero blocking findings, and the scanned-image runtime suite. The Trivy and Compose records carry the same image ID. The passive ZAP report retained one low-risk finding for a missing content-type options header. Prometheus, Grafana and Alertmanager webhook delivery passed. [Hosted run](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45263551266) · [Verification artifact](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45263551266/artifacts/14861528763)

The migration stayed on its review branch while the mandatory Sonar check was blocked. GitHub returned HTTP 403 for private-main protection and listed zero repository Actions secrets and variables. GHCR publishing remains gated by successful verification and protected main.

## SonarQube Cloud OIDC

The existing Verify job grants `id-token: write` and uses the pinned official SonarSource authentication action. The short-lived token is passed only to the Maven analysis step. Maven still waits for the Quality Gate, and publish permissions remain in the separate GHCR job.

The hosted OIDC action resolved project `khattatsyrine_DevSecOps-Secure-CICD-Platform`. SonarQube Cloud denied the exchange because organization `khattatsyrine` has secretless GitHub Actions analysis disabled. An organization administrator must enable it under Administration → Organization settings → Analysis. The Quality Gate step was skipped after authentication failed. The organization setting was later enabled. [Hosted run](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45273369866) · [Official action prerequisites](https://github.com/SonarSource/sonarqube-auth-action#1-prerequisites)

PR #2 rerun attempt 2 passed the OIDC exchange after the organization setting was enabled. Maven authenticated to the bound SonarQube Cloud project, then the scanner rejected CI analysis because Automatic Analysis was still enabled at the project level. A project administrator needs to disable Automatic Analysis under Administration → Analysis Method. Maven must complete analysis and return a passing Quality Gate before merge. Gitleaks, Maven tests, the image build, Trivy, and the scanned-image Compose suite passed on this attempt. GHCR publishing was skipped. GitHub still returned HTTP 403 when checking branch protection. [Rerun attempt 2](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45274440524/attempts/2) · [SonarQube Cloud analysis settings](https://docs.sonarsource.com/sonarqube-cloud/getting-started/github)

## Maintainability and presentation review

The script audit tightened scan and runtime evidence and rejected empty Grafana dashboards. The revised Windows runtime suite passed. The forced scrape failure and invalid scan cleared prior pass markers, and the empty-dashboard fixture exited nonzero. The [presentation guide](PRESENTATION_PREPARATION.md) covers all eight tracked scripts and the demonstration sequence.

The [hosted Ubuntu review run](https://github.com/khattatsyrine/DevSecOps-Secure-CICD-Platform/actions/runs/45370932041) completed successfully on `e46bc7b`. OIDC and the enforced SonarQube Quality Gate passed, as did Gitleaks, Maven, Trivy, the SBOM check and the same-image Compose runtime suite. GHCR skipped publishing on the pull request. GitHub still returned HTTP 403 for branch protection on private `main`, and `GHCR_PUBLISH_ENABLED` is unset.

## Public-repository release preparation

The redacted exposure audit covers every advertised branch and pull-request ref, local committed history, tracked snapshots, and all workflow logs and artifacts retained at the audit baseline. The only Git secret-scanner finding was the deliberate synthetic fixture for the closed Gitleaks test PR. Existing commit metadata includes a non-`noreply` author address. Public visibility would expose that metadata together with existing Actions history. The repository remained private until the owner explicitly authorized publication of the audited history.

The GHCR opt-in remained unset until the public GitHub Free rule was active and publishing was authorized. [Protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) · [Visibility effects](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)

The unused OpenAPI description was removed after confirming that the existing passive ZAP plan and smoke tests do not reference it. Promtool now tests alert rules using the same Compose service image it uses for configuration validation. The Windows runtime suite passed with the revised command, including the alert rule fixture, passive ZAP, metrics, Grafana, webhook delivery and app recovery.
