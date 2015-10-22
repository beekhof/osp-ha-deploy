Introduction
------------

Cinder will be configured in this example to use the NFS backend driver. Instructions for any other backend driver will only differ in the `volume_driver` config option and any driver-specific options.

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/cinder.scenario).

Install software
----------------

    yum install -y openstack-cinder openstack-utils openstack-selinux python-memcached

Configure
---------

    openstack-config --set /etc/cinder/cinder.conf database connection mysql://cinder:cindertest@controller-vip.example.com/cinder
    openstack-config --set /etc/cinder/cinder.conf database max_retries -1
    openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
    openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://controller-vip.example.com:5000/
    openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_plugin password
    openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://controller-vip.example.com:35357/
    openstack-config --set /etc/cinder/cinder.conf keystone_authtoken username cinder
    openstack-config --set /etc/cinder/cinder.conf keystone_authtoken password cindertest
    openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_name services
    openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver messaging
    openstack-config --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
    openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host controller-vip.example.com
    openstack-config --set /etc/cinder/cinder.conf DEFAULT memcache_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/cinder/cinder.conf DEFAULT host rhos7-cinder
    openstack-config --set /etc/cinder/cinder.conf DEFAULT osapi_volume_listen 192.168.1.22X
    openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/cinder/cinder.conf DEFAULT encryption_auth_url http://controller-vip.example.com:5000/v3

**Note:** We are setting a single "host" entry for all nodes, this is related to the A/P issues with cinder-volume.

Configure NFS driver
--------------------

    # Choose whatever NFS share is used

    cat > /etc/cinder/nfs_exports << EOF
    192.168.1.4:/volumeUSB1/usbshare/openstack/cinder 
    EOF

    chown root:cinder /etc/cinder/nfs_exports
    chmod 0640 /etc/cinder/nfs_exports
    openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_shares_config /etc/cinder/nfs_exports
    openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_sparsed_volumes true
    openstack-config --set /etc/cinder/cinder.conf DEFAULT nfs_mount_options v3
    openstack-config --set /etc/cinder/cinder.conf DEFAULT volume_driver cinder.volume.drivers.nfs.NfsDriver

Manage DB
---------

On node 1:

    su cinder -s /bin/sh -c "cinder-manage db sync"

Start services
--------------

On node 1:

    systemctl start openstack-cinder-api
    systemctl start openstack-cinder-scheduler
    systemctl start openstack-cinder-volume
    systemctl enable openstack-cinder-api
    systemctl enable openstack-cinder-scheduler
    systemctl enable openstack-cinder-volume

**Note:** If this node crashes, it should be manually started on another node. Refer to [this bug](https://bugzilla.redhat.com/show_bug.cgi?id=1193229) for additional information.

On nodes 2 and 3:

    systemctl start openstack-cinder-api
    systemctl start openstack-cinder-scheduler
    systemctl enable openstack-cinder-api
    systemctl enable openstack-cinder-scheduler

Open firewall ports
-------------------

On all nodes:

    firewall-cmd --add-port=8776/tcp
    firewall-cmd --add-port=8776/tcp --permanent

Test
----

On any node:

    . /root/keystonerc_demo
    cinder create --display-name test 1
    cinder extend test 4
    cinder delete test
