Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

Install software
----------------

    yum install -y openstack-keystone openstack-utils openstack-selinux

Create service token and distribute to the other controllers
------------------------------------------------------------

On node 1:

    export SERVICE_TOKEN=$(openssl rand -hex 10)
    echo $SERVICE_TOKEN > /root/keystone_service_token
    scp /root/keystone_service_token root@hacontroller2:/root
    scp /root/keystone_service_token root@hacontroller3:/root

Configure Keystone
------------------

On all nodes:

    export SERVICE_TOKEN=$(cat /root/keystone_service_token)
    openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $SERVICE_TOKEN
    openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_ha_queues true
    openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_endpoint 'http://controller-vip.example.com:%(admin_port)s/'
    openstack-config --set /etc/keystone/keystone.conf DEFAULT public_endpoint 'http://controller-vip.example.com:%(public_port)s/'
    openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:keystonetest@controller-vip.example.com/keystone
    openstack-config --set /etc/keystone/keystone.conf database max_retries -1
    openstack-config --set /etc/keystone/keystone.conf DEFAULT public_bind_host 192.168.1.22X
    openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_bind_host 192.168.1.22X

Create and distribute PKI setup, manage DB
------------------------------------------

On node 1:

    keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
    chown -R keystone:keystone /var/log/keystone/etc/keystone/ssl/
    su keystone -s /bin/sh -c "keystone-manage db_sync"
    cd /etc/keystone/ssl
    tar cvfz /tmp/keystone_ssl.tgz *
    scp /tmp/keystone_ssl.tgz hacontroller2:/tmp
    scp /tmp/keystone_ssl.tgz hacontroller3:/tmp

Restore Keystone PKI setup from node 1
--------------------------------------

On nodes 2 and 3:

    mkdir -p /etc/keystone/ssl
    cd /etc/keystone/ssl
    tar xvfz /tmp/keystone_ssl.tgz 
    chown -R keystone:keystone /var/log/keystone/etc/keystone/ssl/
    restorecon -Rv /etc/keystone/ssl

Create cron job to flush expired tokens
---------------------------------------

On all nodes:

    echo "1 * * * * keystone keystone-manage token_flush >>/var/log/keystone/keystone-tokenflush.log 2>&1" >> /etc/crontab

Start services and open firewall ports
--------------------------------------

On all nodes;

    systemctl start openstack-keystone
    systemctl enable openstack-keystone
    firewall-cmd --add-port=5000/tcp
    firewall-cmd --add-port=5000/tcp --permanent
    firewall-cmd --add-port=35357/tcp
    firewall-cmd --add-port=35357/tcp --permanent

Create endpoints, services and users for all API services
---------------------------------------------------------

On node 1:

    export SERVICE_ENDPOINT=http://controller-vip.example.com:35357/v2.0
    keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"
    keystone endpoint-create --service keystone --publicurl 'http://controller-vip.example.com:5000/v2.0' --adminurl 'http://controller-vip.example.com:35357/v2.0' --internalurl 'http://controller-vip.example.com:5000/v2.0'
    keystone user-create --name admin --pass keystonetest
    keystone role-create --name admin
    keystone tenant-create --name admin
    keystone user-role-add --user admin --role admin --tenant admin
    keystone user-create --name demo --pass redhat
    keystone role-create --name _member_
    keystone tenant-create --name demo
    keystone user-role-add --user demo --role _member_ --tenant demo
    keystone tenant-create --name services --description "Services Tenant"
    # glance
    keystone user-create --name glance --pass glancetest
    keystone user-role-add --user glance --role admin --tenant services
    keystone service-create --name glance --type image --description "Glance Image Service"
    keystone endpoint-create --service glance --publicurl "http://controller-vip.example.com:9292" --adminurl "http://controller-vip.example.com:9292" --internalurl "http://controller-vip.example.com:9292"
    # cinder
    keystone user-create --name cinder --pass cindertest
    keystone user-role-add --user cinder --role admin --tenant services
    keystone service-create --name cinder --type volume --description "Cinder Volume Service"
    keystone endpoint-create --service cinder --publicurl "http://controller-vip.example.com:8776/v1/\$(tenant_id)s" --adminurl "http://controller-vip.example.com:8776/v1/\$(tenant_id)s" --internalurl "http://controller-vip.example.com:8776/v1/\$(tenant_id)s"
    keystone service-create --name cinderv2 --type volumev2 --description "OpenStack Block Storage"
    keystone endpoint-create --service cinderv2  --publicurl http://controller-vip.example.com:8776/v2/%\(tenant_id\)s  --internalurl http://controller-vip.example.com:8776/v2/%\(tenant_id\)s --adminurl http://controller-vip.example.com:8776/v2/%\(tenant_id\)s
    # swift
    keystone user-create --name swift --pass swifttest
    keystone user-role-add --user swift --role admin --tenant services
    keystone service-create --name swift --type object-store --description "Swift Storage Service"
    keystone endpoint-create --service swift --publicurl "http://controller-vip.example.com:8080/v1/AUTH_\$(tenant_id)s" --adminurl "http://controller-vip.example.com:8080/v1" --internalurl "http://controller-vip.example.com:8080/v1/AUTH_\$(tenant_id)s"
    # neutron
    keystone user-create --name neutron --pass neutrontest
    keystone user-role-add --user neutron --role admin --tenant services
    keystone service-create --name neutron --type network --description "OpenStack Networking Service"
    keystone endpoint-create --service neutron --publicurl "http://controller-vip.example.com:9696" --adminurl "http://controller-vip.example.com:9696" --internalurl "http://controller-vip.example.com:9696"
    # nova
    keystone user-create --name compute --pass novatest
    keystone user-role-add --user compute --role admin --tenant services
    keystone service-create --name compute --type compute --description "OpenStack Compute Service"
    keystone endpoint-create  --service compute --publicurl "http://controller-vip.example.com:8774/v2/\$(tenant_id)s" --adminurl "http://controller-vip.example.com:8774/v2/\$(tenant_id)s" --internalurl "http://controller-vip.example.com:8774/v2/\$(tenant_id)s"
    # heat
    keystone user-create --name=heat --pass=heattest
    keystone user-role-add --user heat --role admin --tenant services
    keystone service-create --name heat --type orchestration
    keystone endpoint-create --service heat --publicurl "http://controller-vip.example.com:8004/v1/%(tenant_id)s" --adminurl "http://controller-vip.example.com:8004/v1/%(tenant_id)s" --internalurl "http://controller-vip.example.com:8004/v1/%(tenant_id)s"
    keystone service-create --name heat-cfn --type cloudformation
    keystone endpoint-create --service heat-cfn --publicurl "http://controller-vip.example.com:8000/v1" --adminurl "http://controller-vip.example.com:8000/v1" --internalurl "http://controller-vip.example.com:8000/v1"
    # ceilometer
    keystone user-create --name ceilometer --pass ceilometertest --email test@redhat.com
    keystone user-role-add --user ceilometer --role admin --tenant services
    keystone role-create --name ResellerAdmin
    keystone user-role-add --user ceilometer --role ResellerAdmin --tenant services
    keystone service-create --name ceilometer --type metering --description="OpenStack Telemetry Service"
    keystone endpoint-create --service ceilometer --publicurl "http://controller-vip.example.com:8777" --adminurl "http://controller-vip.example.com:8777" --internalurl "http://controller-vip.example.com:8777"

Create keystonerc files for simplicity
--------------------------------------

On all nodes:

    cat > /root/keystonerc_admin << EOF
    export OS_USERNAME=admin 
    export OS_TENANT_NAME=admin
    export OS_PASSWORD=keystonetest
    export OS_AUTH_URL=http://controller-vip.example.com:35357/v2.0/
    export PS1='[\u@\h \W(keystone_admin)]\$ '
    EOF

    cat > /root/keystonerc_demo << EOF
    export OS_USERNAME=demo
    export OS_TENANT_NAME=demo
    export OS_PASSWORD=redhat
    export OS_AUTH_URL=http://controller-vip.example.com:5000/v2.0/
    export PS1='[\u@\h \W(keystone_user)]\$ '
    EOF
