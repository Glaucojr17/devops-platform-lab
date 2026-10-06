resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name = "devops-lab"
  }
}

resource "kubernetes_deployment_v1" "api" {
  metadata {
    name      = "lab-api"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = { app = "lab-api" }
    }
    template {
      metadata {
        labels = { app = "lab-api" }
      }
      spec {
        automount_service_account_token = false
        security_context {
          run_as_non_root = true
          run_as_user     = 10001
          run_as_group    = 10001
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }
        container {
          name              = "api"
          image             = var.image
          image_pull_policy = "IfNotPresent"
          port {
            name           = "http"
            container_port = 3000
          }
          readiness_probe {
            http_get {
              path = "/health/ready"
              port = "http"
            }
            period_seconds = 5
          }
          liveness_probe {
            http_get {
              path = "/health/live"
              port = "http"
            }
            initial_delay_seconds = 3
            period_seconds        = 10
          }
          resources {
            requests = { cpu = "25m", memory = "32Mi" }
            limits   = { cpu = "250m", memory = "128Mi" }
          }
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem = true
            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "api" {
  metadata {
    name      = "lab-api"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }
  spec {
    selector = { app = "lab-api" }
    type     = "ClusterIP"
    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
  }
}
