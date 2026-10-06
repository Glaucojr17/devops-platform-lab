variable "kubeconfig_path" {
  type        = string
  description = "Local kubeconfig path; no credentials are stored in this project."
  default     = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "Context to use for deployment."
  default     = "kind-devops-lab"
}

variable "image" {
  type        = string
  description = "Image already available to the cluster nodes."
  default     = "devops-platform-lab:local"
}

variable "replicas" {
  type    = number
  default = 2
  validation {
    condition     = var.replicas >= 1 && floor(var.replicas) == var.replicas
    error_message = "replicas must be a positive integer."
  }
}
