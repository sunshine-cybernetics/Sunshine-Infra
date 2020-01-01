variable "do_token" {
  description = "Digital Ocean Token"
}

variable "region" {
  description = "Digital Ocean Region to deploy K8S and Postgres"
}

variable "bitlog_secret_key" {
  description = "Secret key for Bitlog (see Rocket docs)"
}

variable "bitlog_domain" {
  description = "domain to host bitlog from"
}

variable "forall_domain" {
  description = "Domain/Subdomain on which forall is exposed"
}