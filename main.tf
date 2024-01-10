locals {
  servers = {
    "serverA" = { privateip = "10.20.20.11", floatingip = "125.213.130.182", volume= "vol_serverA" },
    "serverB" = { privateip = "10.20.20.12", floatingip = "125.213.130.183", volume= "vol_serverB" },
    "serverC" = { privateip = "10.20.20.13", floatingip = "125.213.130.184", volume= "vol_serverC" },
  }
}

resource "openstack_compute_flavor_v2" "tf_flavor1" {
  name      = "tf-flavor"
  ram       = "4096"
  vcpus     = "2"
  disk      = "0"
  is_public = true
  extra_specs = {
    "aggregate_instance_extra_specs:processor" = "intel",
  }
}

resource "openstack_blockstorage_volume_v3" "tf-vol1" {
  for_each = local.servers
  name = each.value.volume
  size = 6
  image_id = "56383473-17de-4baf-8b9b-3711bebe5d3d"
}
resource "openstack_compute_keypair_v2" "tf-keypair" {
  name = "terra-keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGoFEgRQDiK3/jg7yptJ5TZi4WXlbvCa9w0cAUg4Mc4omomzXPF3XstpBC2xCSWRpsIhWusLr20p3M4tDkb87zxdmGZtJPljNn96KkX17lE0OJxHX4sMsCs1eHOsnhc5jcpnR43ATA/uOgVYEatDaIkaXgMQZeo4/+EYNcCoNMpk3CZAr8158iINWTRQFl+Ya814Bqa6+h3NEgiyN7R+dDdz7LFh2U05E9v4HodFpERx6waLfGjhdjXMVhZDLyDdulO+ETofQUG2uATz2Ocv8Cw7VEfG8QsJ8J0u2tdvCXVcqQ5gB7Xg34+/mn+j/bfLlDgu/C1VlqU05uELv50Cel ACC@ACC-MSI-LAPTOP"
}
resource "openstack_compute_secgroup_v2" "m-secgroup" {
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
resource "openstack_compute_secgroup_v2" "w-secgroup" {
  name        = "w-secgroup"
  description = "Security Group for Kubernetes Worker"
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
    from_port   = 10250
    to_port     = 10250
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
  rule {
    from_port   = 30000
    to_port     = 32767
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_networking_network_v2" "tf-network1" {
  name           = "tf-net"
  admin_state_up = "true"
}
resource "openstack_networking_subnet_v2" "tf-subnet1" {
  name       = "tf-subnet"
  network_id = openstack_networking_network_v2.tf-network1.id
  cidr       = "10.20.20.0/24"
  ip_version = 4
}

resource "openstack_networking_port_v2" "tf-port" {
  for_each       = local.servers
  name           = "private-ip"
  admin_state_up = "true"
  network_id     = openstack_networking_network_v2.tf-network1.id
  fixed_ip {
    subnet_id   = openstack_networking_subnet_v2.tf-subnet1.id
    ip_address  = each.value.privateip
  }
}

resource "openstack_networking_router_v2" "tf-router" {
  name                = "terra-router"
  admin_state_up      = true
  external_network_id = "6806d2df-7719-4711-aa3b-94fa4598ed4b"
}
resource "openstack_networking_router_interface_v2" "tf-router_interface" {
  router_id = openstack_networking_router_v2.tf-router.id
  subnet_id = openstack_networking_subnet_v2.tf-subnet1.id
}

# resource "openstack_networking_floatingip_v2" "tf-fip" {
#   pool = "Public"
#   depends_on = [openstack_networking_subnet_v2.tf-subnet1]
# }

resource "openstack_networking_floatingip_v2" "tf-fip" {
  for_each = local.servers
  pool = "Public"
  address = each.value.floatingip
}

resource "openstack_compute_servergroup_v2" "tf-servergroup" {
  name     = "m-servergroup"
  policies = ["anti-affinity"]
}
resource "openstack_compute_instance_v2" "tf-vm1" {
  for_each = local.servers
  name      = each.key
  flavor_id       = openstack_compute_flavor_v2.tf_flavor1.id
  key_pair        = openstack_compute_keypair_v2.tf-keypair.name
  security_groups = [openstack_compute_secgroup_v2.m-secgroup.name]
  scheduler_hints {
    group = openstack_compute_servergroup_v2.tf-servergroup.id
  }
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.tf-vol1[each.key].id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  network {
    uuid = openstack_networking_network_v2.tf-network1.id
    port = openstack_networking_port_v2.tf-port[each.key].id
  }
  user_data = file("user_data.yaml")
}

# resource "openstack_compute_volume_attach_v2" "attached" {
#   instance_id = openstack_compute_instance_v2.tf-vm1.id
#   volume_id   = openstack_blockstorage_volume_v2.tf-vol1.id
# }

# resource "openstack_compute_floatingip_associate_v2" "tf-fip" {
#   for_each = local.servers
#   floating_ip = openstack_networking_floatingip_v2.tf-fip[each.key].address
#   instance_id = openstack_compute_instance_v2.tf-vm1[each.key].id
# }

# resource "null_resource" "example" {
#   for_each = local.servers
#   connection {
#     type     = "ssh"
#     user     = "ubuntu"
#     private_key = file("~/.ssh/id_rsa")
#     host     = openstack_networking_floatingip_v2.tf-fip[each.key].address
#     timeout  = "60s"
#   }
#   provisioner "remote-exec" {
#     script  = "script/kube.sh"
#     on_failure = continue
#   }
# }

output "floating_ip_Instance" {
#   value = openstack_networking_floatingip_v2.tf-fip["each.value.floatingip"]
  value = { for fip in openstack_networking_floatingip_v2.tf-fip: fip.id => fip.address }
}
output "private_ip" {
  value = { for private in openstack_networking_port_v2.tf-port: private.id => private.fixed_ip[0].ip_address }
}
