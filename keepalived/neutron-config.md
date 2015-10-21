Introduction
------------

For this setup, we will configure an external provider network using eth0 (10.10.10.X network). A different setup would apply for bridged networks, although the HA features should be the same.

There are two services that require special attention for a highly available architecture:

-   Neutron DHCP agent availability is obtained by assigning two or more agents to manage each tenant network, setting `dhcp_agents_per_network=2` in `/etc/neutron/neutron.conf`.
-   Neutron L3 agent availability uses the L3 HA functionality using VRRP. Using this functionality, a new type of router, spawned on two or more different agents, is created. One agent will be in charge of the master version of this router, and the remaining L3 agents will be in charge of the slave routers. Refer to [this blog post](http://assafmuller.com/2014/08/16/layer-3-high-availability/) for a detailed description of the feature.

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/neutron.scenario).

Install software
----------------

    yum install -y openstack-neutron openstack-neutron-openvswitch openstack-neutron-ml2 openstack-utils openstack-selinux

Configure Neutron server
------------------------

    openstack-config --set /etc/neutron/neutron.conf DEFAULT bind_host 192.168.1.22X
    openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri https://controller-vip.example.com:5000/
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_plugin password
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller-vip.example.com:35357/
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password neutrontest
    openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name services
    openstack-config --set /etc/neutron/neutron.conf database connection mysql://neutron:neutrontest@controller-vip.example.com:3306/neutron
    openstack-config --set /etc/neutron/neutron.conf database max_retries -1
    openstack-config --set /etc/neutron/neutron.conf DEFAULT notification_driver neutron.openstack.common.notifier.rpc_notifier
    openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_hosts hacontroller1,hacontroller2,hacontroller3
    openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_ha_queues true
    openstack-config --set /etc/neutron/neutron.conf nova nova_region_name regionOne
    openstack-config --set /etc/neutron/neutron.conf nova project_domain_id default
    openstack-config --set /etc/neutron/neutron.conf nova project_name service
    openstack-config --set /etc/neutron/neutron.conf nova user_domain_id default
    openstack-config --set /etc/neutron/neutron.conf nova password novatest
    openstack-config --set /etc/neutron/neutron.conf nova username compute
    openstack-config --set /etc/neutron/neutron.conf nova auth_url http://controller-vip.example.com:35357/
    openstack-config --set /etc/neutron/neutron.conf nova auth_plugin password
    openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
    openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
    openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin neutron.plugins.ml2.plugin.Ml2Plugin
    openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
    openstack-config --set /etc/neutron/neutron.conf DEFAULT router_scheduler_driver neutron.scheduler.l3_agent_scheduler.ChanceScheduler
    openstack-config --set /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 2
    openstack-config --set /etc/neutron/neutron.conf DEFAULT api_workers 2
    openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_workers 2
    openstack-config --set /etc/neutron/neutron.conf DEFAULT l3_ha True
    openstack-config --set /etc/neutron/neutron.conf DEFAULT min_l3_agents_per_router 2
    openstack-config --set /etc/neutron/neutron.conf DEFAULT max_l3_agents_per_router 2

### ML2 configuration

    ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers local,gre,flat,vxlan,vlan
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks \*
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 10:10000
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 10:10000
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group 224.0.0.1
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 

### LBaaS configuration (optional)

    yum -y install openstack-neutron-lbaas
    openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router,lbaas
    openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
    openstack-config --set /etc/neutron/lbaas_agent.ini DEFAULT device_driver neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver
    openstack-config --set /etc/neutron/lbaas_agent.ini haproxy user_group haproxy 

### FWaaS configuration (optional)

    yum -y install openstack-neutron-fwaas
    openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router,firewall,lbaas
    openstack-config --set /etc/neutron/fwaas_driver.ini fwaas enabled True
    openstack-config --set /etc/neutron/fwaas_driver.ini fwaas driver neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver

Manage DB
---------

On node 1:

    neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head

Start services, open firewall ports
-----------------------------------

On all nodes:

    systemctl start neutron-server
    systemctl enable neutron-server
    firewall-cmd --add-port=9696/tcp
    firewall-cmd --add-port=9696/tcp --permanent

OpenvSwitch configuration
-------------------------

    systemctl enable openvswitch
    systemctl start openvswitch
    ovs-vsctl add-br br-int
    ovs-vsctl add-br br-eth0

**Note:** we have seeing issues when trying to configure an IP on br-eth0 (specially ARP problems), so it is not recommended.

    ovs-vsctl add-port br-eth0 eth0

OpenvSwitch agent
-----------------

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent vxlan_udp_port 4789
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip 192.168.1.22X
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs enable_tunneling True
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs integration_bridge br-int
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs tunnel_bridge br-tun
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings physnet1:br-eth0
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs network_vlan_ranges physnet1
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population False

Metadata agent
--------------

    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_strategy keystone
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://controller-vip.example.com:35357/v2.0
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_host controller-vip.example.com
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region regionOne
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name services
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password neutrontest
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip controller-vip.example.com
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_port 8775
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret metatest
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_workers 4
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_backlog 2048

DHCP agent
----------

    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf

The following will prevent issues from happening when the network card MTU is 1500. If we are using jumbo frames, it should not be required. Be aware that this only helps on certain operating systems with a well-behaving DHCP client. Windows is known to ignore it.

    echo "dhcp-option-force=26,1400" > /etc/neutron/dnsmasq-neutron.conf
    chown root:neutron /etc/neutron/dnsmasq-neutron.conf
    chmod 644 /etc/neutron/dnsmasq-neutron.conf

L3 agent
--------

    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT handle_internal_only_routers True
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT send_arp_for_ha 3
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT metadata_ip controller-vip.example.com
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge

Start services and open VXLAN firewall port
-------------------------------------------

    systemctl start neutron-openvswitch-agent
    systemctl start neutron-dhcp-agent
    systemctl start neutron-l3-agent
    systemctl start neutron-metadata-agent
    systemctl start neutron-lbaas-agent
    systemctl enable neutron-openvswitch-agent
    systemctl enable neutron-dhcp-agent
    systemctl enable neutron-l3-agent
    systemctl enable neutron-metadata-agent
    systemctl enable neutron-ovs-cleanup
    systemctl enable neutron-lbaas-agent

    firewall-cmd --add-port=4789/udp
    firewall-cmd --add-port=4789/udp --permanent

**NOTE:** During a full cluster reboot, since Galera does not start cleanly neutron-server will wait for some time, then fail due to a service startup timeout (see [this bug](https://bugzilla.redhat.com/show_bug.cgi?id=1188198) for details). We can fix that by creating a file named `/etc/systemd/system/neutron-server.service.d/restart.conf` with the following contents:

    [Service]
    Restart=on-failure

Neutron server will try to restart indefinitely, then eventually succeed as soon as the Galera DB is running.

Create provider network
-----------------------

On node 1:

    . /root/keystonerc_admin
    neutron net-create public --provider:network_type flat --provider:physical_network physnet1 --router:external
    neutron subnet-create --gateway 10.10.10.1 --allocation-pool start=10.10.10.100,end=10.10.10.150 --disable-dhcp --name public_subnet public 10.10.10.0/24
