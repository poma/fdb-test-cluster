####### Cluster options ####

# instance store options: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html
# m5d.2xlarge - will use local NVMe SSD
variable "aws_fdb_size" {
  default = "m5d.2xlarge"
  description = "machine type to run FoundationDB servers"
}
variable "fdb_procs_per_machine" {
  default = 8
  description = "number of FDB processes per machine"
}
variable "aws_fdb_count" {
  default = 8
  description = "Number of machines in a cluster"
}
variable "aws_tester_count" {
  default = 2
  description = "Number of tester machines in a cluster"
}
variable "fdb_init_string" {
  default = "configure new memory single proxies=9 resolvers=9 logs=4"
  description = "FDB initialization string"
}

####### Misc options #######

# todo maybe just use the default ssh key?
variable "public_key_path" {
  description = "Path to the SSH public key to be used for authentication."
  default = "~/.ssh/terraform.pub"
}
variable "private_key_path" {
  description = "Path to the SSH private key"
  default = "~/.ssh/terraform"
}
variable "key_name" {
   default = "terraform"
}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
  default = "eu-west-1"
  description = "AWS region to launch servers."
}
variable "aws_availability_zone" {
  default = "eu-west-1b"
}