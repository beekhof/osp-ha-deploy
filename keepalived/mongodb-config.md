Introduction
------------

MongoDB can provide high availability through the use of replica sets. A replica set in MongoDB is a group of mongod processes that maintain the same data set, where one of the nodes is specified as master and the rest as slaves. Clients are explicitly told to connect to the replica set, by specifying all its members. In case of a node failure, the client should transparently reconnect to a surviving replica.

The following commands will be executed on all controller nodes, unless otherwise stated.

Install packages
----------------

    yum install -y mongodb mongodb-server

Listen to external connections, and configure replication set
-------------------------------------------------------------

    sed -i -e 's#bind_ip.*#bind_ip = 0.0.0.0#g' /etc/mongodb.conf
    echo "replSet = ceilometer" >> /etc/mongodb.conf 

Start services and enable firewall ports
----------------------------------------

    systemctl start mongod
    systemctl enable mongod
    firewall-cmd --add-port=27017/tcp
    firewall-cmd --add-port=27017/tcp --permanent

Create replica set
------------------

On node 1:

    mongo


    > rs.initiate()
    > sleep(10000)
    > rs.add("hacontroller1.example.com");
    > rs.add("hacontroller2.example.com");
    > rs.add("hacontroller3.example.com");

And verify:

    > rs.status()

Until all nodes show `"stateStr" : "PRIMARY"` or `"stateStr" : "SECONDARY"`, then:

    > quit()
