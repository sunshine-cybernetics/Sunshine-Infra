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
  spaces_access_id  = var.do_spaces_access_key
  spaces_secret_key = var.do_spaces_secret_key
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

// Forall App

resource "digitalocean_database_cluster" "forall" {
  name = "forall"
  engine = "pg"
  version = "11"
  size = "db-s-1vcpu-1gb"
  region = var.region
  node_count = 1
}

resource "digitalocean_spaces_bucket" "forall" {
  name = "forall"
  region = var.spaces_region
  acl = "public-read"
}

resource "digitalocean_certificate" "forall_cdn_cert" {
  name = "forallcdn"
  type = "lets_encrypt"
  domains = [var.forall_cdn_domain]
}

resource "digitalocean_certificate" "forall_cert" {
  name = "forall"
  type = "lets_encrypt"
  domains = [var.forall_domain]
}

resource "digitalocean_cdn" "forall" {
  origin = digitalocean_spaces_bucket.forall.bucket_domain_name
  custom_domain = var.forall_cdn_domain
  certificate_id = digitalocean_certificate.forall_cdn_cert.id
}

resource "kubernetes_namespace" "forall" {
  metadata {
    name = "forall-server"
  }
}

resource "kubernetes_deployment" "forall" {
  metadata {
    name = "forall-server"
    namespace = "forall-server"
    labels = {
      app = "forall-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "forall-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "forall-server"
        }
      }
      spec {
        container {
          image = "moonad/forall-server:latest"
          name = "forall"

          port {
            container_port = 3000
          }

          readiness_probe {
            http_get {
              path = "/health/ready"
              port = 3000
            }
          }

          liveness_probe {
            http_get {
              path = "/health/live"
              port = 3000
            }
          }

          env {
            name = "PUBLIC_HOST"
            value = var.forall_domain
          }

          env {
            name = "PUBLIC_PATH"
            value = "/"
          }

          env {
            name = "PUBLIC_PORT"
            value = "443"
          }

          env {
            name = "PUBLIC_SCHEME"
            value = "https"
          }

          env {
            name = "DATABASE_URL"
            value = digitalocean_database_cluster.forall.uri
          }

          env {
            name = "DATABASE_POOL_SIZE"
            value = "5"
          }

          env {
            name = "BUCKET_ACCESS_KEY"
            value = var.do_spaces_access_key
          }

          env {
            name = "BUCKET_SECRET_KEY"
            value = var.do_spaces_secret_key
          }

          env {
            name = "BUCKET_HOST"
            value = "${digitalocean_spaces_bucket.forall.region}.digitaloceanspaces.com"
          }

          env {
            name = "BUCKET_PORT"
            value = "443"
          }

          env {
            name = "BUCKET_NAME"
            value = digitalocean_spaces_bucket.forall.name
          }

          env {
            name = "BUCKET_SCHEME"
            value = "https://"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "forall" {
  lifecycle {
    ignore_changes = [metadata[0].annotations["kubernetes.digitalocean.com/load-balancer-id"]]
  }
  metadata {
    name = "forall"
    namespace = "forall-server"
    labels = {
      app = "forall-server"
    }
    annotations = {
      "kubernetes.digitalocean.com/load-balancer-id" = "placeholder"
      "service.beta.kubernetes.io/do-loadbalancer-protocol" = "http"
      "service.beta.kubernetes.io/do-loadbalancer-algorithm" = "round_robin"
      "service.beta.kubernetes.io/do-loadbalancer-tls-ports" = "443"
      "service.beta.kubernetes.io/do-loadbalancer-certificate-id" = digitalocean_certificate.forall_cert.id
      "service.beta.kubernetes.io/do-loadbalancer-hostname" = var.forall_domain
      "service.beta.kubernetes.io/do-loadbalancer-redirect-http-to-https" = "true"
    }
  }

  spec {
    selector = {
      app = "forall-server"
    }

    port {
      name = "http"
      port = 80
      target_port = 3000
    }

    port {
      name = "https"
      port = 443
      target_port = 3000
    }

    type = "LoadBalancer"
  }
}
