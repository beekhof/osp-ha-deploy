Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

Install software
----------------

    yum install -y openstack-nova-console openstack-nova-novncproxy openstack-utils openstack-nova-api openstack-nova-conductor openstack-nova-scheduler python-cinderclient python-memcached

**Note:** python-websockify 0.6.0 or later is required (https://bugzilla.redhat.com/show_bug.cgi?id=1200701). This should be fixed by the Kilo GA date.

Configure Nova API
------------------

    openstack-config --set /etc/nova/nova.conf DEFAULT memcached_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 192.168.1.22X
    openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 192.168.1.22X
    openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_host 192.168.1.22X
    openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller-vip.example.com:6080/vnc_auto.html
    openstack-config --set /etc/nova/nova.conf database connection mysql://nova:novatest@controller-vip.example.com/nova
    openstack-config --set /etc/nova/nova.conf database max_retries -1
    openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
    openstack-config --set /etc/nova/nova.conf DEFAULT osapi_compute_listen 192.168.1.22X
    openstack-config --set /etc/nova/nova.conf DEFAULT metadata_host 192.168.1.22X
    openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen 192.168.1.22X
    openstack-config --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8775
    openstack-config --set /etc/nova/nova.conf DEFAULT glance_host controller-vip.example.com
    openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
    openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
    openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_vif_driver nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
    openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
    openstack-config --set /etc/nova/nova.conf cinder cinder_catalog_info volume:cinder:internalURL
    openstack-config --set /etc/nova/nova.conf conductor use_local false
    openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_ha_queues True
    openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
    openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret metatest
    openstack-config --set /etc/nova/nova.conf neutron url http://controller-vip.example.com:9696/
    openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name services
    openstack-config --set /etc/nova/nova.conf neutron admin_username neutron
    openstack-config --set /etc/nova/nova.conf neutron admin_password neutrontest
    openstack-config --set /etc/nova/nova.conf neutron admin_auth_url http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/nova/nova.conf neutron region_name regionOne

    # REQUIRED FOR A/A scheduler
    openstack-config --set /etc/nova/nova.conf DEFAULT scheduler_host_subset_size 30
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken identity_uri http://controller-vip.example.com:35357/
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_tenant_name services
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_user compute
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_password novatest

Only run the following command if you are creating a test environment where your hypervisors will be virtual machines

    openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu

Manage DB
---------

On node 1:

    su nova -s /bin/sh -c "nova-manage db sync"

Start services, open firewall ports
-----------------------------------

On all nodes:

    systemctl start openstack-nova-consoleauth
    systemctl start openstack-nova-novncproxy 
    systemctl start openstack-nova-api
    systemctl start openstack-nova-scheduler
    systemctl start openstack-nova-conductor
    systemctl enable openstack-nova-consoleauth
    systemctl enable openstack-nova-novncproxy 
    systemctl enable openstack-nova-api
    systemctl enable openstack-nova-scheduler
    systemctl enable openstack-nova-conductor

    firewall-cmd --add-port=8773-8775/tcp
    firewall-cmd --add-port=8773-8775/tcp --permanent
    firewall-cmd --add-port=6080/tcp
    firewall-cmd --add-port=6080/tcp --permanent
