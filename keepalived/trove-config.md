Introduction
------------

**Note: This section is still work in progress. It does not work 100%, so expect changes during the next few days.** Some info taken from https://access.redhat.com/solutions/1318703.

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

**Note: still WIP**

Create /etc/trove/cloudinit/mysql.cloudinit with the following contents:

    #!/bin/bash

    sed -i'.orig' -e's/without-password/yes/' /etc/ssh/sshd_config
    echo "test" | passwd --stdin cloud-user
    echo "redhat" | passwd --stdin root
    service sshd restart

    yum -y install wget
    cd /etc/yum.repos.d
    wget https://repos.fedorapeople.org/repos/openstack/openstack-trunk/epel-7/rc2/delorean-kilo.repo
    yum -y install yum install http://rdoproject.org/repos/openstack-kilo/rdo-release-kilo.rpm
    yum -y install openstack-trove-guestagent mariadb-server
    
    cat << EOF > /etc/trove/trove-guestagent.conf
    rabbit_host = 192.168.1.221
    rabbit_password = guest
    nova_proxy_admin_user = trove
    nova_proxy_admin_pass = trovetest
    nova_proxy_admin_tenant_name = services
    trove_auth_url = http://192.168.1.220:35357/v2.0
    control_exchange = trove
    EOF

    echo "${TRUSTED_SSH_KEY}" >> /root/.ssh/authorized_keys

    echo "${TRUSTED_SSH_KEY}" >> /home/centos/.ssh/authorized_keys

    systemctl stop trove-guestagent
    systemctl enable trove-guestagent
    systemctl start trove-guestagent

Get a CentOS 7 cloud image, and upload it to Glance

    wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
    glance image-create --name centos7 --disk-format qcow2 --container-format bare --is-public True --owner trove --file CentOS-7-x86_64-GenericCloud.qcow2

Take note of the image id, then update the Trove database with a reference to the newly uploaded image:
    
    trove-manage --config-file=/etc/trove/trove.conf datastore_version_update mysql mysql-5.5 mysql 9b412ead-5a5c-40ba-ac8f-98f70cc4f682 mysql55 1
    trove-manage db_load_datastore_config_parameters mysql "mysql-5.5"  /usr/lib/python2.7/site-packages/trove/templates/mysql/validation-rules.json

Start services, open firewall ports
-----------------------------------
    systemctl enable openstack-trove-api
    systemctl enable openstack-trove-taskmanager
    systemctl enable openstack-trove-conductor
    systemctl start openstack-trove-api
    systemctl start openstack-trove-taskmanager
    systemctl start openstack-trove-conductor
    firewall-cmd --add-port=8779/tcp
    firewall-cmd --add-port=8779/tcp --permanent
