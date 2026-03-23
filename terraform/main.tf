terraform {
  required_providers {
    cloudsmith = {
      source  = "cloudsmith-io/cloudsmith"
      version = "~> 0.0"
    }
  }

  # Store state remotely so the team can collaborate.
  # Swap backend config to match your setup (S3, GCS, Terraform Cloud, etc.)
  # backend "s3" {
  #   bucket = "acme-tf-state"
  #   key    = "cloudsmith/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "cloudsmith" {
  api_key = var.cloudsmith_api_key
}

# ── Repositories ─────────────────────────────────────────────────────────────

resource "cloudsmith_repository" "qa" {
  name        = "acme-pypi-qa"
  namespace   = var.cloudsmith_org
  description = "QA / staging repository for acme-data-utils"
  repository_type = "private"
  slug        = "acme-pypi-qa"
}

resource "cloudsmith_repository" "prod" {
  name        = "acme-pypi-prod"
  namespace   = var.cloudsmith_org
  description = "Production repository for approved acme-data-utils packages"
  repository_type = "private"
  slug        = "acme-pypi-prod"
}

# ── Service Accounts ─────────────────────────────────────────────────────────
# One service account per pipeline role keeps permissions minimal.

resource "cloudsmith_service" "ci_publisher" {
  name        = "acme-ci-publisher"
  namespace   = var.cloudsmith_org
  description = "Used by GitHub Actions to push packages to QA"
  slug        = "acme-ci-publisher"

  team {
    slug = cloudsmith_team.publishers.slug
  }
}

resource "cloudsmith_service" "prod_promoter" {
  name        = "acme-prod-promoter"
  namespace   = var.cloudsmith_org
  description = "Used by the manual promotion workflow to copy QA → Prod"
  slug        = "acme-prod-promoter"

  team {
    slug = cloudsmith_team.promoters.slug
  }
}

# ── Teams & Repository Permissions ───────────────────────────────────────────

resource "cloudsmith_team" "publishers" {
  name      = "ci-publishers"
  namespace = var.cloudsmith_org
  slug      = "ci-publishers"
}

resource "cloudsmith_team" "promoters" {
  name      = "prod-promoters"
  namespace = var.cloudsmith_org
  slug      = "prod-promoters"
}

resource "cloudsmith_repository_privileges" "qa_publish" {
  namespace  = var.cloudsmith_org
  repository = cloudsmith_repository.qa.slug

  team {
    slug       = cloudsmith_team.publishers.slug
    privilege  = "Write"
  }

  team {
    slug       = cloudsmith_team.promoters.slug
    privilege  = "Read"
  }
}

resource "cloudsmith_repository_privileges" "prod_publish" {
  namespace  = var.cloudsmith_org
  repository = cloudsmith_repository.prod.slug

  team {
    slug       = cloudsmith_team.promoters.slug
    privilege  = "Write"
  }
}

# ── OIDC Provider (GitHub Actions → Cloudsmith, no long-lived keys) ──────────
# This eliminates static API keys stored in GitHub Secrets entirely.

resource "cloudsmith_oidc" "github_actions" {
  namespace   = var.cloudsmith_org
  name        = "github-actions-oidc"
  enabled     = true
  provider_url = "https://token.actions.githubusercontent.com"

  claims = {
    # Only tokens from this specific repo/org are accepted.
    repository = var.github_repo
  }

  service_accounts = [
    cloudsmith_service.ci_publisher.slug,
    cloudsmith_service.prod_promoter.slug,
  ]
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "qa_repository_url" {
  description = "PyPI index URL for the QA repository"
  value       = "https://dl.cloudsmith.io/basic/${var.cloudsmith_org}/acme-pypi-qa/python/simple/"
}

output "prod_repository_url" {
  description = "PyPI index URL for the Production repository"
  value       = "https://dl.cloudsmith.io/basic/${var.cloudsmith_org}/acme-pypi-prod/python/simple/"
}

output "oidc_provider_slug" {
  description = "Slug to use in CLOUDSMITH_OIDC_SLUG GitHub Actions variable"
  value       = cloudsmith_oidc.github_actions.slug
}

output "ci_publisher_slug" {
  description = "Service account slug for the CI publisher"
  value       = cloudsmith_service.ci_publisher.slug
}

output "prod_promoter_slug" {
  description = "Service account slug for the prod promoter"
  value       = cloudsmith_service.prod_promoter.slug
}
