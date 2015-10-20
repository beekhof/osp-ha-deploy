Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/keystone.scenario).

Install software
----------------

    yum install -y openstack-keystone openstack-utils openstack-selinux httpd mod_wsgi python-openstackclient

Create service token and distribute to the other controllers
------------------------------------------------------------

On node 1:

    export SERVICE_TOKEN=$(openssl rand -hex 10)
    echo $SERVICE_TOKEN > /root/keystone_service_token
    scp /root/keystone_service_token root@hacontroller2:/root
    scp /root/keystone_service_token root@hacontroller3:/root

Configure Apache web server for Keystone
----------------------------------------

**NOTE:** running Keystone under eventlet has been deprecated as of the Kilo release. Support for utilizing eventlet will be removed as of the M-release. Thus, instructions are provided to run Keystone under the Apache web server, as a WSGI process.

On all nodes:
    cp /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
    sed -i -e 's/apache2/httpd/g'   /etc/httpd/conf.d/wsgi-keystone.conf
    sed -i -e 's/VirtualHost \*/VirtualHost 192.168.1.22X/g' /etc/httpd/conf.d/wsgi-keystone.conf 
    sed -i -e 's/Listen 5000/Listen 192.168.1.22X:5000/g' /etc/httpd/conf.d/wsgi-keystone.conf 
    sed -i -e 's/Listen 35357/Listen 192.168.1.22X:35357/g' /etc/httpd/conf.d/wsgi-keystone.conf 
    sed -i -e 's/^Listen.*/Listen 192.168.1.22X:80/g' /etc/httpd/conf/httpd.conf 

Configure Keystone
------------------

On all nodes:

    export SERVICE_TOKEN=$(cat /root/keystone_service_token)
    openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $SERVICE_TOKEN
    openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/keystone/keystone.conf DEFAULT rabbit_ha_queues true
    openstack-config --set /etc/keystone/keystone.conf eventlet_server admin_endpoint 'http://controller-vip.example.com:%(admin_port)s/'
    openstack-config --set /etc/keystone/keystone.conf eventlet_server public_endpoint 'http://controller-vip.example.com:%(public_port)s/'
    openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:keystonetest@controller-vip.example.com/keystone
    openstack-config --set /etc/keystone/keystone.conf database max_retries -1
    openstack-config --set /etc/keystone/keystone.conf DEFAULT public_bind_host 192.168.1.22X
    openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_bind_host 192.168.1.22X
    openstack-config --set /etc/keystone/keystone.conf token driver  keystone.token.persistence.backends.sql.Token

Create and distribute PKI setup, manage DB
------------------------------------------

On node 1:

    keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
    chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl/
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
    chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl/
    restorecon -Rv /etc/keystone/ssl
    touch /var/log/keystone/keystone.log
    chown keystone:keystone /var/log/keystone/keystone.log

Create cron job to flush expired tokens
---------------------------------------

On all nodes:

    echo "1 * * * * keystone keystone-manage token_flush >>/var/log/keystone/keystone-tokenflush.log 2>&1" >> /etc/crontab

Start services and open firewall ports
--------------------------------------

On all nodes;

    firewall-cmd --add-port=5000/tcp
    firewall-cmd --add-port=5000/tcp --permanent
    firewall-cmd --add-port=35357/tcp
    firewall-cmd --add-port=35357/tcp --permanent
    systemctl start httpd
    systemctl enable httpd

Create endpoints, services and users for all API services
---------------------------------------------------------

On node 1:

    export OS_TOKEN=$(cat /root/keystone_service_token)
    export OS_URL=http://controller-vip.example.com:35357/v2.0
    export OS_REGION_NAME=regionOne
    openstack service create --name=keystone --description="Keystone Identity Service" identity
    openstack endpoint create --publicurl 'http://controller-vip.example.com:5000/v2.0' --adminurl 'http://controller-vip.example.com:35357/v2.0' --internalurl 'http://controller-vip.example.com:5000/v2.0' --region regionOne keystone
    openstack user create --password keystonetest admin
    openstack role create admin
    openstack project create admin
    openstack role add --project admin --user admin admin
    openstack user create --password redhat demo
    openstack role create _member_
    openstack project create demo
    openstack role add --project demo --user demo _member_
    openstack project create --description "Services Tenant" services
    # glance
    openstack user create --password glancetest glance
    openstack role add --project services --user glance admin
    openstack service create --name=glance --description="Glance Image Service" image
    openstack endpoint create --publicurl 'http://controller-vip.example.com:9292' --adminurl 'http://controller-vip.example.com:9292' --internalurl 'http://controller-vip.example.com:9292' --region regionOne glance
    # cinder
    openstack user create --password cindertest cinder
    openstack role add --project services --user cinder admin
    openstack service create --name=cinder --description="Cinder Volume Service" volume
    openstack endpoint create --publicurl "http://controller-vip.example.com:8776/v1/\$(tenant_id)s" --adminurl "http://controller-vip.example.com:8776/v1/\$(tenant_id)s" --internalurl "http://controller-vip.example.com:8776/v1/\$(tenant_id)s" --region regionOne cinder
    openstack service create --name=cinderv2 --description="OpenStack Block Storage" volumev2
    openstack endpoint create --publicurl "http://controller-vip.example.com:8776/v2/\$(tenant_id)s" --adminurl "http://controller-vip.example.com:8776/v2/\$(tenant_id)s" --internalurl "http://controller-vip.example.com:8776/v2/\$(tenant_id)s" --region regionOne cinderv2
    # swift
    openstack user create --password swifttest swift
    openstack role add --project services --user swift admin
    openstack service create --name=swift --description="Swift Storage Service" object-store
    openstack endpoint create --publicurl "http://controller-vip.example.com:8080/v1/AUTH_\$(tenant_id)s" --adminurl "http://controller-vip.example.com:8080/v1" --internalurl "http://controller-vip.example.com:8080/v1/AUTH_\$(tenant_id)s" --region regionOne swift
    # neutron
    openstack user create --password neutrontest neutron
    openstack role add --project services --user neutron admin
    openstack service create --name=neutron --description="OpenStack Networking Service" network
    openstack endpoint create --publicurl "http://controller-vip.example.com:9696" --adminurl "http://controller-vip.example.com:9696" --internalurl "http://controller-vip.example.com:9696" --region regionOne neutron
    # nova
    openstack user create --password novatest compute
    openstack role add --project services --user compute admin
    openstack service create --name=compute --description="OpenStack Compute Service" compute
    openstack endpoint create --publicurl "http://controller-vip.example.com:8774/v2/\$(tenant_id)s" --adminurl "http://controller-vip.example.com:8774/v2/\$(tenant_id)s" --internalurl "http://controller-vip.example.com:8774/v2/\$(tenant_id)s" --region regionOne compute
    # heat
    openstack user create --password heattest heat
    openstack role add --project services --user heat admin
    openstack service create --name=heat --description="Heat Orchestration Service" orchestration
    openstack endpoint create --publicurl "http://controller-vip.example.com:8004/v1/%(tenant_id)s" --adminurl "http://controller-vip.example.com:8004/v1/%(tenant_id)s" --internalurl "http://controller-vip.example.com:8004/v1/%(tenant_id)s" --region regionOne heat
    openstack service create --name=heat-cfn --description="Heat CloudFormation Service" cloudformation
    openstack endpoint create --publicurl "http://controller-vip.example.com:8000/v1" --adminurl "http://controller-vip.example.com:8000/v1" --internalurl "http://controller-vip.example.com:8000/v1" --region regionOne heat-cfn
    # ceilometer
    openstack user create --password ceilometertest ceilometer
    openstack role add --project services --user ceilometer admin
    openstack role create ResellerAdmin
    openstack role add --project services --user ceilometer ResellerAdmin
    openstack service create --name=ceilometer --description="OpenStack Telemetry Service" metering
    openstack endpoint create --publicurl "http://controller-vip.example.com:8777" --adminurl "http://controller-vip.example.com:8777" --internalurl "http://controller-vip.example.com:8777" --region regionOne ceilometer
    # sahara
    openstack user create --password saharatest sahara
    openstack role add --project services --user sahara admin
    openstack service create --name=sahara --description="Sahara Data Processing" data-processing
    openstack endpoint create --publicurl "http://controller-vip.example.com:8386/v1.1/%(tenant_id)s" --adminurl "http://controller-vip.example.com:8386/v1.1/%(tenant_id)s" --internalurl "http://controller-vip.example.com:8386/v1.1/%(tenant_id)s" --region regionOne sahara
    # trove
    openstack user create --password trovetest trove
    openstack role add --project services --user trove admin
    openstack service create --name=trove --description="OpenStack Database Service" database
    openstack endpoint create --publicurl "http://controller-vip.example.com:8779/v1.0/%(tenant_id)s" --adminurl "http://controller-vip.example.com:8779/v1.0/%(tenant_id)s" --internalurl "http://controller-vip.example.com:8779/v1.0/%(tenant_id)s" --region regionOne trove

Create keystonerc files for simplicity
--------------------------------------

On all nodes:

    cat > /root/keystonerc_admin << EOF
    export OS_USERNAME=admin 
    export OS_TENANT_NAME=admin
    export OS_PROJECT_NAME=admin
    export OS_REGION_NAME=regionOne
    export OS_PASSWORD=keystonetest
    export OS_AUTH_URL=http://controller-vip.example.com:35357/v2.0/
    export PS1='[\u@\h \W(keystone_admin)]\$ '
    EOF

    cat > /root/keystonerc_demo << EOF
    export OS_USERNAME=demo
    export OS_TENANT_NAME=demo
    export OS_PROJECT_NAME=demo
    export OS_REGION_NAME=regionOne
    export OS_PASSWORD=redhat
    export OS_AUTH_URL=http://controller-vip.example.com:5000/v2.0/
    export PS1='[\u@\h \W(keystone_user)]\$ '
    EOF
