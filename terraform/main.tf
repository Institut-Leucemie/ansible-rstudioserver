terraform {
  required_providers {
    openstack = { source = "terraform-provider-openstack/openstack", version = "~> 1.53.0" }
    aws       = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket                      = "my-terraform-state"
    key                         = "rstudio/terraform.tfstate"
    region                      = "eu-west-par"
    endpoint                    = "https://s3.eu-west-par.io.cloud.ovh.net/"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

variable "os_username" {}
variable "os_password" {}
variable "service_name" {}

provider "openstack" {
  auth_url  = "https://auth.cloud.ovh.net/v3/"
  tenant_id = var.service_name
  user_name = var.os_username
  password  = var.os_password
  region    = "GRA9"
}

provider "aws" {
  region                      = "gra"
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  endpoints {
    s3 = "https://s3.gra.io.cloud.ovh.net"
  }
}

# --- Lookup de l'infra permanente (par nom, pas par state) ---

data "openstack_networking_network_v2" "net_leucemie" {
  name = "priv-net-leucemie"
}

data "openstack_networking_secgroup_v2" "sg_leucemie" {
  name = "sg-leucemie"
}

data "openstack_compute_keypair_v2" "key" {
  name = "key-aligre-prod"
}

# --- Ressources éphémères ---

resource "openstack_compute_instance_v2" "rstudio_vm" {
  name            = "marie-rstudio"
  region          = "GRA9"
  flavor_name     = "r3-128"
  image_name      = "Ubuntu 24.04"
  key_pair        = data.openstack_compute_keypair_v2.key.name
  security_groups = [data.openstack_networking_secgroup_v2.sg_leucemie.name]

  network {
    uuid        = data.openstack_networking_network_v2.net_leucemie.id
    fixed_ip_v4 = "192.168.10.50"
  }
}

resource "openstack_blockstorage_volume_v3" "rstudio_data" {
  name   = "1TB-standard-rstudio"
  size   = 1000
  region = "GRA9"

  lifecycle {
    prevent_destroy = true
  }
}

resource "openstack_compute_volume_attach_v2" "rstudio_data_attach" {
  instance_id = openstack_compute_instance_v2.rstudio_vm.id
  volume_id   = openstack_blockstorage_volume_v3.rstudio_data.id
}

output "rstudio_ip" {
  value = openstack_compute_instance_v2.rstudio_vm.network[0].fixed_ip_v4
}
