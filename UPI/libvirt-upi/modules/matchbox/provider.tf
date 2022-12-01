provider "matchbox" {
  # endpoint    = var.matchbox_rpc_endpoint
  #endpoint    = "matchbox.example.com:8081"
  endpoint    = "192.168.1.100:8081"
  client_cert = file("~/.matchbox/client.crt")
  client_key  = file("~/.matchbox/client.key")
  ca          = file("~/.matchbox/ca.crt")
}

terraform {
  required_providers {
    matchbox = {
      source = "poseidon/matchbox"
      version = "0.5.2"
    }
    
  }
}

