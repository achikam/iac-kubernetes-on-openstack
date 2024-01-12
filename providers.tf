# Define required providers
terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "1.53.0"
    }
  }
}

# Configure the OpenStack Provider
provider "openstack" {
  user_name   = var.username
  tenant_name = var.project
  domain_name = var.domain
  password    = var.password
  auth_url    = "https://xxxxxxxxxxx:13000"
  region      = "regionOne"
}
