Introduction
------------

Memcached is a general-purpose distributed memory caching system. It is used to speed up dynamic database-driven websites by caching data and objects in RAM to reduce the number of times an external data source must be read.

**Note:** Access to memcached is not handled by HAproxy because replicated access is currently only in an experimental state. Instead consumers must be supplied with the full list of hosts running memcached.

The following commands will be executed on all controller nodes.

Install and enable memcached
----------------------------

    yum install -y memcached
    systemctl start memcached
    systemctl enable memcached
    firewall-cmd --add-port=11211/tcp
    firewall-cmd --add-port=11211/tcp --permanent
