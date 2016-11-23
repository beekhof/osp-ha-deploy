# Highly Available Openstack Deployments

The current target for this document is RDO 10, based on
the OpenStack Newton release.

Looking for an edition prior to Newton (RDO10)?

Check out the [Juno-RDO6](../Juno-RDO6/ha-openstack.md) or
[Mitaka-RDO9](../Mitaka-RDO9/ha-openstack.md) branches instead.

## Purpose of this Document

This document aims at defining a high level architecture for a highly
available RHEL OSP setup with the [Pacemaker](http://clusterlabs.org)
cluster manager which provides:

- detection and recovery of machine and application-level failures
- startup/shutdown ordering between applications
- preferences for other applications that must/must-not run on the same machine
- provably correct response to any failure or cluster state

It is important to understand the following definitions used to
describe the operational mode of services in a cluster:

- Active/active 

  Traffic intended for the failed node is either passed onto an
  existing node or load balanced across the remaining nodes. This is
  usually only possible when the nodes use a homogeneous software
  configuration.

- Active/passive

  Provides a fully redundant instance of each node, which is only
  brought online when its associated primary node fails. This
  configuration typically requires the most extra hardware.

In this document, all components are currently modelled as
active/active with the exception of:

- cinder-volume

Implementation details are contained in scripts linked to from the main document.
Read them carefully before considering to run them in your own environment. 

## Historical Context

In the previous OpenStack HA architectures used by Red Hat, SuSE and
others, Systemd is the entity in charge of starting and stopping most
OpenStack services. Pacemaker exists as a layer on top, signalling
when this should happen, but Systemd is the part making it happen.

This is a valuable contribution for active/passive (A/P) services and
those that require all their dependancies be available during their
startup and shutdown sequences. However as OpenStack has matured, more
and more components are able to operate in an unconstrained
active/active capacity with little regard for the startup/shutdown
order of their peers or dependancies - making them well suited to be
managed exclusively by Systemd.

## Overall Design

With Newton, OpenStack has reached the point where it is now a good
idea to limit Pacemaker’s involvement to core services like Galera and
Rabbit as well as the few remaining OpenStack services, such as
cinder-volume, that run A/P.

This will be particularly useful as we look towards a containerised
future. It both allows OpenStack to play nicely with the current
generation of container managers which lack Orchestration
capabilities, as well as reducing recovery and down time by allowing
for the maximum possible parallelism.

Any objections to this architecture usually fall into one of three
main categories:

1. The use of Pacemaker as an alerting mechanism
1. The idea that Pacemaker provides better monitoring of systemd services
1. A believe that active/passive installations are suprior

If these concerns apply to you then, as the founding author of
Pacemaker, I would like to direct your attention to my
[post](http://blog.clusterlabs.org/blog/2016/next-openstack-ha-arch)
which will attempt to disuade you of their relevance.

This reference design is based around a single cluster of 3 or more
nodes on which every component is running.
   
This scenario can be visualized as below:
    
  ![Collapsed deployment architecture](Cluster-deployment-collapsed.png)

With the advent of composable roles however, it is certainly possible
to dedicate a subset of nodes for one or more components that are
expected to be a bottleneck.

It is also possible that these dedicated nodes run extra copies of
those service, in addition to the ones on a fully symmetrical core set
of nodes.

## Assumptions

It is required that the clusters contain at least three nodes so that
we take advantage of
[quorum](http://en.wikipedia.org/wiki/Quorum_(Distributed_Systems))

Quorum becomes important when a failure causes the cluster to split in
two or more paritions.  In this situation, you want the majority to
ensure the minority are truely dead (through fencing) and continue to
host resources.  For a two-node cluster, no side has the majority and
you can end up in a situations where both sides fence each other, or
both sides are running the same services - leading to data corruption.

Clusters with an even number of hosts suffer from similar issues - a
single network failure could easily cause a N:N split where neither
side retains a majority.  For this reason, we recommend an odd number
of cluster members when scaling up.

You can have up to 16 cluster members (this is currently limited by
corosync's ability to scale higher).  In extreme cases, 32 and even up
to 64 nodes could be possible however this is not well tested.

In some environments, the available IP address range of the public LAN
is limited. If this applies to you, you will need one additional node
to set up as a [gateway](pcmk/gateway.scenario) that will provide DNS
and DHCP for the guests containing the OpenStack services and expose
the required nova and horizon APIs to the external network.

## Solution Components

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
[Pacemaker](http://clusterlabs.org) is highly recommended.

### Proxy server

Almost all services in this stack are proxied.
Using a proxy server provides:

1.  Load distribution
    
    Many services can act in an active/active capacity, however they
    usually require an external mechanism for distributing requests to
    one of the available instances. The proxy server can serve this
    role.

1.  API isolation
    
    By sending all API access through the proxy, we can clearly
    identify service interdependancies.  We can also move them to
    locations other than `localhost` to increase capacity if the need
    arises.

1.  Simplified process for adding/removing of nodes
    
    Since all API access is directed to the proxy, adding or removing
    nodes has no impact on the configuration of other services.  This
    can be very useful in upgrade scenarios where an entirely new set
    of machines can be configured and tested in isolation before
    telling the proxy to direct traffic there instead.

1.  Enhanced failure detection

    The proxy can be configured as a secondary mechanism for detecting
    service failures.  It can even be configured to look for nodes in
    a degraded state (such as being 'too far' behind in the
    replication) and take them out of circulation.

The following components are currently unable to benefit from the use
of a proxy server:

- RabbitMQ
- memcached
- mongodb

However the reasons vary and are discussed under each component's
heading.

We recommend HAProxy as the load balancer, however there are many
alternatives in the marketplace.

We use a check interval of 1 second however the timeouts vary by service.

Generally we use round-robin to distriute load amongst instances of
active/active services, however Galera and Qpid use the `stick-table`
options to ensure that incoming connections to the virtual IP (VIP)
should be directed to only one of the available backends.

In Galera's case, although it can run active/active, this helps avoid
lock contention and prevent deadlocks.  It is used in combination with
the `httpchk` option that ensures only nodes that are in sync with its
peers are allowed to handle requests.

Qpid however operates in a active/passive configuration, no built-in
clustering, so in it's case the `stick-table` option ensures that all
requests go to the active instance.

### Replicated Database

Most OpenStack components require access to a database.

To avoid the database being a single point of failure, we require that
it be replicated and the ability to support multiple masters can help
when trying to scale other components.

One of the most popular database choices is Galera for MySQL, it supports:

- Synchronous replication
- active/active multi-master topology
- Automatic node joining
- True parallel replication, on row level
- Direct client connections, native MySQL look & feel

and claims:

- No slave lag
- No lost transactions
- Both read and write scalability
- Smaller client latencies

Although galera supports active/active configurations, we recommend
active/passive (enforced by the load balancer) in order to avoid lock
contention.

### Database Cache

Memcached is a general-purpose distributed memory caching system. It
is used to speed up dynamic database-driven websites by caching data
and objects in RAM to reduce the number of times an external data
source must be read.

__Note__: Access to memcached is not handled by HAproxy because
replicated access is currently only in an experimental state.  Instead
consumers must be supplied with the full list of hosts running
memcached.

### Message Bus

An AMQP (Advanced Message Queuing Protocol) compliant message bus is
required for most OpenStack components in order to co-ordinate the
execution of jobs entered into the system.

RabbitMQ and Qpid are common deployment options. Both support:

- reliable message delivery
- flexible routing options
- replicated queues

This guide assumes RabbitMQ is being deployed, however we also
[document Qpid (TODO)](pcmk/osp-qpid.scenario) for completeness.  Pay
attention to the comments in that guide for how selecting `Qpid` affects
the rest of the configuration.

__Note__: Access to RabbitMQ is not handled by HAproxy.  Instead
consumers must be supplied with the full list of hosts running
RabbitMQ with `rabbit_hosts` and `rabbit_ha_queues` options.

Jock Eck found the [core
issue](http://people.redhat.com/jeckersb/private/vip-failover-tcp-persist.html)
and went into some detail regarding the [history and
solution](http://john.eckersberg.com/improving-ha-failures-with-tcp-timeouts.html)
on his blog.

In summary though:

> The source address for the connection from HAProxy back to the
> client is the VIP address. However the VIP address is no longer
> present on the host. This means that the network (IP) layer deems
> the packet unroutable, and informs the transport (TCP) layer. TCP,
> however, is a reliable transport. It knows how to handle transient
> errors and will retry. And so it does.

In this case that is a problem though, because:

> TCP generally holds on to hope for a long time. A ballpark estimate
> is somewhere on the order of tens of minutes (30 minutes is commonly
> referenced). During this time it will keep probing and trying to
> deliver the data.
>
> It's important to note that HAProxy has no idea that any of this is
> happening. As far as its process is concerned, it called write()
> with the data and the kernel returned success.

The [resolution](https://review.openstack.org/#/c/146047/) is already
understood and just needs to make its way through review.

## Core OpenStack services

In contrast to earlier versions of this guide, with the exception of
Cinder Volume, there are no specific instructions with regards to the
installation core OpenStack services beyond:

1. Ensuring services that make use of RabbitMQ list all configured servers
1. Accessing Galera and all OpenStack peer APIs (keystone, etc) via the HAProxy and the VIPs 

In all other respects, one should follow standard practices for
installing packages and instructing the system to start them at boot
time.

### Cinder

Cinder provides 'block storage as a service' suitable for performance
sensitive scenarios such as databases, expandable file systems, or
providing a server with access to raw block level storage.

Persistent block storage can survive instance termination and can also
be moved across instances like any external storage device. Cinder
also has volume snapshots capability for backing up the volumes.

In theory cinder can be run as active/active however there are
currently sufficient concerns that cause us to recommend running the
volume component as active/passive only.

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
for addressing them upstream.

# Implementation

The best way to visualize the result of this architecture is to make
use of
[tripleo-quickstart](https://github.com/openstack/tripleo-quickstart/blob/master/README.rst)
which implements the described architecture.

This will take a bare metal installation of your favorite OS (surely CentOS 7.2) and:

1. create a 'stack' user
1. create several VMs representing the undercloud, control plane and computes
1. deploy the undercloud (TripleO uses a pre-rolled OpenStack image as a means for deploying and updating the user facing installation of OpenStack aka. the overcloud) 
1. deploy the overcloud for you to investigate and compare your existing architecture against


    git clone git@github.com:openstack/tripleo-quickstart.git
    cd tripleo-quickstart
    ./quickstart.sh -b -n -w $PWD -c config/general_config/ha.yml  -p quickstart-extras.yml -r quickstart-extras-requirements.txt --tags all -R newton -T all ${the_machine_you_wish_to_install_to}


For those that would prefer not to deal with TripleO, you can see
roughly what TripleO does by examining the pseudo code for manually:

1. configuring a basic [pacemaker cluster](pcmk/basic-cluster.scenario)
1. deploying the [load balancer](pcmk/lb.scenario)
1. deploying [galera](pcmk/galera.scenario)
1. deploying [memcached](pcmk/memcached.scenario)
1. deploying [rabbitmq](pcmk/rabbitmq.scenario)
1. deploying [cinder volume](pcmk/cinder.scenario)

Here is a [list of variables](pcmk/ha-collapsed.variables) used when
executing the referenced scripts.  Modify them to your needs.

## Disclaimer 

- The referenced scripts contain many comments and warnings - READ THEM CAREFULLY.
- There are probably 2^8 other ways to deploy this same scenario. This is only one of them.
- Due to limited number of available physical LAN connections in the test setup, the instance IP traffic overlaps with the internal/management network.
- Distributed/Shared storage is provided via NFS from the commodity server due to lack of dedicated CEPH servers. Any other kind of storage supported by OpenStack would work just fine.
- Bare metal could be used in place of any or all guests.
- Most of the scripts contain shell expansion to automatically fill in some values.  Use your common sense when parsing data. Example:

  `openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address $(ip addr show dev vmnet0 scope global | grep inet | sed -e 's#.*inet ##g' -e    's#/.*##g')`

  means that we want the IP address from vmnet0 as vncserver_proxyclient_address.

# Compute Nodes 

We will usually need more than 16 compute nodes
which is beyond Corosync's ability to manage. So in order monitor the
healthiness of compute nodes and the services running on them, we
previously had to create single node clusters.

The current deployment model allows Pacemaker to continue this role,
but presents a single coherent view of the entire deployment while
allowing us to scale beyond corosync's limits. Having this single
administrative domain then allows us to do clever things like
automated recovery of VMs running on a failed or failing compute node.

The main difference with the previous deployment mode is that services
on the compute nodes are now managed and driven by the Pacemaker
cluster on the control plane. The compute nodes do not become full
members of the cluster and they no longer require the full cluster
stack, instead they run pacemaker_remoted which acts as a conduit.

> Implementation Details:
>
> - Pacemaker monitors the connection to pacemaker_remoted to verify
>   that the node is reachable or not.  Failure to talk to a node
>   triggers recovery action.
>
> - Pacemaker uses pacemaker_remoted to start compute node services in
>   the same sequence as before (neutron-ovs-agent ->
>   ceilometer-compute -> nova-compute).
>
> - If a service fails to start, any services that depend on the
>   FAILED service will not be started.  This avoids the issue of 
>   adding a broken node (back) to the pool.
> 
> - If a service fails to stop, the node where the service is running
>   will be fenced.  This is necessary to guarantee data integrity and
>   a core HA concept (for the purposes of this particular discussion,
>   please take this as a given).
> 
> - If a service's health check fails, the resource (and anything that
>   depends on it) will be stopped and then restarted.  Remember that
>   failure to stop will trigger a fencing action.
>
> - A successful restart of all the services can only potentially
>   affect network connectivity of the instances for a short period of
>   time.

With these capabilities in place, we can exploit Pacemaker's node
monitoring and fencing capabilities to drive nova host-evacuate for
the failed compute nodes and recover the VMs elsewhere.

When a compute node fails, Pacemaker will:

1. Execute 'nova service-disable'
2. fence (power off) the failed compute node
3. fence_compute off (waiting for nova to detect compute node is gone)
4. fence_compute on (a no-op unless the host happens to be up already)
5. Execute 'nova service-enable' when the compute node returns

Technically steps 1 and 5 are optional and they are aimed to improve
user experience by immediately excluding a failed host from nova
scheduling.

The only benefit is a faster scheduling of VMs that happens during a
failure (nova does not have to recognize a host is down, timeout and
subsequently schedule the VM on another host).

Step 2 will make sure the host is completely powered off and nothing
is running on the host.  Optionally, you can have the failed host
reboot which would potentially allow it to re-enter the pool.

We have an implementation for Step 3 but the ideal solution depends on
extensions to the nova API.  Currently fence_compute loops, waiting
for nova to recognise that the failed host is down, before we make a
host-evacuate call which triggers nova to restart the VMs on another
host.  The discussed nova API extensions will speed up recovery times
by allowing fence_compute to proactively push that information into
nova instead.


To take advantage of the VM recovery features:

- VMs need to be running off a cinder volume or using shared ephemeral
  storage (like RBD or NFS)

- If VM is not running using shared storage, recovery of the instance
  on a new compute node would need to revert to a previously stored
  snapshot/image in Glance (potentially losing state, but in some
  cases that may not matter)

- RHEL7.1+ required for infrastructure nodes (controllers and
  compute). Instance guests can run anything.

- Compute nodes need to have a working fencing mechanism (IPMI,
  hardware watchdog, etc)

## Compute Node Implementation

Start by creating a minimal CentOS __7__ installation on at least one node.

Once the machine(s) have been installed, [prepare
them](pcmk/baremetal.scenario) for hosting OpenStack.

Next, you can configure them as [compute nodes](pcmk/compute-common.scenario).

We now add them to the cluster as [partial members](pcmk/compute-managed.scenario).

Once the compute nodes are configured as remote, they can be added
to the [controller backplane](pcmk/controller-managed.scenario)

> TODO: what if nova-compute fails to restart and there are scheduled
> instances?  Those can still be accessed from outside but cannot be
> managed by nova.  This might warrant a host-evacuate.
>
> Traditionally, HA systems would fence the node at this point.



