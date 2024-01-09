resource "openstack_blockstorage_volume_v3" "volume_1" {
  name        = "volume_1"
  description = "first test volume"
  size        = 3
}