
resource null_resource write_outputs {
  provisioner "local-exec" {
    command = "echo \"$${OUTPUT}\" > gitops-output.json"

    environment = {
      OUTPUT = jsonencode({
        name        = module.global_sealed_secrets.name
        branch      = module.global_sealed_secrets.branch
        namespace   = module.global_sealed_secrets.namespace
        server_name = module.global_sealed_secrets.server_name
        layer       = module.global_sealed_secrets.layer
        layer_dir   = module.global_sealed_secrets.layer == "infrastructure" ? "1-infrastructure" : (module.global_sealed_secrets.layer == "services" ? "2-services" : "3-applications")
        type        = module.global_sealed_secrets.type
      })
    }
  }
}
