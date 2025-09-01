resource "helm_release" "nginx" {
  name       = "nginx-demo"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace  = "default"
  version = "21.1.23"

  values = [
    <<-EOF
    service:
      type: NodePort
      nodePorts:
        http: 30080
    EOF
  ]
}
