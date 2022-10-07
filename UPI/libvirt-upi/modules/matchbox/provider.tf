provider "matchbox" {
  # endpoint    = var.matchbox_rpc_endpoint
  endpoint    = "matchbox.example.com:8081"
  client_cert = file("~/.matchbox/client.crt")
  client_key  = file("~/.matchbox/client.key")
  ca          = file("~/.matchbox/ca.crt")
}

