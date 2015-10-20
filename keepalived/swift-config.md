Introduction
------------

We need to have an additional disk, `/dev/vdb` in our test available for Swift usage.

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/swift.scenario).

Install software
----------------

    yum install -y openstack-swift-object openstack-swift-container openstack-swift-account openstack-swift-proxy openstack-utils rsync xfsprogs

Create XFS file system for additional disk, and mount it
--------------------------------------------------------

    mkfs.xfs /dev/vdb
    mkdir -p /srv/node/vdb
    echo "/dev/vdb /srv/node/vdb xfs defaults 1 2" >> /etc/fstab
    mount -a 
    chown -R swift:swift /srv/node
    restorecon -R /srv/node

Configure account, container and object services
------------------------------------------------

    openstack-config --set /etc/swift/object-server.conf DEFAULT bind_ip 192.168.1.22X
    openstack-config --set /etc/swift/object-server.conf DEFAULT devices /srv/node
    openstack-config --set /etc/swift/account-server.conf DEFAULT bind_ip 192.168.1.22X
    openstack-config --set /etc/swift/account-server.conf DEFAULT devices /srv/node
    openstack-config --set /etc/swift/container-server.conf DEFAULT bind_ip 192.168.1.22X
    openstack-config --set /etc/swift/container-server.conf DEFAULT devices /srv/node
    chown -R root:swift /etc/swift

Start account, container and object services, open firewall ports
-----------------------------------------------------------------

    systemctl start openstack-swift-account
    systemctl start openstack-swift-container
    systemctl start openstack-swift-object
    systemctl enable openstack-swift-account
    systemctl enable openstack-swift-container
    systemctl enable openstack-swift-object

    firewall-cmd --add-port=6200/tcp
    firewall-cmd --add-port=6200/tcp --permanent
    firewall-cmd --add-port=6201/tcp
    firewall-cmd --add-port=6201/tcp --permanent
    firewall-cmd --add-port=6202/tcp
    firewall-cmd --add-port=6202/tcp --permanent

Configure swift proxy and object expirer
----------------------------------------

    openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_uri https://controller-vip.example.com:5000/
    openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_plugin password
    openstack-config --set /etc/swift/proxy-server.conf filter:authtoken auth_url http://controller-vip.example.com:35357/
    openstack-config --set /etc/swift/proxy-server.conf filter:authtoken username swift
    openstack-config --set /etc/swift/proxy-server.conf filter:authtoken password swifttest
    openstack-config --set /etc/swift/proxy-server.conf filter:authtoken project_name services
    openstack-config --set /etc/swift/proxy-server.conf filter:cache memcache_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/swift/proxy-server.conf DEFAULT bind_ip 192.168.1.22X
    openstack-config --set /etc/swift/object-expirer.conf filter:cache memcache_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/swift/object-expirer.conf object-expirer concurrency 100

Configure hash path suffix
--------------------------

On node 1:

    openstack-config --set /etc/swift/swift.conf swift-hash swift_hash_path_suffix $(openssl rand -hex 10)

Set Ceilometer hook
-------------------

On node 1:

    cat >> /etc/swift/swift.conf << EOF
    [filter:ceilometer]
    use = egg:ceilometer#swift
    [pipeline:main]
    pipeline = healthcheck cache authtoken keystoneauth proxy-server ceilometer
    EOF

Create rings
------------

On node 1:

    swift-ring-builder /etc/swift/object.builder create 16 3 24
    swift-ring-builder /etc/swift/container.builder create 16 3 24
    swift-ring-builder /etc/swift/account.builder create 16 3 24
    swift-ring-builder /etc/swift/account.builder add z1-192.168.1.221:6202/vdb 10
    swift-ring-builder /etc/swift/container.builder add z1-192.168.1.221:6201/vdb 10
    swift-ring-builder /etc/swift/object.builder add z1-192.168.1.221:6200/vdb 10
    swift-ring-builder /etc/swift/account.builder add z2-192.168.1.222:6202/vdb 10
    swift-ring-builder /etc/swift/container.builder add z2-192.168.1.222:6201/vdb 10
    swift-ring-builder /etc/swift/object.builder add z2-192.168.1.222:6200/vdb 10
    swift-ring-builder /etc/swift/account.builder add z3-192.168.1.223:6202/vdb 10
    swift-ring-builder /etc/swift/container.builder add z3-192.168.1.223:6201/vdb 10
    swift-ring-builder /etc/swift/object.builder add z3-192.168.1.223:6200/vdb 10
    swift-ring-builder /etc/swift/account.builder rebalance
    swift-ring-builder /etc/swift/container.builder rebalance
    swift-ring-builder /etc/swift/object.builder rebalance

    cd /etc/swift
    tar cvfz /tmp/swift_configs.tgz swift.conf *.builder *.gz
    scp /tmp/swift_configs.tgz hacontroller2:/tmp
    scp /tmp/swift_configs.tgz hacontroller3:/tmp
    chown -R root:swift /etc/swift

Import swift configuration from node 1
--------------------------------------

On nodes 2 and 3:

    cd /etc/swift
    tar xvfz /tmp/swift_configs.tgz
    chown -R root:swift /etc/swift
    restorecon -R /etc/swift

Start services, open firewall ports
-----------------------------------

On all nodes:

    systemctl start openstack-swift-proxy
    systemctl enable openstack-swift-proxy
    systemctl start openstack-swift-object-expirer
    systemctl enable openstack-swift-object-expirer
    firewall-cmd --add-port=8080/tcp
    firewall-cmd --add-port=8080/tcp --permanent

Test
----

On any node:

    . /root/keystonerc_admin
    swift list
    swift upload test /tmp/cirros-0.3.3-x86_64-disk.img 
    swift list
    swift list test
    swift download test tmp/cirros-0.3.3-x86_64-disk.img
