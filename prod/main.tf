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

// Forall App

resource "digitalocean_certificate" "forall_cert" {
  name = "forall"
  type    = "lets_encrypt"
  domains = [var.forall_domain]
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
