#!/bin/bash
sudo service foundationdb stop
sudo cp /tmp/foundationdb.conf /etc/foundationdb/foundationdb.conf
echo "Drtu0T4S:i8uQIB9r@10.0.2.101:4500" | sudo tee /etc/foundationdb/fdb.cluster > /dev/null
sudo rm -rf /var/lib/foundationdb/data
#sudo service foundationdb start
