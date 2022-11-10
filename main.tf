locals {
  default_secret_name = replace(replace("${var.docker_username}-${lower(var.docker_server)}", "/[^a-z0-9-.]/", "-"), "/-+/", "-")
  secret_name   = var.secret_name != "" ? var.secret_name : local.default_secret_name
  name          = local.secret_name
  yaml_dir      = "${path.cwd}/.tmp/${local.name}/chart/global-pull-secret"
  service_url   = "http://${local.name}.${var.namespace}"
  source_dir      = "${path.cwd}/.tmp/source"
  tmp_dir      = "${path.cwd}/.tmp/tmp"

  values_content = {
    docker_username = var.docker_username
    docker_server = var.docker_server
    secret_name = local.secret_name
  }
  layer = "infrastructure"
  type  = "base"
  application_branch = "main"
  namespace = var.namespace
  layer_config = var.gitops_config[local.layer]
}

resource null_resource create_yaml {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-yaml.sh '${local.name}' '${local.yaml_dir}'"

    environment = {
      VALUES_CONTENT = yamlencode(local.values_content)
    }
  }
}

resource null_resource create_secrets {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-secrets.sh '${local.secret_name}' '${local.source_dir}'"

    environment = {
      DOCKER_PASSWORD = var.docker_password
      NAMESPACE = var.namespace
    }
  }
}

resource gitops_seal_secrets secrets {
  depends_on = [null_resource.create_secrets,null_resource.create_yaml]

  source_dir    = local.source_dir
  dest_dir      = "${local.yaml_dir}/templates"
  kubeseal_cert = var.kubeseal_cert
  tmp_dir       = local.tmp_dir
}


resource gitops_module setup_gitops {
  depends_on = [null_resource.create_yaml, gitops_seal_secrets.secrets]
  name = local.name
  namespace = local.namespace
  content_dir = local.yaml_dir
  server_name = var.server_name
  layer = local.layer
  type = local.type
  branch = local.application_branch
  config = yamlencode(var.gitops_config)
  credentials = yamlencode(var.git_credentials)
}