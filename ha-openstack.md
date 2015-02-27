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

Start by creating a minimal CentOS installation on at least three nodes.
No OpenStack services or HA will be running here.

For each service we create a virtual cluster, with one member running on each of the physical hosts.
Each virtual cluster must contain at least three members because [TODO: quorum, fencing, etc].

You can have up to 16 cluster members (this is currently limited by corosync's ability
to scale higher).  In extreme cases, 32 and even up to 64 nodes could
be possible however this is not well tested.

In some environments, the available IP address range of the public LAN
is limited. If this applies to you, you will need one additional node
to set up as a [gateway](osp-gateway.scenario) that will provide DNS
and DHCP for the guests containing the OpenStack services and expose
the required nova and horizon APIs to the external network.

Once the machines have been installed, [prepare them](basic-baremetal.scenario) 
for hosting OpenStack.

Next we must [create the image](osp-virt-hosts.scenario) for the
guests that will host the OpenStack services and clone it.  Once the
image has been created, we can prepare the hosting nodes and
[clone](osp-virt-hosts.scenario) it.

# Deploy OpenStack HA controllers
It is possible to deploy up to 16 nodes to act as controllers but not less than 3 without special casing of some services.

## Installing core non-Openstack services

This how-to is divided in 2 sections. The first section is used to
deploy all core non-OpenStack services, the second section all
OpenStack services.

Pacemaker is used to drive all services.

### Cluster Manager

At its core, a cluster is a distributed finite state machine capable
of co-ordinating the startup and recovery of inter-related services
across a set of machines.

Even a distributed and/or replicated application that is able to
survive failures on one or more machines can benefit from a
cluster manager:

1.  Awareness of other applications in the stack
    
    While SYS-V init replacements like systemd can provide
    deterministic recovery of a complex stack of services, the
    recovery is limited to one machine and lacks the context of what
    is happening on other machines - context that is crucial to
    determine the difference between a local failure, clean startup
    and recovery after a total site failure.

1.  Awareness of instances on other machines

    Services like RabbitMQ and Galera have complicated boot-up
    sequences that require co-ordination, and often serialization, of
    startup operations across all machines in the cluster. This is
    especially true after site-wide failure or shutdown where we must
    first determine the last machine to be active.
    
1.  A shared implementation and calculation of [quorum](http://en.wikipedia.org/wiki/Quorum_%28Distributed_Systems%29)

    It is very important that all members of the system share the same
    view of who their peers are and whether or not they are in the
    majority.  Failure to do this leads very quickly to an internal
    [split-brain](https://en.wikipedia.org/wiki/Split-brain_(computing))
    state - where different parts of the system are pulling in
    different and incompatioble directions.

1.  Data integrity through fencing (a non-responsive process does not imply it is not doing anything)

    A single application does not have sufficient context to know the
    difference between failure of a machine and failure of the
    applcation on a machine.  The usual practice is to assume the
    machine is dead and carry on, however this is highly risky - a
    rogue process or machine could still be responding to requests and
    generally causing havoc.  The safer approach is to make use of
    remotely accessible power switches and/or network switches and SAN
    controllers to fence (isolate) the machine before continuing.

1.  Automated recovery of failed instances
    
    While the application can still run after the failure of several
    instances, it may not have sufficient capacity to serve the
    required volume of requests.  A cluster can automatically recover
    failed instances to prevent additional load induced failures.


For this reason, the use of a cluster manager like
[Pacemaker](http://clusterlabs.org) is highly recommended.  The [basic
cluster setup](basic-cluster.scenario) instructions are required for
every cluster.

When performing an All-in-One deployment, there is only one cluster and now is the time to perform it.
When performing an One-Cluster-per-Service deployment, this should be performed before configuring each component.

### Proxy server

Using a proxy allows:

- simplified process for adding/removing of nodes
- enhanced failure detection
- API isolation
- load distribution

If you are performing a One-Cluster-per-Service deployment, follow the [basic cluster setup](basic-cluster.scenario) instructions.

Once you have a functional cluster, you can then deploy the [load balancer](osp-lb.scenario) to the previously created guests.

Generally we use round-robin to distriute load, however Qpid and RabbitMQ use the stick-table option.
TODO: Why?

The check interval is 1 second however the timeouts vary by service.
Galera requires the httpchk option because [TODO]

### Replicated Database

Most OpenStack components require access to a database.
To avoid the database being a single point of failure, we require that it be replicated and the ability to support multiple masters can help when trying to scale other components.

One of the most popular database choices is Galera for MySQL, it supports:

- Synchronous replication
- Active-active multi-master topology
- Automatic node joining
- True parallel replication, on row level
- Direct client connections, native MySQL look & feel

and claims:

- No slave lag
- No lost transactions
- Both read and write scalability
- Smaller client latencies

Although galera supports active-active configurations, we recommend active-passive (enforced by the load balancer) in order to avoid lock contention.

To configure Galera, first follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain it.
Once you have a functional cluster, you can then [deploy galera](osp-galera.scenario) into it.

### Database Cache

Memcached is a general-purpose distributed memory caching system. It
is used to speed up dynamic database-driven websites by caching data
and objects in RAM to reduce the number of times an external data
source must be read.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain memcached.
Once you have a functional cluster, you can then [deploy memcached](osp-memcached.scenario) into it.

### Message Bus

An AMQP (Advanced Message Queuing Protocol) compliant message bus is required for most OpenStack components in order to co-ordinate the execution of jobs entered into the system.
RabbitMQ and Qpid are common deployment options. Both support:

- reliable message delivery
- flexible routing options
- replicated queues

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain RabbitMQ or Qpid.
Once you have a functional cluster, you can then deploy [rabbitmq](osp-rabbitmq.scenario) or [qpid](osp-qpid.scenario)into it.

### NoSQL Database (optional)

If you plan to install ceilometer, you will need a NoSQL database such as mongodb.

MongoDB is a cross-platform document-oriented database that eschews
the traditional table-based relational database structure in favor of
JSON-like documents with dynamic schemas, making the integration of
data in certain types of applications easier and faster.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain mongodb.
Once you have a functional cluster, you can then [deploy mongodb](osp-mongodb.scenario) into it.

## Installing Openstack services
### Keystone

Keystone is an OpenStack project that provides Identity, Token,
Catalog and Policy services for use specifically by projects in the
OpenStack family. It implements OpenStack's Identity API.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain keystone.
Once you have a functional cluster, you can then [deploy keystone](osp-keystone.scenario) into it.

### Glance

The Glance project provides a service where users can upload and
discover data assets that are meant to be used with other
services. This currently includes images and metadata definitions.

Glance image services include discovering, registering, and retrieving
virtual machine images.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain glance.
Once you have a functional cluster, you can then [deploy glance](osp-glance.scenario) into it.

### Cinder

Cinder provides 'block storage as a service'.

In theory cinder can be run as active-active however there are
currently sufficient concerns that cause us to recommend running the
volume component as active-passive only.

Jon Bernard writes:

> Requests are first seen by Cinder in the API service, and we have a
> fundamental problem there - a standard test-and-set race condition
> exists for many operations where the volume status is first checked
> for an expected status and then (in a different operation) updated to
> a pending status.  The pending status indicates to other incoming
> requests that the volume is undergoing a current operation, however it
> is possible for two simultaneous requests to race here, which
> undefined results.
> 
> Later, the manager/driver will receive the message and carry out the
> operation.  At this stage there is a question of the synchronization
> techniques employed by the drivers and what guarantees they make.
> 
> If cinder-volume processes exist as different process, then the
> 'synchronized' decorator from the lockutils package will not be
> sufficient.  In this case the programmer can pass an argument to
> synchronized() 'external=True'.  If external is enabled, then the
> locking will take place on a file located on the filesystem.  By
> default, this file is placed in Cinder's 'state directory' in
> /var/lib/cinder so won't be visible to cinder-volume instances running
> on different machines.
> 
> However, the location for file locking is configurable.  So an
> operator could configure the state directory to reside on shared
> storage.  If the shared storage in use implements unix file locking
> semantics, then this could provide the requisite synchronization
> needed for an active/active HA configuration.
> 
> The remaining issue is that not all drivers use the synchronization
> methods, and even fewer of those use the external file locks.
> A sub-concern would be whether they use them correctly.

You can read more about these concerns on the [Red Hat
Bugzilla](https://bugzilla.redhat.com/show_bug.cgi?id=1193229) and
there is a [psuedo roadmap](https://etherpad.openstack.org/p/cinder-kilo-stabilisation-work)
for addressing the concerns upstream.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain cinder.
Once you have a functional cluster, you can then [deploy cinder](osp-cinder.scenario) into it.

### Swift AOC (optional)

Swift is a highly available, distributed, eventually consistent
object/blob store. Organizations can use Swift to store lots of data
efficiently, safely, and cheaply.

As mentioned earlier, limitations in Corosync prevent us from
combining more than 16 machines into a logic unit. In the case of
Swift, although this is fune for the proxy, it is insufficient for the
worker nodes.

There are plans to make use of something called `pacemaker-remote` to
allow the cluster to manage more than 16 worker nodes, but until this
is properly documented, the work-around is to create each Swift worker
as an single node cluster - independant of all the others. This avoids
the 16 node limit while still making sure the individual Swift daemons
are being monitored and recovered as necessary.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on every guest intended to contain Swift.
Once you have a set of functional single-node clusters, you can then [deploy swift AOCs](osp-swift-aoc.scenario) into them.

### Swift Proxy (optional)

The Proxy Server is responsible for tying together the rest of the
Swift architecture. For each request, it will look up the location of
the account, container, or object in the ring (see below) and route
the request accordingly.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain the swift proxy.
Once you have a functional cluster, you can then [deploy swift](osp-swift.scenario) into it.

### Networking

Neutron and Nova are two commonly deployed projects that can provide 'network connectivity as a service' between interface devices (e.g., vNICs) managed by other OpenStack services (e.g., nova).

Neutron is preferred when [TODO].
Nova is preferred when [TODO].

#### Installing Neutron
Server:

Agents:

#### Installing Nova (non-compute)

For nova, first follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain nova.
Once you have a functional cluster, you can then [deploy nova](osp-nova.scenario) into it.

### Ceilometer (optional)

The Ceilometer project aims to deliver a unique point of contact for
billing systems to acquire all of the measurements they need to
establish customer billing, across all current OpenStack core
components with work underway to support future OpenStack components.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain ceilometer.
Once you have a functional cluster, you can then [deploy ceilometer](osp-ceilometer.scenario) into it.

### Heat (optional)

Heat is a service to orchestrate multiple composite cloud applications
using the AWS CloudFormation template format, through both an
OpenStack-native ReST API and a CloudFormation-compatible Query API.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain heat.
Once you have a functional cluster, you can then [deploy heat](osp-heat.scenario) into it.

### Horizon

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on the guests intended to contain horizon.
Once you have a functional cluster, you can then [deploy horizon](osp-horizon.scenario) into it.

### Compute nodes (standalone)

Just like Swift, we will usually need more than 16 compute nodes which
is beyond Corosync's ability to manage.  So again we use the
work-around of create each compute node as a single node cluster -
independant of all the others. This avoids the 16 node limit while
still making sure the individual compute daemons are being monitored
and recovered as necessary.

First follow the [basic cluster setup](basic-cluster.scenario) instructions to set up a cluster on every guest intended to contain Swift.
Once you have a set of functional single-node clusters, you can then [deploy compute nodes](osp-compute.scenario) into them.
