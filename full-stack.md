This is what the result of `pcs status` should look like:

    Cluster name: rhos-node
    Last updated: Fri Mar  6 22:06:28 2015
    Last change: Fri Mar  6 22:03:52 2015
    Stack: corosync
    Current DC: rhos6-node2 (2) - partition with quorum
    Version: 1.1.12-a14efad
    3 Nodes configured
    121 Resources configured
    
    
    Online: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
    
    Full list of resources:
    
     fence1	(stonith:fence_xvm):	Started rhos6-node1 
     fence2	(stonith:fence_xvm):	Started rhos6-node2 
     fence3	(stonith:fence_xvm):	Started rhos6-node3 
     Clone Set: lb-haproxy-clone [lb-haproxy]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     vip-db	(ocf::heartbeat:IPaddr2):	Started rhos6-node1 
     vip-qpid	(ocf::heartbeat:IPaddr2):	Started rhos6-node2 
     vip-keystone	(ocf::heartbeat:IPaddr2):	Started rhos6-node3 
     vip-glance	(ocf::heartbeat:IPaddr2):	Started rhos6-node1 
     vip-cinder	(ocf::heartbeat:IPaddr2):	Started rhos6-node2 
     vip-swift	(ocf::heartbeat:IPaddr2):	Started rhos6-node3 
     vip-neutron	(ocf::heartbeat:IPaddr2):	Started rhos6-node1 
     vip-nova	(ocf::heartbeat:IPaddr2):	Started rhos6-node2 
     vip-horizon	(ocf::heartbeat:IPaddr2):	Started rhos6-node3 
     vip-heat	(ocf::heartbeat:IPaddr2):	Started rhos6-node1 
     vip-ceilometer	(ocf::heartbeat:IPaddr2):	Started rhos6-node2 
     vip-rabbitmq	(ocf::heartbeat:IPaddr2):	Started rhos6-node3 
     Master/Slave Set: galera-master [galera]
         Masters: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: mongodb-clone [mongodb]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: memcached-clone [memcached]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: rabbitmq-server-clone [rabbitmq-server]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: keystone-clone [keystone]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: glance-fs-clone [glance-fs]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: glance-registry-clone [glance-registry]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: glance-api-clone [glance-api]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: cinder-api-clone [cinder-api]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: cinder-scheduler-clone [cinder-scheduler]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     cinder-volume	(systemd:openstack-cinder-volume):	Started rhos6-node1 
     Clone Set: swift-fs-clone [swift-fs]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: swift-account-clone [swift-account]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: swift-container-clone [swift-container]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: swift-object-clone [swift-object]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: swift-proxy-clone [swift-proxy]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     swift-object-expirer	(systemd:openstack-swift-object-expirer):	Started rhos6-node2 
     Clone Set: neutron-server-clone [neutron-server]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: neutron-scale-clone [neutron-scale] (unique)
         neutron-scale:0	(ocf::neutron:NeutronScale):	Started rhos6-node3 
         neutron-scale:1	(ocf::neutron:NeutronScale):	Started rhos6-node1 
         neutron-scale:2	(ocf::neutron:NeutronScale):	Started rhos6-node2 
     Clone Set: neutron-ovs-cleanup-clone [neutron-ovs-cleanup]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: neutron-netns-cleanup-clone [neutron-netns-cleanup]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: neutron-openvswitch-agent-clone [neutron-openvswitch-agent]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: neutron-dhcp-agent-clone [neutron-dhcp-agent]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: neutron-l3-agent-clone [neutron-l3-agent]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: neutron-metadata-agent-clone [neutron-metadata-agent]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     ceilometer-central	(systemd:openstack-ceilometer-central):	Started rhos6-node3 
     Clone Set: ceilometer-collector-clone [ceilometer-collector]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: ceilometer-api-clone [ceilometer-api]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: ceilometer-delay-clone [ceilometer-delay]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: ceilometer-alarm-evaluator-clone [ceilometer-alarm-evaluator]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: ceilometer-alarm-notifier-clone [ceilometer-alarm-notifier]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: ceilometer-notification-clone [ceilometer-notification]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: heat-api-clone [heat-api]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: heat-api-cfn-clone [heat-api-cfn]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     Clone Set: heat-api-cloudwatch-clone [heat-api-cloudwatch]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
     heat-engine	(systemd:openstack-heat-engine):	Started rhos6-node1 
     Clone Set: horizon-clone [horizon]
         Started: [ rhos6-node1 rhos6-node2 rhos6-node3 ]
    
    PCSD Status:
      rhos6-node1: Online
      rhos6-node2: Online
      rhos6-node3: Online
    
    Daemon Status:
      corosync: active/enabled
      pacemaker: active/enabled
      pcsd: active/enabled
