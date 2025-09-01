resource "helm_release" "nginx" {
  name       = "nginx-demo"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "nginx"
  version    = "21.1.23"   # Or whatever your helm search showed
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
