terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "Sunshine"

    workspaces {
      name = "prod"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

// K8S Cluster

resource "digitalocean_kubernetes_cluster" "prod_cluster" {
  name    = "prodcluster"
  region  = var.region
  version = "1.16.2-do.0"

  node_pool {
    name       = "worker-pool"
    size       = "s-1vcpu-2gb"
    node_count = 2
  }
}

provider "kubernetes" {
  host = digitalocean_kubernetes_cluster.prod_cluster.kube_config.0.host
  token = digitalocean_kubernetes_cluster.prod_cluster.kube_config.0.token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.prod_cluster.kube_config.0.cluster_ca_certificate
  )
}

// Bitlog App

resource "digitalocean_certificate" "bitlog_cert" {
  name = "bitlog"
  type = "lets_encrypt"
  domains = [var.bitlog_domain]
}

resource "digitalocean_database_cluster" "bitlog" {
  name = "bitlog"
  engine = "redis"
  size = "db-s-1vcpu-1gb"
  region = var.region
  node_count = 1
}

resource "kubernetes_namespace" "bitlog" {
  metadata {
    name = "bitlog-server"
  }
}

resource "kubernetes_deployment" "bitlog" {
  metadata {
    name = "bitlog-server"
    namespace = "bitlog-server"
    labels = {
      app = "bitlog-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "bitlog-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "bitlog-server"
        }
      }
      spec {
        container {
          image = "moonad/bitlog-server:latest"
          name = "bitlog"

          port {
            container_port = 8000
          }

          env {
            name = "ROCKET_DATABASES"
            value = "{redis_db={url=\"redis://${digitalocean_database_cluster.bitlog.user}:${digitalocean_database_cluster.bitlog.password}@localhost:6379/\"}}"
          }

          env {
            name = "ROCKET_SECRET_KEY"
            value = var.bitlog_secret_key
          }
        }

        container {
          image = "bamorim/stunnel"
          name = "stunnel"

          port {
            container_port = 6379
          }

          env {
            name = "CLIENT"
            value = "yes"
          }

          env {
            name = "SERVICE"
            value = "redis"
          }
          
          env {
            name = "ACCEPT"
            value = "6379"
          }
          
          env {
            name = "CONNECT"
            value = "${digitalocean_database_cluster.bitlog.private_host}:${digitalocean_database_cluster.bitlog.port}"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "bitlog" {
  lifecycle {
    ignore_changes = [metadata[0].annotations["kubernetes.digitalocean.com/load-balancer-id"]]
  }
  metadata {
    name = "bitlog"
    namespace = "bitlog-server"
    labels = {
      app = "bitlog-server"
    }
    annotations = {
      "kubernetes.digitalocean.com/load-balancer-id" = "placeholder"
      "service.beta.kubernetes.io/do-loadbalancer-protocol" = "http"
      "service.beta.kubernetes.io/do-loadbalancer-algorithm" = "round_robin"
      "service.beta.kubernetes.io/do-loadbalancer-tls-ports" = "443"
      "service.beta.kubernetes.io/do-loadbalancer-certificate-id" = digitalocean_certificate.bitlog_cert.id
      "service.beta.kubernetes.io/do-loadbalancer-hostname" = var.bitlog_domain
      "service.beta.kubernetes.io/do-loadbalancer-redirect-http-to-https" = "true"
    }
  }

  spec {
    selector = {
      app = "bitlog-server"
    }

    port {
      name = "http"
      port = 80
      target_port = 8000
    }

    port {
      name = "https"
      port = 443
      target_port = 8000
    }

    type = "LoadBalancer"
  }
}