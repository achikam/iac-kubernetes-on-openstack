locals {
  masters = {
    "master" = { privateip = "10.20.20.11", floatingip = "125.213.130.182", volume_name = "vol_master", volume_size = "10" },
    # "worker1" = { privateip = "10.20.20.12", floatingip = "125.213.130.183", volume_name = "vol_worker1", volume_size = "10" },
    # "worker2" = { privateip = "10.20.20.13", floatingip = "125.213.130.184", volume_name = "vol_worker2", volume_size = "10" },
  }
}

locals {
  workers = {
    # "master" = { privateip = "10.20.20.11", floatingip = "125.213.130.182", volume_name = "vol_master", volume_size = "10" },
    "worker1" = { privateip = "10.20.20.12", floatingip = "125.213.130.183", volume_name = "vol_worker1", volume_size = "10" },
    "worker2" = { privateip = "10.20.20.13", floatingip = "125.213.130.184", volume_name = "vol_worker2", volume_size = "10" },
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

resource "openstack_blockstorage_volume_v3" "m-vol" {
  for_each = local.masters
  name = each.value.volume_name
  size = each.value.volume_size
  image_id = "56383473-17de-4baf-8b9b-3711bebe5d3d"
}

resource "openstack_blockstorage_volume_v3" "w-vol" {
  for_each = local.workers
  name = each.value.volume_name
  size = each.value.volume_size
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

resource "openstack_networking_port_v2" "m-port" {
  for_each       = local.masters
  name           = "port-master-${each.value.privateip}"
  admin_state_up = "true"
  network_id     = openstack_networking_network_v2.tf-network1.id
  fixed_ip {
    subnet_id   = openstack_networking_subnet_v2.tf-subnet1.id
    ip_address  = each.value.privateip
  }
}

resource "openstack_networking_port_v2" "w-port" {
  for_each       = local.workers
  name           = "port-worker-${each.value.privateip}"
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

resource "openstack_networking_floatingip_v2" "m-fip" {
  for_each = local.masters
  pool = "Public"
  address = each.value.floatingip
}
resource "openstack_networking_floatingip_v2" "w-fip" {
  for_each = local.workers
  pool = "Public"
  address = each.value.floatingip
}

# MASTER VM
resource "openstack_compute_servergroup_v2" "tf-servergroup" {
  name     = "m-servergroup"
  policies = ["anti-affinity"]
}

resource "openstack_compute_instance_v2" "master-vm" {
  for_each = local.masters
  name      = each.key
  flavor_id = openstack_compute_flavor_v2.tf_flavor1.id
  key_pair  = openstack_compute_keypair_v2.tf-keypair.name
  security_groups = [openstack_compute_secgroup_v2.w-secgroup.id]
  scheduler_hints {
    group = openstack_compute_servergroup_v2.tf-servergroup.id
  }
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.m-vol[each.key].id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  network {
    uuid = openstack_networking_network_v2.tf-network1.id
    port = openstack_networking_port_v2.m-port[each.key].id
  }
  user_data = file("user_data.yaml")
}

# WORKER VM
resource "openstack_compute_servergroup_v2" "w-servergroup" {
  name     = "w-servergroup"
  policies = ["anti-affinity"]
}

resource "openstack_compute_instance_v2" "worker-vm" {
  for_each = local.workers
  name      = each.key
  flavor_id = openstack_compute_flavor_v2.tf_flavor1.id
  key_pair  = openstack_compute_keypair_v2.tf-keypair.name
  security_groups = [openstack_compute_secgroup_v2.w-secgroup.id]
  scheduler_hints {
    group = openstack_compute_servergroup_v2.w-servergroup.id
  }
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.w-vol[each.key].id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  network {
    uuid = openstack_networking_network_v2.tf-network1.id
    port = openstack_networking_port_v2.w-port[each.key].id
  }
  user_data = file("user_data.yaml")
}

# resource "openstack_compute_volume_attach_v2" "attached" {
#   instance_id = openstack_compute_instance_v2.master-vm.id
#   volume_id   = openstack_blockstorage_volume_v2.m-vol.id
# }

resource "openstack_compute_floatingip_associate_v2" "m-fip" {
  for_each = local.masters
  floating_ip = openstack_networking_floatingip_v2.m-fip[each.key].address
  instance_id = openstack_compute_instance_v2.master-vm[each.key].id
}
resource "null_resource" "for-master" {
  for_each = local.masters
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file(var.private_key_path)
    # private_key = file("/home/achikam/.ssh/terra-keypair")
    host     = openstack_networking_floatingip_v2.m-fip[each.key].address
    # timeout  = "60s"
  }
  provisioner "remote-exec" {
    script  = "script/kube.sh"
    on_failure = continue
  }
}

resource "openstack_compute_floatingip_associate_v2" "w-fip" {
  for_each = local.workers
  floating_ip = openstack_networking_floatingip_v2.w-fip[each.key].address
  instance_id = openstack_compute_instance_v2.worker-vm[each.key].id
}
resource "null_resource" "for-worker" {
  for_each = local.workers
  connection {
    type     = "ssh"
    user     = "ubuntu"
    # private_key = file("~/.ssh/id_rsa")
    private_key = file(var.private_key_path)
    host     = openstack_networking_floatingip_v2.w-fip[each.key].address
    # timeout  = "60s"
  }
  provisioner "remote-exec" {
    script  = "script/kube.sh"
    on_failure = continue
  }
}

resource "null_resource" "kubeadm-bootstrap" {
  depends_on = [ null_resource.for-master, null_resource.for-worker ]
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file(var.private_key_path)
    # private_key = file("/home/achikam/.ssh/terra-keypair")
    host     = local.masters["master"].floatingip
    timeout  = "600s"
  }
  provisioner "remote-exec" {
    script  = "script/kubeadm-bootstrap.sh"
    on_failure = continue
  }
}

resource "null_resource" "copy-private-key" {
  depends_on = [ null_resource.kubeadm-bootstrap ]
  provisioner "file" {
    source      = "/home/achikam/.ssh/id_rsa"
    destination = "/home/ubuntu/.ssh/id_rsa"

    connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file(var.private_key_path)
    host     = local.masters["master"].floatingip
    timeout  = "600s"
    }
  }
}

resource "null_resource" "copy-join-command" {
  for_each = local.workers
  depends_on = [ null_resource.kubeadm-bootstrap, null_resource.copy-private-key ]
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file(var.private_key_path)
    host     = local.masters["master"].floatingip
  }
  provisioner "remote-exec" {
    script  = "script/kubeadm-join-worker.sh"
    on_failure = continue
  }
}

resource "null_resource" "kubeadm-complete" {
  depends_on = [ null_resource.copy-join-command ]
  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = file(var.private_key_path)
    host     = local.masters["master"].floatingip
  }
  provisioner "remote-exec" {
    script  = "script/install-cilium.sh"
    on_failure = continue
  }
}


output "floating_ip_Master" {
  value = { for fip in openstack_networking_floatingip_v2.m-fip: fip.id => fip.address }
}
output "floating_ip_Worker" {
  value = { for fip in openstack_networking_floatingip_v2.w-fip: fip.id => fip.address }
}
output "private_ip_Master" {
  value = { for private in openstack_networking_port_v2.m-port: private.id => private.fixed_ip[0].ip_address }
}
output "private_ip_Worker" {
  value = { for private in openstack_networking_port_v2.w-port: private.id => private.fixed_ip[0].ip_address }
}