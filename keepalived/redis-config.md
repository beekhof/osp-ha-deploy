Introduction
------------

Redis in a key-value cache and store, used by Ceilometer with the [tooz](https://github.com/openstack/tooz) library. It uses an master-slave architecture for high availability, where a single node is used for writes and a number of slaves replicate data from it. Using [Sentinel](http://redis.io/topics/sentinel), it is possible monitor node health and fail over automatically to another node if needed. By configuring Ceilometer to access the Sentinel processes, high availability from the consumer point of view is transparent.

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/redis.scenario).

Install redis
-------------

    yum install -y redis

Configure bind IP, set master and slaves
----------------------------------------

On node 1:

    sed --in-place 's/bind 127.0.0.1/bind 127.0.0.1 192.168.1.X/' /etc/redis.conf

On node2 and 3:

    sed --in-place 's/bind 127.0.0.1/bind 127.0.0.1 192.168.1.X/' /etc/redis.conf
    echo slaveof ''<hacontroller1 IP>'' 6379 >> /etc/redis.conf 

Configure Sentinel, used for master failover
--------------------------------------------

**On all nodes:**

    cat > /etc/redis-sentinel.conf << EOF

    sentinel monitor mymaster <hacontroller1 IP> 6379 2
    sentinel down-after-milliseconds mymaster 30000
    sentinel failover-timeout mymaster 180000
    sentinel parallel-syncs mymaster 1
    min-slaves-to-write 1
    min-slaves-max-lag 10
    logfile /var/log/redis/sentinel.log
    EOF

Configure firewall, start services
----------------------------------

    firewall-cmd --add-port=6379/tcp
    firewall-cmd --add-port=6379/tcp --permanent
    firewall-cmd --add-port=26379/tcp
    firewall-cmd --add-port=26379/tcp --permanent
    systemctl enable redis
    systemctl start redis
    systemctl enable redis-sentinel
    systemctl start redis-sentinel
