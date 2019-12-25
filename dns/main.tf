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

// Bitlog.fm Records
resource "digitalocean_record" "bitlog_naked" {
  domain = "bitlog.fm"
  type = "A"
  name = "@"
  value = var.bitlog_prod_ip
}