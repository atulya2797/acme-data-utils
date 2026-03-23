# Acme Corp: GitLab CI + Artifactory → GitHub Actions + Cloudsmith
## Migration Guide for Engineering Teams

---

## 1. What Changed and Why

### Platform Changes at a Glance

| Area | Before | After |
|---|---|---|
| **CI/CD** | GitLab CI (self-hosted runners) | GitHub Actions (GitHub-hosted runners) |
| **Package registry** | JFrog Artifactory (on-prem) | Cloudsmith (SaaS) |
| **QA repository** | `acme-pypi-qa` on Artifactory | `acme-pypi-qa` on Cloudsmith |
| **Prod repository** | `acme-pypi-prod` on Artifactory | `acme-pypi-prod` on Cloudsmith |
| **Authentication** | Long-lived API keys in CI variables | Short-lived OIDC tokens (no stored secrets) |
| **Promotion mechanism** | JFrog CLI `jf rt cp` | Cloudsmith CLI `cloudsmith copy` |
| **QA gate** | GitLab `when: manual` job | GitHub Environment with required reviewers |
| **Infrastructure management** | Manual Cloudsmith UI config | Terraform (`cloudsmith-io/cloudsmith` provider) |

The core workflow is unchanged: **Build → Test → Publish to QA → Manual gate → Promote to Prod**. What has changed is where each step runs and how the pipeline authenticates.

---

## 2. Authentication Approach

### The Old Way: Long-Lived API Keys (avoid)

The legacy pipeline stored `ARTIFACTORY_API_KEY` as a GitLab CI variable. These keys:
- Don't expire automatically
- Are indistinguishable from legitimate use if leaked
- Must be rotated manually across multiple places

### The New Way: OIDC (recommended)

GitHub Actions natively supports OpenID Connect (OIDC). When a workflow runs, GitHub mints a short-lived, cryptographically-signed JWT for that specific run. Cloudsmith's OIDC provider validates this token and exchanges it for a temporary API key scoped only to what the service account is allowed to do.

**No secrets are stored anywhere.** There is no `CLOUDSMITH_API_KEY` to rotate, leak, or forget about.

```
GitHub Actions workflow run
  │
  ├─ requests OIDC token from GitHub's token endpoint
  │   (valid for this run only, signed by GitHub)
  │
  └─ POSTs token to Cloudsmith OIDC endpoint
      │
      └─ Cloudsmith validates claims (repo must match `acme-corp/acme-data-utils`)
          │
          └─ returns temporary API key tied to the ci-publisher service account
```

The OIDC provider and service accounts are provisioned with Terraform so this configuration is version-controlled and auditable.

### Fallback: Static API Key Secret

If OIDC is not yet configured, you can use a static key as a stopgap. Store it as a GitHub Actions secret called `CLOUDSMITH_API_KEY` and replace the OIDC steps with:

```yaml
env:
  CLOUDSMITH_API_KEY: ${{ secrets.CLOUDSMITH_API_KEY }}
```

This is explicitly a **temporary fallback** — migrate to OIDC as soon as possible.

---

## 3. Pipeline Workflow Reference

Three workflow files replace the single `.gitlab-ci.yml`:

### `ci.yml` — Build & Test
- Triggers on every push and pull request
- Builds the wheel, installs it, runs pytest
- Uploads the dist artifact for downstream jobs

### `publish-qa.yml` — Publish to QA
- Triggers on pushes to `main` only, after CI passes
- Authenticates via OIDC and pushes the wheel to `acme-pypi-qa`
- Prints the install command to the Actions log for easy developer pickup

### `promote-prod.yml` — Promote to Production
- **Manual trigger only** — go to Actions → Promote to Production → Run workflow
- Input the version string (e.g. `0.1.0`)
- The run is gated by the **`production` GitHub Environment** (requires a reviewer to approve)
- On approval, copies the wheel from `acme-pypi-qa` to `acme-pypi-prod` using `cloudsmith copy`

---

## 4. Developer Workflows

### Installing a QA Package

```bash
pip install acme-data-utils==<version> \
  --index-url https://dl.cloudsmith.io/basic/<org>/acme-pypi-qa/python/simple/ \
  --extra-index-url https://pypi.org/simple/
```

You'll need a Cloudsmith entitlement token for private repos. Your token is in the Cloudsmith UI under **Tokens** or ask your team lead.

### Installing a Production Package

```bash
pip install acme-data-utils==<version> \
  --index-url https://dl.cloudsmith.io/basic/<org>/acme-pypi-prod/python/simple/ \
  --extra-index-url https://pypi.org/simple/
```

### Promoting a QA Build to Production

1. Navigate to the GitHub repository → **Actions** → **Promote to Production**
2. Click **Run workflow**
3. Enter the version number (must match exactly what is in Cloudsmith QA)
4. A designated reviewer receives an email/Slack notification
5. The reviewer clicks **Review deployments → Approve and deploy**
6. The workflow copies the package to production and logs the install command

### Triggering a Build Manually

Push to `main` or open a pull request. To force a QA publish without a code change, use GitHub's **Re-run jobs** button on a completed `publish-qa` run.

---

## 5. Infrastructure Management

Cloudsmith resources are managed as code via Terraform in the `terraform/` directory. This includes:

- QA and Production repositories
- Service accounts (`acme-ci-publisher`, `acme-prod-promoter`)
- Teams and repository permission grants
- The GitHub Actions OIDC provider configuration

### First-time setup

```bash
cd terraform/
export TF_VAR_cloudsmith_api_key="<your-admin-api-key>"
terraform init
terraform plan
terraform apply
```

After `apply`, add the printed output values as GitHub Actions **repository variables**:

| GitHub Variable | Terraform Output |
|---|---|
| `CLOUDSMITH_ORG` | your org slug |
| `CLOUDSMITH_OIDC_SLUG` | `oidc_provider_slug` |
| `CLOUDSMITH_SA_SLUG` | `ci_publisher_slug` or `prod_promoter_slug` |

### Making infrastructure changes

Edit `terraform/main.tf`, open a pull request, and run `terraform plan` in CI before merging. Never click around the Cloudsmith UI to make infrastructure changes — the state will diverge from Terraform.

---

## 6. Security Improvements Over the Previous Setup

| Concern | Old Setup | New Setup |
|---|---|---|
| Credential lifetime | API keys never expire | OIDC tokens expire after minutes |
| Credential scope | Same key for QA and Prod | Separate service accounts with least-privilege permissions |
| Credential storage | Stored in GitLab CI variables (encrypted but persistent) | Not stored — generated per run |
| Blast radius of a leak | Full Artifactory access | A single short-lived operation |
| Audit trail | API key usage not attributed to a specific workflow run | OIDC claims include repo, branch, workflow, run ID |

---

## 7. Observability

The previous pipeline had no notification mechanism beyond job pass/fail. The new setup adds:

- **Explicit install-command output** in the workflow logs after every successful publish. Developers can immediately see which version landed in which repo.
- **GitHub Environment history** records every production promotion, who approved it, and when.
- **Cloudsmith audit log** records every push and copy operation, attributed to the OIDC service account and traceable back to a GitHub Actions run ID.

For richer alerting, add a Slack notification step to `publish-qa.yml` and `promote-prod.yml` using the `slackapi/slack-github-action`.

---

## 8. Known Limitations & Recommendations

- **OIDC is not enabled by default** on all Cloudsmith plans — verify your plan supports it before removing the static-key fallback.
- **Terraform state** should be stored remotely (S3, GCS, Terraform Cloud) rather than locally. The `backend` block in `main.tf` includes a commented example.
- **The `cloudsmith_oidc` resource** may not be available in all versions of the Terraform provider. Pin to a tested version (`~> 0.0`) and verify with `terraform plan` before applying.
- **Branch protection** on `main` is strongly recommended so that only reviewed code triggers a QA publish.
