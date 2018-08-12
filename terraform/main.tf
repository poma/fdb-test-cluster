provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
  version    = "~> 1.30"
}

provider "random" {
  version    = "~> 1.3"
}



// Find our latest available AMI for the fdb node
// TODO: switch to a shared and hosted stable image
data "aws_ami" "fdb" {
  most_recent = true
 
  filter {
    name = "name"
    values = ["poma-fdb"]
  }
  owners = ["self"]
}


# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  # this will solve sudo: unable to resolve host ip-10-0-xx-xx
  enable_dns_hostnames = true

  tags = {
    Name = "FDB Test"
    Project = "TF:poma"
  }
}


# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

}
# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}


# Create a subnet to launch our instances into
resource "aws_subnet" "db" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_availability_zone}"

  tags = {
    Name = "FDB Subnet"
    Project = "TF:poma"
  }
}


# security group with SSH and FDB access
resource "aws_security_group" "fdb_group" {
  name        = "tf_fdb_group"
  description = "Terraform: SSH and FDB"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FDB access from the VPC. We open a port for each process
  ingress {
    from_port   = 4500
    to_port     = "${4500 + var.fdb_procs_per_machine - 1}"
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Random cluster identifier strings
resource "random_string" "cluster_description" {
  length = 8
  special = false
}
resource "random_string" "cluster_id" {
  length = 8
  special = false
}

locals {
  # FDB seed controller
  fdb_seed = "${cidrhost(aws_subnet.db.cidr_block, 101)}"
  # fdb.cluster file contents
  fdb_cluster = "${random_string.cluster_description.result}:${random_string.cluster_id.result}@${local.fdb_seed}:4500"
}

resource "aws_instance" "fdb" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"
    agent = "false"

    private_key = "${file(var.private_key_path)}"
    # The connection will use the local SSH agent for authentication.
  }


  availability_zone = "${var.aws_availability_zone}"
  instance_type = "${var.aws_fdb_size}"
  count = "${var.aws_fdb_count}"
  # Grab AMI id from the data source
  ami = "${data.aws_ami.fdb.id}"


  # I want a very specific IP address to be assigned. However
  # AWS reserves both the first four IP addresses and the last IP address
  # in each subnet CIDR block. They're not available for you to use.
  private_ip = "${cidrhost(aws_subnet.db.cidr_block, count.index + 1 + 100)}"


  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.fdb_group.id}"]

  # We're going to launch into the DB subnet
  subnet_id = "${aws_subnet.db.id}"

  tags {
    Name = "${format("fdb-%02d", count.index + 1)}"
    Project = "TF:poma"
  }

  provisioner "file" {
    source      = "init.sh"
    destination = "/tmp/init.sh"
  }

  provisioner "file" {
    source      = "conf/${count.index + 1}.ini"
    destination = "/etc/foundationdb/foundationdb.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/init.sh",
      "sudo /tmp/init.sh ${var.aws_fdb_size} ${self.private_ip} ${local.fdb_seed} '${local.fdb_cluster}' '${var.fdb_init_string}'",
    ]
  }
}


resource "aws_instance" "tester" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"
    agent = "false"

    private_key = "${file(var.private_key_path)}"
    # The connection will use the local SSH agent for authentication.
  }


  availability_zone = "${var.aws_availability_zone}"
  instance_type = "${var.aws_fdb_size}"
  count = "${var.aws_tester_count}"
  # Grab AMI id from the data source
  ami = "${data.aws_ami.fdb.id}"

    # I want a very specific IP address to be assigned. However
  # AWS reserves both the first four IP addresses and the last IP address
  # in each subnet CIDR block. They're not available for you to use.
  private_ip = "${cidrhost(aws_subnet.db.cidr_block, count.index + 1 + 200)}"


  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.fdb_group.id}"]

  # We're going to launch into the DB subnet
  subnet_id = "${aws_subnet.db.id}"

  tags {
    Name = "${format("fdb-tester-%02d", count.index + 1)}"
    Project = "TF:poma"
  }

  provisioner "file" {
    source      = "init.sh"
    destination = "/tmp/init.sh"
  }

  provisioner "file" {
    source      = "conf/tester.ini"
    destination = "/etc/foundationdb/foundationdb.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/init.sh",
      "sudo /tmp/init.sh ${var.aws_fdb_size} ${self.private_ip} ${local.fdb_seed} '${local.fdb_cluster}' '${var.fdb_init_string}'",
    ]
  }
}
