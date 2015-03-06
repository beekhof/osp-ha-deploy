Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

Install software
----------------

    yum install -y openstack-heat-* python-heatclient openstack-utils python-glanceclient

Configure Heat
--------------

    openstack-config --set /etc/heat/heat.conf database connection mysql://heat:heattest@controller-vip.example.com/heat
    openstack-config --set /etc/heat/heat.conf database max_retries -1
    openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_user heat
    openstack-config --set /etc/heat/heat.conf keystone_authtoken admin_password heattest
    openstack-config --set /etc/heat/heat.conf keystone_authtoken service_host controller-vip.example.com
    openstack-config --set /etc/heat/heat.conf keystone_authtoken identity_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/heat/heat.conf keystone_authtoken auth_uri http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/heat/heat.conf keystone_authtoken keystone_ec2_uri http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/heat/heat.conf ec2authtoken auth_uri http://controller-vip.example.com:5000/v2.0
    openstack-config --set /etc/heat/heat.conf DEFAULT memcache_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/heat/heat.conf heat_api bind_host 192.168.1.22X
    openstack-config --set /etc/heat/heat.conf heat_api_cfn bind_host 192.168.1.22X
    openstack-config --set /etc/heat/heat.conf heat_api_cloudwatch bind_host 192.168.1.22X
    openstack-config --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url controller-vip.example.com:8000
    openstack-config --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url controller-vip.example.com:8000/v1/waitcondition
    openstack-config --set /etc/heat/heat.conf DEFAULT heat_watch_server_url controller-vip.example.com:8003
    openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/heat/heat.conf DEFAULT rabbit_ha_queues true
    openstack-config --set /etc/heat/heat.conf DEFAULT rpc_backend rabbit
    openstack-config --set /etc/heat/heat.conf DEFAULT notification_driver heat.openstack.common.notifier.rpc_notifier

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
