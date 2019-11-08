terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "Sunshine"

    workspaces {
      name = "dns"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

// Forall.fm Records
resource "digitalocean_record" "forall_naked" {
  domain = "forall.fm"
  type = "A"
  name = "@"
  value = var.forall_prod_ip
}