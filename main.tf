provider "random" {}

resource "random_integer" "port" {
  min = 8000
  max = 8099
}

locals {
  host_lb_port = (var.k3d_host_lb_port != "" ? var.k3d_host_lb_port : random_integer.port.result)
}

resource "null_resource" "cluster" {
  for_each = toset(var.k3d_cluster_name)
  triggers = {
    agent_count  = var.agent_count
    server_count = var.server_count
    ip           = var.k3d_cluster_ip
    port         = var.k3d_cluster_port
    k3s_version  = var.k3s_version
  }
  provisioner "local-exec" {
    command = <<-EOT
      k3d cluster create ${each.key} --servers ${var.server_count} --agents ${var.agent_count} --api-port ${var.k3d_cluster_ip}:${var.k3d_cluster_port} --port 80:80@loadbalancer --port 443:443@loadbalancer --k3s-arg '--no-deploy=traefik@server:0'
    istioctl install -y --set profile=default --context k3d-${each.key}
    kubectl label namespace default istio-injection=enabled --context k3d-${each.key}
    EOT
  }
}

resource "null_resource" "cluster_delete" {
  for_each = toset(var.k3d_cluster_name)
  provisioner "local-exec" {
    command = "k3d cluster delete ${each.key}"
    when    = destroy
  }
}
