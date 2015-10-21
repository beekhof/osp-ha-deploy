Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/heat.scenario).

Install software
----------------

    yum install -y openstack-heat-engine openstack-heat-api openstack-heat-api-cfn openstack-heat-api-cloudwatch python-heatclient openstack-utils python-glanceclient

Configure Heat domain
---------------------

To allow non-admin users to create Heat stacks, a Keystone domain needs to be created. Run the following commands to create the Heat domain, and configure Heat to use it.

On node 1:

    . /root/keystonerc_admin
    openstack role create heat_stack_user
    openstack token issue

Take note of the token ID issued, then:

    openstack --os-token=${TOKEN_ID} --os-url=http://controller-vip.example.com:5000/v3 --os-identity-api-version=3 domain create heat --description "Owns users and projects created by heat"
    openstack --os-token=${TOKEN_ID} --os-url=http://controller-vip.example.com:5000/v3 --os-identity-api-version=3 user create --password heattest --domain heat --description "Manages users and projects created by heat" heat_domain_admin
    openstack --os-token=${TOKEN_ID} --os-url=http://controller-vip.example.com:5000/v3 --os-identity-api-version=3 role add --user heat_domain_admin --domain heat admin

On all nodes:

    openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin_password heattest
    openstack-config --set /etc/heat/heat.conf DEFAULT stack_domain_admin heat_domain_admin
    openstack-config --set /etc/heat/heat.conf DEFAULT stack_user_domain_name heat

Configure Heat
--------------

    openstack-config --set /etc/heat/heat.conf database connection mysql://heat:heattest@controller-vip.example.com/heat
    openstack-config --set /etc/heat/heat.conf database max_retries -1
    openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri https://controller-vip.example.com:5000/
    openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_plugin password
    openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_url http://controller-vip.example.com:35357/
    openstack-config --set /etc/heat/heat.conf keystone_authtoken username heat
    openstack-config --set /etc/heat/heat.conf keystone_authtoken password heattest
    openstack-config --set /etc/heat/heat.conf keystone_authtoken project_name services
    openstack-config --set /etc/heat/heat.conf keystone_authtoken keystone_ec2_uri http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/heat/heat.conf ec2authtoken auth_uri http://controller-vip.example.com:5000/v2.0
    openstack-config --set /etc/heat/heat.conf DEFAULT memcache_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/heat/heat.conf heat_api bind_host 192.168.1.22X
    openstack-config --set /etc/heat/heat.conf heat_api_cfn bind_host 192.168.1.22X
    openstack-config --set /etc/heat/heat.conf heat_api_cloudwatch bind_host 192.168.1.22X
    openstack-config --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url controller-vip.example.com:8000
    openstack-config --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url controller-vip.example.com:8000/v1/waitcondition
    openstack-config --set /etc/heat/heat.conf DEFAULT heat_watch_server_url controller-vip.example.com:8003
    openstack-config --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend rabbit
    openstack-config --set /etc/heat/heat.conf DEFAULT notification_driver heat.openstack.common.notifier.rpc_notifier
    openstack-config --set /etc/heat/heat.conf DEFAULT enable_cloud_watch_lite false

Manage DB
---------

On node 1:

    su heat -s /bin/sh -c "heat-manage db_sync"

Start services, open firewall ports
-----------------------------------

On all nodes:

    systemctl start openstack-heat-api
    systemctl start openstack-heat-api-cfn
    systemctl start openstack-heat-api-cloudwatch
    systemctl start openstack-heat-engine
    systemctl enable openstack-heat-api
    systemctl enable openstack-heat-api-cfn
    systemctl enable openstack-heat-api-cloudwatch
    systemctl enable openstack-heat-engine
    firewall-cmd --add-port=8000/tcp
    firewall-cmd --add-port=8000/tcp --permanent
    firewall-cmd --add-port=8003/tcp
    firewall-cmd --add-port=8003/tcp --permanent
    firewall-cmd --add-port=8004/tcp
    firewall-cmd --add-port=8004/tcp --permanent
