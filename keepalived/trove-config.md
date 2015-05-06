Introduction
------------


**Important:** this configuration assumes that virtual machine instances can access the controller node management network (192.168.1.0/24 in the example configuration). This requires setting up the required routes and firewall rules to ensure this is possible. Those firewall rules should allow access from the floating IP network (10.10.10.0/24) to the controller node management network.

The following commands will be executed on all controller nodes, unless otherwise stated.

Install software
----------------

    yum install -y openstack-trove python-troveclient

Configure Trove
---------------

    openstack-config --set /etc/trove/trove.conf DEFAULT bind_host 192.168.1.22X
    openstack-config --set /etc/trove/trove.conf DEFAULT log_dir /var/log/trove
    openstack-config --set /etc/trove/trove.conf DEFAULT trove_auth_url http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/trove/trove.conf DEFAULT os_region_name regionOne
    openstack-config --set /etc/trove/trove.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/trove/trove.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/trove/trove.conf oslo_messaging_rabbit rabbit_password guest
    openstack-config --set /etc/trove/trove.conf DEFAULT rpc_backend rabbit
    openstack-config --set /etc/trove/trove.conf database connection  mysql://trove:trovetest@controller-vip.example.com/trove
    openstack-config --set /etc/trove/trove.conf database max_retries -1
    openstack-config --set /etc/trove/trove.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/trove/trove.conf keystone_authtoken admin_user trove
    openstack-config --set /etc/trove/trove.conf keystone_authtoken admin_password trovetest
    openstack-config --set /etc/trove/trove.conf keystone_authtoken service_host controller-vip.example.com
    openstack-config --set /etc/trove/trove.conf keystone_authtoken identity_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/trove/trove.conf keystone_authtoken auth_uri http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/trove/trove.conf DEFAULT control_exchange trove

    openstack-config --set /etc/trove/trove-conductor.conf DEFAULT trove_auth_url http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/trove/trove-conductor.conf DEFAULT os_region_name regionOne
    openstack-config --set /etc/trove/trove-conductor.conf DEFAULT log_file trove-conductor.log
    openstack-config --set /etc/trove/trove-conductor.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/trove/trove-conductor.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/trove/trove-conductor.conf oslo_messaging_rabbit rabbit_password guest
    openstack-config --set /etc/trove/trove-conductor.conf DEFAULT rpc_backend rabbit
    openstack-config --set /etc/trove/trove-conductor.conf database connection  mysql://trove:trovetest@controller-vip.example.com/trove
    openstack-config --set /etc/trove/trove-conductor.conf database max_retries -1
    openstack-config --set /etc/trove/trove-conductor.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/trove/trove-conductor.conf keystone_authtoken admin_user trove
    openstack-config --set /etc/trove/trove-conductor.conf keystone_authtoken admin_password trovetest
    openstack-config --set /etc/trove/trove-conductor.conf keystone_authtoken service_host controller-vip.example.com
    openstack-config --set /etc/trove/trove-conductor.conf keystone_authtoken identity_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/trove/trove-conductor.conf keystone_authtoken auth_uri http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/trove/trove-conductor.conf DEFAULT control_exchange trove

    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT trove_auth_url http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT os_region_name regionOne
    openstack-config --set /etc/trove/trove-taskmanager.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/trove/trove-taskmanager.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/trove/trove-taskmanager.conf oslo_messaging_rabbit rabbit_password guest
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT rpc_backend rabbit
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user trove
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass trovetest
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_name ${SERVICES_TENANT_ID}
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT log_file trove-taskmanager.log
    openstack-config --set /etc/trove/trove-taskmanager.conf database connection  mysql://trove:trovetest@controller-vip.example.com/trove
    openstack-config --set /etc/trove/trove-taskmanager.conf database max_retries -1
    openstack-config --set /etc/trove/trove-taskmanager.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/trove/trove-taskmanager.conf keystone_authtoken admin_user trove
    openstack-config --set /etc/trove/trove-taskmanager.conf keystone_authtoken admin_password trovetest
    openstack-config --set /etc/trove/trove-taskmanager.conf keystone_authtoken service_host controller-vip.example.com
    openstack-config --set /etc/trove/trove-taskmanager.conf keystone_authtoken identity_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_uri http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT cloudinit_loaction /etc/trove/cloudinit
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT network_driver trove.network.neutron.NeutronDriver
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT control_exchange trove
    # The following is a workaround for https://bugs.launchpad.net/trove/+bug/1402055
    openstack-config --set /etc/trove/trove-taskmanager.conf DEFAULT exists_notification_transformer

    openstack-config --set /etc/trove/trove.conf DEFAULT default_datastore mysql
    openstack-config --set /etc/trove/trove.conf DEFAULT add_addresses True
    openstack-config --set /etc/trove/trove.conf DEFAULT network_label_regex ^private$

    cp /usr/share/trove/trove-dist-paste.ini /etc/trove/api-paste.ini
    openstack-config --set /etc/trove/api-paste.ini filter:authtoken auth_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/trove/api-paste.ini filter:authtoken identity_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/trove/api-paste.ini filter:authtoken admin_password trovetest
    openstack-config --set /etc/trove/api-paste.ini filter:authtoken admin_user trove
    openstack-config --set /etc/trove/api-paste.ini filter:authtoken admin_tenant_name services
    openstack-config --set /etc/trove/trove.conf DEFAULT api_paste_config /etc/trove/api-paste.ini


Manage DB
---------

On node 1:

    su trove -s /bin/sh -c "trove-manage db_sync"
    trove-manage datastore_update mysql ''

Create and upload image
-----------------------

Trove instances will require a specially crafted virtual machine image with the required database software. The following instructions will create a simple image based on CentOS 7 with MariaDB 5.5. [This article](https://www.rdoproject.org/forum/discussion/1010/creation-of-trove-compatible-images-for-rdo/p1) provides detailed instructions on how to create a Trove-compatible image using trove-image-elements.

Please note that only limited testing has been performed with the image. These instructions can be updated over time, please feel free to provide feedback if you have a chance to test them.

On all controller nodes, create /etc/trove/cloudinit/mysql.cloudinit with the following contents:

    #!/bin/bash

    sed -i'.orig' -e's/without-password/yes/' /etc/ssh/sshd_config
    echo "test" | passwd --stdin centos
    echo "redhat" | passwd --stdin root
    service sshd restart

    yum -y install wget epel-release    
    yum -y install http://rdoproject.org/repos/openstack-kilo/rdo-testing-kilo.rpm
    yum -y install openstack-trove-guestagent mariadb-server openstack-utils python-oslo-messaging python-osprofiler python-oslo-concurrency

    systemctl enable mariadb
    systemctl start mariadb

    echo "trove ALL=(ALL)  NOPASSWD: ALL" >> /etc/sudoers
    echo "Defaults:trove !requiretty" >> /etc/sudoers
    
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_hosts 192.168.1.221,192.168.1.222,192.168.1.113
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_password guest
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_user trove
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_pass trovetest
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_tenant_name services
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT trove_auth_url http://192.168.1.220:35357/v2.0
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT control_exchange trove
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT log_dir /var/log/trove
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT log_file trove-guestagent.log
    openstack-config --set /etc/trove/trove-guestagent.conf DEFAULT datastore_manager mysql

    echo "${TRUSTED_SSH_KEY}" >> /root/.ssh/authorized_keys

    echo "${TRUSTED_SSH_KEY}" >> /home/centos/.ssh/authorized_keys

    systemctl stop openstack-trove-guestagent
    systemctl enable openstack-trove-guestagent
    systemctl start openstack-trove-guestagent

**Note:** Be aware that trove-guestagent needs https://bugzilla.redhat.com/show_bug.cgi?id=1219069 to be fixed.

On node 1:

Get a CentOS 7 cloud image, and upload it to Glance

    wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
    glance image-create --name centos7 --disk-format qcow2 --container-format bare --is-public True --owner trove --file CentOS-7-x86_64-GenericCloud.qcow2

Take note of the image id, then update the Trove database with a reference to the newly uploaded image:
    
    trove-manage --config-file=/etc/trove/trove.conf datastore_version_update mysql mysql-5.5 mysql 9b412ead-5a5c-40ba-ac8f-98f70cc4f682 mysql55 1
    trove-manage db_load_datastore_config_parameters mysql "mysql-5.5"  /usr/lib/python2.7/site-packages/trove/templates/mysql/validation-rules.json

Start services, open firewall ports
-----------------------------------
On all nodes:

    systemctl enable openstack-trove-api
    systemctl enable openstack-trove-taskmanager
    systemctl enable openstack-trove-conductor
    systemctl start openstack-trove-api
    systemctl start openstack-trove-taskmanager
    systemctl start openstack-trove-conductor
    firewall-cmd --add-port=8779/tcp
    firewall-cmd --add-port=8779/tcp --permanent
