variable "username" {
  default = "admin-uat"
}
variable "password" {
  default = "Redhat123!@#"
}
variable "project" {
  default = "uat-project"
}
variable "domain" {
  default = "uat"
}
variable "private_key_path" {
  type = string
  default = "/home/achikam/.ssh/id_rsa"
}
