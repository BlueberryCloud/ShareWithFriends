resource "helm_release" "nginx" {
  name       = "nginx-demo"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace  = "default"

  values = [
    <<-EOF
    service:
      type: NodePort
      nodePorts:
        http: 30080
    EOF
  ]
}
