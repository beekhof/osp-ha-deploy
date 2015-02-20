# Changelog
# IMPORTANT NOTES

- There are probably 2^8 other ways to deploy this same scenario. This is only one of them.
- Due to limited number of available physical LAN connections in the test setup, the instance IP traffic overlaps with the internal/management network.
- Internal LAN: 192.168.16.x
- External LAN has very limited IP availability. Hence we use a firewall / commodity server to provide ssh tunneling and an extra/unnecessary haproxy to access horizon and console services that point straight to the haproxy instance installed on the controller nodes (should be visible in the baremetal how-to setup).
- Shared storage is provided via NFS from the commodity server due to lack of dedicated CEPH servers. Any other kind of storage supported by OpenStack would work just fine.
- Some minor services within major are still A/P (for example swift garbage collector, part of swift proxy service is A/P while the major is A/A)
- rhos6-node1|2|3 are currently disposable VMs running on top of mrg-07|mrg-08|mrg-09. The deployment can be done also on baremetal, but for debugging/testing/redeployment purposes, VMs backed by qcow2 images are more effective.
- Most of the how-to contains some shell expansion to automatically fill in some values.  Use your common sense when parsing data. Example:
- openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(ip addr show dev vmnet0 scope global | grep inet | sed -e 's#.*inet ##g' -e    's#/.*##g')
means that we want the IP address from vmnet0 as vncserver_proxyclient_address.
- Interface vmnet0 is specific to this setup.
- A line:  rhos6-node1|rhos6-node2|rhos6-node3: 
means that the following commands must be executed on all nodes.
- rhos6-node1:
means that it must be executed only on that specific node.
- openvswitch does NOT work properly in RHEL7.1. DO NOT USE! https://bugzilla.redhat.com/show_bug.cgi?id=1185521
- There are tons of comments and warnings around. READ THEM!!


# TODO

- Missing how-to add / remove a node
- Missing how-to move a service from cluster X to cluster Y
- nova network HA
- A/A service managed by pacemaker vs systemd
- Compute nodes managed by pacemaker_remoted
- Remove all artificial sleep and use pcs --wait once 7.1 is out of the door
- Improve nova-compute test section with CLI commands
- re-check keystone -> other services start order require-all=false option

# Network and Service diagram

- neutron-agents are directly connected to the external LAN
- all APIs are exposed only in the internal LAN
- as already noted, horizon is exposed to the external LAN via an extra haproxy instance installed on the commodity server
- Compute nodes have a management connection to the external LAN but it is not used by OpenStack and hence not reproduced in the diagram. This will be used when adding nova network setup.

# Hardware Requirements
A minimum of 5 machines are required to deploy this setup:
- 1 commodity server (can be a VM) to deploy nfs-server, dhcp, dns
- 1 bare metal node to be used a compute node
- 3 controller nodes (can be VM)

As noted before, this setup uses:
- 1 commodity server (mrg-01) bare metal
- 3 bare metal nodes to be used a compute nodes (mrg-02|mrg-03|mrg-04)
- 3 controller nodes (rhos6-node1|rhos6-node2|rhos6-node3) that are 3 VMs running on top of mrg-07|mrg-08|mrg-09

2 physical LAN:
- public facing LAN (10.x.y.z). All mrg-0x nodes are connected here. To keep interface naming standard across all nodes (instead of using ethX or emX or some random generated names), we will use ext0 to identify the network interface (bridge) connected to the public lan. The VMs are connected to the public LAN via eth0.
- internal LAN (192.168.16.x). All mrg-0x nodes and all VMs (rhos6-nodeX) are connected here. Similar as above we will use vmnet0 to identify interfaces connected here. The VMs are connected to the private LAN via eth1

# Hardware / VM deployment

Start by creating a minimal CentOS installation on at least four nodes.
No OpenStack services or HA will be running here.

The first of the four will become a public gateway (see later) and the rest will host one member of each virtual cluster.
Each virtual cluster must contain at least three nodes because [TODO].

You can have up to 16 (this is currently limited by corosync's ability to scale higher).
In extreme cases, 32 and even up to 64 nodes could be possible however this is not well tested. 

Once the machines have been installed, [prepare them](basic-baremetal.scenario) for hosting OpenStack.

NOTE: The following step may not be necessary in your environment.

In some environments, the available IP address range of the public LAN
is limited. To avoid overlapping in such scenarios, we set up a
[gateway](osp-gateway.scenario) on the first node to provide DNS and
DHCP for the guests containing the OpenStack services and exposes the
required nova and horizon APIs to the external network.


Next we must [create the image](osp-virt-hosts.scenario) for the guests that will host the OpenStack services and clone it.
Once the image has been created, we can prepare the hosting nodes and [clone](osp-virt-hosts.scenario) it.

# Deploy OpenStack HA controllers
In this example rhos6-node1, rhos6-node2, rhos6-node3 are deployed as controller. 
It is possible to deploy up to 16 nodes to act as controllers but not less than 3 without special casing of some services.

## Installing core non-Openstack services
This how-to is divided in 2 sections. The first section is used to deploy all core non-OpenStack services, the second section all OpenStack services.

Current version of the how-to uses pacemaker to drive all services.

### Install Pacemaker

Even when a service can survive one or more node failures, there is still a need for a cluster manager to 

1. co-ordinate the startup/shutdown of other services on the same host
1. co-ordinate the startup/shutdown of other services on _other_ hosts
1. co-ordinate the startup/shutdown of other instances of a service on _other_ hosts
1. integrate with quorum and provide fencing capabilities

Item 3. is of particular relevance to services like galera and rabbitmq that have complicated boot-up sequences.

The [basic cluster setup](basic-cluster.scenario) instructions are required for every cluster.

When performing an All-in-One deployment, there is only one cluster and now is the time to perform it.
When performing an One-Cluster-per-Service deployment, this should be performed before configuring each component.

### Install haproxy

Using a proxy allows:

- simplified process for adding/removing of nodes
- enhanced failure detection
- API isolation
- load distribution

If you are performing a One-Cluster-per-Service deployment, follow the [basic cluster setup](basic-cluster.scenario) instructions.

Once you have a functional cluster, you can then deploy the [load balancer](osp-lb.scenario).
Tasks to be performed at this step include:

*   Tweaking the IP stack to allow nonlocal binding and adjusting keepalive timings
*   Configuring haproxy

    Generally we use round-robin to distriute load, however Qpid and RabbitMQ use the stick-table option.
    TODO: Why?

    The check interval is 1 second however the timeouts vary by service.

    Galera requires the httpchk option because [TODO]

*   Adding the virtual IPs to the cluster
*   Putting haproxy under the cluster's control

### Install galera
### Install RabbitMQ
### Install Qpid
### Install memcached
### Install mongodb (optional)
## Installing Openstack services
### Install keystone
### Install glance
### Install cinder
### Install swift AOC (optional)
### Install swift proxy (optional)
### Install neutron server (optional)
### Install neutron agents (optional)
### Install nova (non-compute)
### Install ceilometer (optional)
### Install heat (optional)
### Install horizon
### Install compute nodes (standalone)
