output "namespace" {
  value = kubernetes_namespace_v1.lab.metadata[0].name
}

output "service_name" {
  value = kubernetes_service_v1.api.metadata[0].name
}
