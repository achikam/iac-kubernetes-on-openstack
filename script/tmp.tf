locals {
  flavor_settings = {
    name        = "tf-flavor"
    ram         = "4096"
    vcpus       = "2"
    disk        = "0"
    is_public   = true
    extra_specs = { "aggregate_instance_extra_specs:processor" = "intel" }
  }

  master_settings = {
    "master"  = { private_ip = "10.20.20.11", floating_ip = "125.213.130.182", volume_name = "vol_master", volume_size = "10" }
    "worker1" = { private_ip = "10.20.20.12", floating_ip = "125.213.130.183", volume_name = "vol_worker1", volume_size = "10" }
    "worker2" = { private_ip = "10.20.20.13", floating_ip = "125.213.130.184", volume_name = "vol_worker2", volume_size = "10" }
  }
}

resource "openstack_compute_flavor_v2" "tf_flavor" {
  for_each = local.flavor_settings
  name      = each.value.name
  ram       = each.value.ram
  vcpus     = each.value.vcpus
  disk      = each.value.disk
  is_public = each.value.is_public
  extra_specs = each.value.extra_specs
}

resource "openstack_blockstorage_volume_v3" "volumes" {
  for_each = local.master_settings
  name     = each.value.volume_name
  size     = each.value.volume_size
  image_id = "56383473-17de-4baf-8b9b-3711bebe5d3d"
}

resource "openstack_compute_keypair_v2" "tf_keypair" {
  name       = "terra-keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGoFEgRQDiK3/jg7yptJ5TZi4WXlbvCa9w0cAUg4Mc4omomzXPF3XstpBC2xCSWRpsIhWusLr20p3M4tDkb87zxdmGZtJPljNn96KkX17lE0OJxHX4sMsCs1eHOsnhc5jcpnR43ATA/uOgVYEatDaIkaXgMQZeo4/+EYNcCoNMpk3CZAr8158iINWTRQFl+Ya814Bqa6+h3NEgiyN7R+dDdz7LFh2U05E9v4HodFpERx6waLfGjhdjXMVhZDLyDdulO+ETofQUG2uATz2Ocv8Cw7VEfG8QsJ8J0u2tdvCXVcqQ5gB7Xg34+/mn+j/bfLlDgu/C1VlqU05uELv50Cel ACC@ACC-MSI-LAPTOP"
}

resource "openstack_compute_secgroup_v2" "m_secgroup" {
  name        = "m-secgroup"
  description = "Security Group for Kubernetes Control Plane"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 6443
    to_port     = 6443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 10250
    to_port     = 10250
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 10257
    to_port     = 10257
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 10259
    to_port     = 10259
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 2379
    to_port     = 2380
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}


resource "openstack_networking_network_v2" "tf_network" {
  name           = "tf-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "tf_subnet" {
  name       = "tf-subnet"
  network_id = openstack_networking_network_v2.tf_network.id
  cidr       = "10.20.20.0/24"
  ip_version = 4
}

resource "openstack_networking_port_v2" "ports" {
  for_each       = local.master_settings
  name           = "port-${each.key}-${each.value.private_ip}"
  admin_state_up = true
  network_id     = openstack_networking_network_v2.tf_network.id

  fixed_ip {
    subnet_id   = openstack_networking_subnet_v2.tf_subnet.id
    ip_address  = each.value.private_ip
  }
}

resource "openstack_networking_router_v2" "tf_router" {
  name                = "terra-router"
  admin_state_up      = true
  external_network_id = "6806d2df-7719-4711-aa3b-94fa4598ed4b"
}

resource "openstack_networking_router_interface_v2" "tf_router_interface" {
  router_id = openstack_networking_router_v2.tf_router.id
  subnet_id = openstack_networking_subnet_v2.tf_subnet.id
}

resource "openstack_networking_floatingip_v2" "floating_ips" {
  for_each = local.master_settings
  pool    = "Public"
  address = each.value.floating_ip
}

resource "openstack_compute_servergroup_v2" "server_groups" {
  for_each = { for key in ["m", "w"] : key => { name = "${key}-servergroup", policies = ["anti-affinity"] } }

  name     = each.value.name
  policies = each.value.policies
}

resource "openstack_compute_instance_v2" "instances" {
  for_each = local.master_settings

  name            = each.key
  flavor_id       = openstack_compute_flavor_v2.tf_flavor[each.key].id
  key_pair        = openstack_compute_keypair_v2.tf_keypair.name
  security_groups = [openstack_compute_secgroup_v2.m_secgroup.id]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.volumes[each.key].id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  network {
    uuid = openstack_networking_network_v2.tf_network.id
    port = openstack_networking_port_v2.ports[each.key].id
  }

  user_data = file("user_data.yaml")
}
