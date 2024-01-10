locals {
  servers = {
    "serverA" = { floatingip = "125.213.130.182", volume= "vol_serverA" },
    "serverB" = { floatingip = "125.213.130.183", volume= "vol_serverB" },
  }
}

resource "openstack_compute_flavor_v2" "tf_flavor1" {
  name      = "tf-flavor"
  ram       = "1024"
  vcpus     = "1"
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
resource "openstack_compute_secgroup_v2" "tf-secgroup1" {
  name        = "tf-secgroup"
  description = "a security group by terraform"
  
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
resource "openstack_networking_router_v2" "tf-router" {
  name                = "terra-router"
  admin_state_up      = true
  external_network_id = "6806d2df-7719-4711-aa3b-94fa4598ed4b"
}
resource "openstack_networking_router_interface_v2" "tf-router_interface" {
  router_id = openstack_networking_router_v2.tf-router.id
  subnet_id = openstack_networking_subnet_v2.tf-subnet1.id
}

# resource "openstack_networking_floatingip_v2" "tf-fip1" {
#   pool = "Public"
#   depends_on = [openstack_networking_subnet_v2.tf-subnet1]
# }

resource "openstack_networking_floatingip_v2" "tf-fip1" {
  for_each = local.servers
  pool = "Public"
  address = each.value.floatingip
#   address = "125.213.130.186"
}

resource "openstack_compute_instance_v2" "tf-vm1" {
  for_each = local.servers
  name      = each.key
  flavor_id       = openstack_compute_flavor_v2.tf_flavor1.id
  key_pair        = openstack_compute_keypair_v2.tf-keypair.name
  security_groups = [openstack_compute_secgroup_v2.tf-secgroup1.name]
  block_device {
    # uuid                  = openstack_blockstorage_volume_v3.tf-vol1.id
    uuid                  = openstack_blockstorage_volume_v3.tf-vol1[each.key].id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  network {
    uuid = openstack_networking_network_v2.tf-network1.id
  }
  user_data = file("user_data.yaml")
}

# resource "openstack_compute_volume_attach_v2" "attached" {
#   instance_id = openstack_compute_instance_v2.tf-vm1.id
#   volume_id   = openstack_blockstorage_volume_v2.tf-vol1.id
# }

resource "openstack_compute_floatingip_associate_v2" "tf-fip1" {
  for_each = local.servers
  floating_ip = openstack_networking_floatingip_v2.tf-fip1[each.key].address
  instance_id = openstack_compute_instance_v2.tf-vm1[each.key].id
}

resource "null_resource" "example" {
  for_each = local.servers
  connection {
    type     = "ssh"
    user     = "ubuntu"
    # password = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    # host     = openstack_networking_floatingip_v2.tf-fip1["each.value.floatingip"]
    host     = openstack_networking_floatingip_v2.tf-fip1[each.key].address
  }
  provisioner "remote-exec" {
    script  = "script/tes.sh"
    on_failure = continue
  }
}

output "floating_ip_Instance" {
#   value = openstack_networking_floatingip_v2.tf-fip1.address
  value = {for fip in openstack_networking_floatingip_v2.tf-fip1: fip.id => fip.address }
}

