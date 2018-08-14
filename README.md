

# About

The purpose of this project is to make it easy to run various load
tests on systems with FoundationDB in the cloud.

We can achieve that by:

1. "Prebaking" cloud-specific VM images for the FoundationDB cluster
   nodes along with the tester nodes.
2. Using these images to quickly create FoundationDB clusters with the
   specific configuration.

The first step is handled by the [Packer](https://www.packer.io), the
second - by the [Terraform](https://www.terraform.io). If you're using 
a Mac you can install them using homebrew:

```
brew install packer terraform
```

The scripts are based on [bitgn/fdb-cloud-test](https://github.com/bitgn/fdb-cloud-test)

# Creating AMIs

First you need to create packer images for FDB and tester
machines. 

Note, that in this setup we actually create a temporary EC2 instance
in the cloud, install all the dependencies there, make a snapshot
(AMI) and terminate the original machine. With these snapshots we could
then quickly launch a dozen of EC2 instances, connecting them into a
cluster.

You can create a FoundationDB AMI like this (make sure to fill in your
AWS credentials):

```
$ export AWS_ACCESS_KEY=""
$ export AWS_SECRET_KEY=""
$ cd packer
$ make
```

# Deploying Clusters

## Setup Terraform

Before deploying pre-baked images into AWS you need to configure your
working copy first. Install Terraform, then go to the `terraform`
folder of this repository and execute:

```
$ make init
```

Then, you would need to create a file `.secret.aws.tfvars`, filling it
with your AWS credentials:

```
aws_access_key = ""
aws_secret_key = ""
aws_account_id = ""
```

Afterwards you would also need to create a new ssh key called
`terraform` and place it into your `~/.ssh/` folder. Terraform will
install it into all the new machines, making it possible for you to
connect to them via ssh.

You can do that with:

```
$ ssh-keygen -t rsa -b 4096 -C "terraform" -f "$HOME/.ssh/terraform"
```

## Deploy a cluster

In order to deploy a cluster you would need to execute the following
in the `terraform` folder:

```
# prepare terraform plan, using a separate file with the credentials
$ make plan
# prepare and carry out the plan
$ make apply
```

The process should take 3-4 minutes and print out in the end something
like this:

```
aws_instance.fdb[0]: Creation complete after 3m32s (ID: i-0b90a62a90636c1ad)

Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

fdb_address = [
    fdb-01.amazonaws.com,
    fdb-02.amazonaws.com,
    fdb-03.amazonaws.com
]
fdb_cluster = Drtu0T4S:i8uQIB9r@10.0.1.101:4500
fdb_init_string = configure new memory single proxies=9 resolvers=9 logs=4
tester_address = [
    tester-01.amazonaws.com
]
```

Note that the machine names would be different each time (and much
longer). This is just a sample output.

Congratulations, you now have a FoundationDB cluster running in
AWS. 

## Verify your deployment

You can check it by connecting to any machine with your
terraform key:

```
$ ssh -i ~/.ssh/terraform ubuntu@tester-01.amazonaws.com
```

On your first connection, the ssh might ask you about accepting the
new fingerprint. This happens because we have a brand new server
running. Just type in 'yes'.

Once connected to a machine, you could verify that the client
tools are installed and the cluster is responding:

```
$ fdbcli
Using cluster file `/etc/foundationdb/fdb.cluster'.

The database is available.

Welcome to the fdbcli. For help, type `help'.
fdb> status details

Using cluster file `/etc/foundationdb/fdb.cluster'.

Configuration:
  Redundancy mode        - double
  Storage engine         - ssd-2
  Coordinators           - 3
  
...
```

Congratulations, FDB cluster is up and running!

# Running tests

Tests run from fdb instances with the `test` role. The test definition can 
be found in `terraform/test.conf`. To run tests on a single core type:

```
$ make test
...
setting up test (RandomReadWriteTest)...
Test received trigger for setup...
running test...
ReadWrite complete
RandomReadWriteTest complete
checking tests...
fetching metrics...
Metric (0, 0): Measured Duration, 10.000000, 10
Metric (0, 1): Transactions/sec, 7312.100000, 7.31e+03
Metric (0, 2): Operations/sec, 73121.000000, 7.31e+04
Metric (0, 3): A Transactions, 73121.000000, 73121
Metric (0, 4): B Transactions, 0.000000, 0
Metric (0, 5): Retries, 1114.000000, 1114
Metric (0, 6): Mean load time (seconds), 0.000000, 0
Metric (0, 7): Read rows, 658089.000000, 6.58e+05
Metric (0, 8): Write rows, 73121.000000, 7.31e+04
Metric (0, 9): Mean Latency (ms), 2702.319528, 2.7e+03
Metric (0, 10): Median Latency (ms, averaged), 2695.211649, 2.7e+03
Metric (0, 11): 90% Latency (ms, averaged), 4515.662670, 4.52e+03
Metric (0, 12): 98% Latency (ms, averaged), 4883.429766, 4.88e+03
Metric (0, 13): Max Latency (ms, averaged), 4981.800556, 4.98e+03
Metric (0, 14): Mean Row Read Latency (ms), 1.525933, 1.53
Metric (0, 15): Median Row Read Latency (ms, averaged), 1.519918, 1.52
Metric (0, 16): Max Row Read Latency (ms, averaged), 3.243923, 3.24
Metric (0, 17): Mean Total Read Latency (ms), 1.746427, 1.75
Metric (0, 18): Median Total Read Latency (ms, averaged), 1.638174, 1.64
Metric (0, 19): Max Total Latency (ms, averaged), 3.243923, 3.24
Metric (0, 20): Mean GRV Latency (ms), 4760.292973, 4.76e+03
Metric (0, 21): Median GRV Latency (ms, averaged), 5482.825041, 5.48e+03
Metric (0, 22): Max GRV Latency (ms, averaged), 6889.936924, 6.89e+03
Metric (0, 23): Mean Commit Latency (ms), 2.517775, 2.52
Metric (0, 24): Median Commit Latency (ms, averaged), 2.553701, 2.55
Metric (0, 25): Max Commit Latency (ms, averaged), 7.510185, 7.51
Metric (0, 26): Read rows/sec, 65808.900000, 6.58e+04
Metric (0, 27): Write rows/sec, 7312.100000, 7.31e+03
Metric (0, 28): Bytes read/sec, 6975743.400000, 6.98e+06
Metric (0, 29): Bytes written/sec, 775082.600000, 7.75e+05
1 test clients passed; 0 test clients failed

1 tests passed; 0 tests failed, waiting for DD to end...
```

It will upload the test definition to a server and then run it. Running on a 
single core is usually not enough to saturate the cluster, so most of 
the time you should instead run 

```
$ make multitest
```

This will execute the test from all available test processes and output 
results from each of them. To get the totals you usually want to sum 
or average the results from each process.

# Modifying the cluster

You can tune the cluster configuration by editing `variables.tf` file
to your liking. Ideally, you would do that before creating a new
cluster.

The configuration for each node is stored in `conf/*.ini` files. Each file 
corresponds to a node with the same number (you will have to create 
more config files if you want to make your cluster larger). Testing nodes have 
identical configs stored in `conf/tester.ini`. The configs are intentionally made as 
a separate files instead of a script that generates them from an array of roles 
to allow easy per process tuning, for example adding memory to storage processess. 

You can quickly update configs on all your cluster nodes without recreating or restarting them by using

```
$ make reconfigure
```

This is done by copying configs to the corresponding nodes via `scp`, fdb should automatically 
detect and apply the config file changes. To avoid being asked about new fingerprints, 
you may want to fetch them all first with the following command, this needs to be done 
only once after the cluster deployment

```
$ make add-keys
```

If you want to clear all keys in your DB you can use

```
$ make clean
```

# Monitoring performance

Most useful things can be monitored by running included [fdbtop](https://github.com/poma/fdbtop)
utility on one of your test nodes (run `fdbtop --help` for more info). 

```
$ fdbtop

<ip>          port    cpu%  mem%  iops  net    class                 roles
------------  ------  ----  ----  ----  -----  --------------------  --------------------
 10.0.2.101    4500    5     3     6     2      cluster_controller    cluster_controller
               4501    84    6     6     143    transaction           log
               4504    1     2     6     0      proxy
               4505    87    3     6     182    proxy                 proxy
               4506    0     3     6     0      resolution
               4507    27    2     6     9      master                master
------------  ------  ----  ----  ----  -----  --------------------  --------------------
 10.0.2.102    4500    58    6     4     91     transaction           log
               4501    1     2     4     0      proxy
               4504    58    3     4     116    proxy                 proxy
               4505    58    3     4     117    proxy                 proxy
               4506    38    4     4     34     resolution            resolver
               4507    0     2     4     0      master
------------  ------  ----  ----  ----  -----  --------------------  --------------------
 10.0.2.103    4500    83    16    33    46     storage               storage
               4501    0     2     33    0      proxy
               4503    92    18    33    78     storage               storage
               4504    45    3     33    102    proxy                 proxy
               4505    0     2     33    0      proxy
               4506    25    3     33    30     resolution            resolver
               4507    0     2     33    0      master
```

You can also monitor general stats by running `status` command in 
fdbcli or calling it periodically with `watch`:

```
watch "fdbcli --exec status"
```

Alternatively, you may want to feed the output of 
`fdbcli --exec 'status json'` command to your monitoring tool of choice.

Most of the time you need to watch if any of your `log` or `storage` 
processes saturate the disk iops, and whether any role saturates its CPU core.

# Destroying the cluster

Keeping AWS instances running costs money. So generally it is advised
to destroy all the resources after the experiment.

Terraform makes it easy:

```
$ make destroy

....

Plan: 0 to add, 0 to change, 12 to destroy.

Do you really want to destroy?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
  
....

Destroy complete! Resources: 12 destroyed.

```