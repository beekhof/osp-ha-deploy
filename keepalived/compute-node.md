Introduction
------------

The compute node implementation is relatively straightforward, compared to the controller node. It will only be necessary to configure:

-   OpenvSwitch and Neutron OpenvSwitch agent
-   Nova compute
-   Ceilometer compute agent

You can find a phd scenario file [here](phd-setup/compute.scenario).

Environment description
-----------------------

The network configuration was previously discussed in the [Controller node implementation](controller-node.md) section:

![](Controller-network.jpg "Network configuration")

-   The external network is used by the Neutron floating IPs, and for any external access. The hypervisor nodes (hacompute1 and hacompute2) do not need to be connected to this network, but in the demo setup they are connected for testing purposes.
-   The internal network will carry all other traffic: API traffic, tenant networks and storage traffic.
-   The router providing connectivity between the internal and external networks is only needed if Trove and/or Sahara are being deployed.

Remember this is a minimum test setup. Any production setup should separate internal and external API traffic, tenant networks and storage traffic in different network segments.

Compute node configuration
--------------------------

The following commands should be executed on each compute node to be added to the installation. There is no configuration required on the controller nodes, meaning compute nodes can be added anytime.

### Install software

    yum install -y openstack-nova-compute openstack-utils python-cinder openstack-neutron-openvswitch openstack-ceilometer-compute openstack-neutron

### Enable OpenvSwitch, start daemon and create integration bridge

    systemctl enable openvswitch
    systemctl start openvswitch
    ovs-vsctl add-br br-int

### Configure Nova compute

    openstack-config --set /etc/nova/nova.conf DEFAULT memcached_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 192.168.1.22X
    openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
    openstack-config --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller-vip.example.com:6080/vnc_auto.html
    openstack-config --set /etc/nova/nova.conf database connection mysql://nova:novatest@controller-vip.example.com/nova
    openstack-config --set /etc/nova/nova.conf database max_retries -1
    openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
    openstack-config --set /etc/nova/nova.conf glance host controller-vip.example.com
    openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
    openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
    openstack-config --set /etc/nova/nova.conf libvirt vif_driver nova.virt.libvirt.vif.LibvirtGenericVIFDriver
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
    openstack-config --set /etc/nova/nova.conf libvirt nfs_mount_options v3
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken auth_host controller-vip.example.com
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_tenant_name services
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_user compute
    openstack-config --set /etc/nova/api-paste.ini filter:authtoken admin_password novatest

Only run the following command if you are creating a test environment where your hypervisors will be virtual machines.

    openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu

### Configure Neutron on compute node

    openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_host controller-vip.example.com
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken admin_password neutrontest
    openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent tunnel_types vxlan
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent vxlan_udp_port 4789
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs enable_tunneling True
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_id_ranges 1:1000
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tenant_network_type vxlan
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs integration_bridge br-int
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs tunnel_bridge br-tun
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini ovs local_ip 192.168.1.22X
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
    openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini agent l2_population False

### Configure Ceilometer on compute node

    openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit True
    openstack-config --set /etc/nova/nova.conf DEFAULT instance_usage_audit_period hour
    openstack-config --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
    openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver nova.openstack.common.notifier.rpc_notifier
    sed  -i -e  's/nova.openstack.common.notifier.rpc_notifier/nova.openstack.common.notifier.rpc_notifier\nnotification_driver  = ceilometer.compute.nova_notifier/g' /etc/nova/nova.conf
    openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host controller-vip.example.com
    openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port 35357
    openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol http
    openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name services
    openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
    openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password ceilometertest
    openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT memcache_servers hacontroller1:11211,hacontroller2:11211,hacontroller3:11211
    openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/ceilometer/ceilometer.conf publisher telemetry_secret ceilometersecret
    openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://controller-vip.example.com:5000/v2.0
    openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
    openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name services
    openstack-config --set /etc/ceilometer/ceilometer.conf service_credentials os_password ceilometertest
    openstack-config --set /etc/ceilometer/ceilometer.conf database connection mongodb://hacontroller1,hacontroller2,hacontroller3:27017/ceilometer?replicaSet=ceilometer
    openstack-config --set /etc/ceilometer/ceilometer.conf database connection max_retries -1

    # keep last 5 days data only (value is in secs)
    openstack-config --set /etc/ceilometer/ceilometer.conf database metering_time_to_live 432000

**Note:** the following SELinux boolean allows QEMU to use NFS for Cinder volumes. A different boolean may apply if using another type of backend storage.

    setsebool -P virt_use_nfs 1

### Set kernel TCP keepalive parameters

    cat > /etc/sysctl.d/tcpka.conf << EOF
    net.ipv4.tcp_keepalive_intvl = 1
    net.ipv4.tcp_keepalive_probes = 5
    net.ipv4.tcp_keepalive_time = 5
    EOF

    sysctl -p /etc/sysctl.d/tcpka.conf

### Enable and start services, open firewall ports

**Note:** we are enabling ports 5900-5999 for VNC access. If the compute node could host more than 100 VMs, we have to extend this range.

    systemctl start libvirtd
    systemctl start neutron-openvswitch-agent
    systemctl enable neutron-openvswitch-agent
    systemctl enable neutron-ovs-cleanup
    systemctl start openstack-ceilometer-compute
    systemctl enable openstack-ceilometer-compute
    systemctl start openstack-nova-compute
    systemctl enable openstack-nova-compute
    firewall-cmd --add-port=4789/udp
    firewall-cmd --add-port=4789/udp --permanent
    firewall-cmd --add-port=5900-5999/tcp
    firewall-cmd --add-port=5900-5999/tcp --permanent
