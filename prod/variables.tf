variable "do_token" {
  description = "Digital Ocean Token"
}

variable "do_spaces_access_key" {
  description = "Digital Ocean Spaces Access Key"
}

variable "do_spaces_secret_key" {
  description = "Digital Ocean Spaces Secret Key"
}

variable "region" {
  description = "Digital Ocean Region to deploy K8S and Postgres"
}

variable "spaces_region" {
  description = "Digital Ocean Region to deploy the spaces bucket"
}

variable "forall_domain" {
  description = "Domain/Subdomain on which forall is exposed"
}

variable "forall_cdn_domain" {
  description = "Domain/Subdomain on which forall CDN is exposed"
}