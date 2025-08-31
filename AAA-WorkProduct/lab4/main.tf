resource "kubernetes_namespace" "demo" {
  metadata {
    name = "tf-namespace"
  }
}
