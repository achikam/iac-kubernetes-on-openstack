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
  tenant_name = "uat-project"
  domain_name = "uat"
  password    = "Redhat123!@#"
  auth_url    = "https://lite-iaas-tbs.lintasarta.net:13000"
  region      = "regionOne"
}