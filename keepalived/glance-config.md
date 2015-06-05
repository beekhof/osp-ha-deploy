Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/glance.scenario).

Install software
----------------

    yum install -y openstack-glance openstack-utils openstack-selinux nfs-utils

Configure glance-api and glance-registry
----------------------------------------

    openstack-config --set /etc/glance/glance-api.conf database connection mysql://glance:glancetest@controller-vip.example.com/glance
    openstack-config --set /etc/glance/glance-api.conf database max_retries -1
    openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
    openstack-config --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://controller-vip.example.com:35357/ 
    openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_user glance
    openstack-config --set /etc/glance/glance-api.conf keystone_authtoken admin_password glancetest
    openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver messaging
    openstack-config --set /etc/glance/glance-api.conf DEFAULT bind_host 192.168.1.22X
    openstack-config --set /etc/glance/glance-api.conf DEFAULT registry_host controller-vip.example.com
    openstack-config --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/glance/glance-registry.conf database connection mysql://glance:glancetest@controller-vip.example.com/glance
    openstack-config --set /etc/glance/glance-registry.conf database max_retries -1
    openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
    openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_user glance
    openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password glancetest
    openstack-config --set /etc/glance/glance-registry.conf DEFAULT bind_host 192.168.1.22X

Manage DB
---------

On node 1:

    su glance -s /bin/sh -c "glance-manage db_sync"

Configure backend
-----------------

For this setup, NFS will be used. Add the NFS mount to `/etc/fstab`, making sure it is mounted on `/var/lib/glance`. Be aware the last two columns in `fstab` need to be "0 0" on RHEL/CentOS 7, due to [this bug](https://bugzilla.redhat.com/show_bug.cgi?id=1120367). You may also find [this bug](https://bugzilla.redhat.com/show_bug.cgi?id=1203820) if using NFS v3 shares.

Also, note there is currently a known SELinux issue when using an NFS backend for Glance. See [this bug](https://bugzilla.redhat.com/show_bug.cgi?id=1219406) for a description and fix.

On all nodes:

    chown glance:nobody /var/lib/glance

Start services and open firewall ports
--------------------------------------

    systemctl start openstack-glance-registry
    systemctl start openstack-glance-api
    systemctl enable openstack-glance-registry
    systemctl enable openstack-glance-api
    firewall-cmd --add-port=9191/tcp
    firewall-cmd --add-port=9191/tcp --permanent
    firewall-cmd --add-port=9292/tcp
    firewall-cmd --add-port=9292/tcp --permanent

Test
----

On any node:

    . /root/keystonerc_admin

    glance image-create --name "cirros" --is-public true --disk-format qcow2 --container-format bare --location http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img

    glance image-list
