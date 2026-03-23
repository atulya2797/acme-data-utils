variable "cloudsmith_api_key" {
  description = "Admin Cloudsmith API key used only for Terraform operations"
  type        = string
  sensitive   = true
  # Set via: TF_VAR_cloudsmith_api_key=... or a tfvars file (never commit!)
}

variable "cloudsmith_org" {
  description = "Cloudsmith organisation (namespace) slug"
  type        = string
  default     = "atulya_s"
  # Override for your actual org slug, e.g. "atulya_s" in the demo
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (used to scope OIDC claims)"
  type        = string
  default     = "atulya2797/acme-data-utils"
}
