module "global_sealed_secrets" {
  source = "./module"

  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert

  docker_server = "test-server"
  docker_username = "test-user"
  secret_name = "test-secret"
  docker_password = "test-password"
}
