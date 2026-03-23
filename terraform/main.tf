terraform {
  required_providers {
    cloudsmith = {
      source  = "cloudsmith-io/cloudsmith"
      version = "~> 0.0"
    }
  }
}

provider "cloudsmith" {
  api_key = var.cloudsmith_api_key
}

# ── Repositories ─────────────────────────────────────────────────────────────

resource "cloudsmith_repository" "qa" {
  name            = "acme-pypi-qa"
  namespace       = var.cloudsmith_org
  description     = "QA / staging repository for acme-data-utils"
  repository_type = "Private"
  slug            = "acme-pypi-qa"
}

resource "cloudsmith_repository" "prod" {
  name            = "acme-pypi-prod"
  namespace       = var.cloudsmith_org
  description     = "Production repository for approved acme-data-utils packages"
  repository_type = "Private"
  slug            = "acme-pypi-prod"
}

# ── Teams ─────────────────────────────────────────────────────────────────────

resource "cloudsmith_team" "publishers" {
  name         = "ci-publishers"
  organization = var.cloudsmith_org
}

resource "cloudsmith_team" "promoters" {
  name         = "prod-promoters"
  organization = var.cloudsmith_org
}

# ── Service Accounts ─────────────────────────────────────────────────────────

resource "cloudsmith_service" "ci_publisher" {
  name         = "acme-ci-publisher"
  organization = var.cloudsmith_org

  team {
    slug = cloudsmith_team.publishers.slug
  }
}

resource "cloudsmith_service" "prod_promoter" {
  name         = "acme-prod-promoter"
  organization = var.cloudsmith_org

  team {
    slug = cloudsmith_team.promoters.slug
  }
}

# ── Repository Permissions ────────────────────────────────────────────────────

resource "cloudsmith_repository_privileges" "qa_publish" {
  organization = var.cloudsmith_org
  repository   = cloudsmith_repository.qa.slug

  team {
    slug      = cloudsmith_team.publishers.slug
    privilege = "Write"
  }

  team {
    slug      = cloudsmith_team.promoters.slug
    privilege = "Read"
  }
}

resource "cloudsmith_repository_privileges" "prod_publish" {
  organization = var.cloudsmith_org
  repository   = cloudsmith_repository.prod.slug

  team {
    slug      = cloudsmith_team.promoters.slug
    privilege = "Write"
  }
}

# ── OIDC Provider ─────────────────────────────────────────────────────────────

resource "cloudsmith_oidc" "github_actions" {
  namespace    = var.cloudsmith_org
  name         = "github-actions-oidc"
  enabled      = true
  provider_url = "https://token.actions.githubusercontent.com"

  claims = {
    repository = var.github_repo
  }

  service_accounts = [
    cloudsmith_service.ci_publisher.slug,
    cloudsmith_service.prod_promoter.slug,
  ]
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "qa_repository_url" {
  value = "https://dl.cloudsmith.io/basic/${var.cloudsmith_org}/acme-pypi-qa/python/simple/"
}

output "prod_repository_url" {
  value = "https://dl.cloudsmith.io/basic/${var.cloudsmith_org}/acme-pypi-prod/python/simple/"
}

output "oidc_provider_slug" {
  value = cloudsmith_oidc.github_actions.slug
}

output "ci_publisher_slug" {
  value = cloudsmith_service.ci_publisher.slug
}

output "prod_promoter_slug" {
  value = cloudsmith_service.prod_promoter.slug
}