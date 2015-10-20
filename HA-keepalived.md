Introduction
------------

This document aims at defining a high level architecture for a highly available OpenStack setup using application-native options and keepalived. It will document the overall setup, the architecture limitations and any important item to keep in mind when deploying.

The document can be used to create a highly available architecture for:

-   [RDO Kilo](http://openstack.redhat.com)
-   [Red Hat Enterprise Linux Openstack Platform 7](http://www.redhat.com/openstack)

If you are looking for the Juno edition, check out the [Juno-RDO6 branch](../Juno-RDO6/HA-keepalived.md).

Most of the time the instructions will apply to both distributions. If there is any difference, it will be specified throughout the document.

### Authors and changelog          

- Javier Peña (jpena@redhat.com) commited the initial version.

Architecture overview
---------------------

### Scope

This document will define, at a high level, the placement and high availability strategy for the different OpenStack services, as well as the limitations of the architecture.

Service monitoring and recovery are outside the scope for this document. You may choose to monitor and recover the running services health using any generally available monitoring tool, or implement automated service restart in systemd.

### Server roles

A typical OpenStack architecture will consist of servers performing various roles. The following roles may be spread over different servers or collapsed into some of them:

-   Controller nodes
-   Load balancer nodes
-   Database nodes
-   Network nodes
-   Storage nodes
-   Compute nodes

High availability for storage and compute nodes is out of the scope for this document.

### High availability strategy

The following diagram shows a very simplified view of the different strategies used to achieve high availability for the OpenStack services:

![](keepalived/Highlevelarch.jpg "High level architecture")

Depending on the method used to communicate with the service, the following availability strategies will be followed:

-   Keepalived, for the HAProxy instances.
-   Access via an HAProxy virtual IP, for services accessed via a TCP socket than can be load balanced (e.g. httpd).
-   Built-in application clustering, when available from the application (e.g. Galera) .
-   Starting up one instance of the service on several controller nodes, when they can coexist and coordinate by other means (e.g. RPC, in the case of nova-conductor).
-   No high availability, when the service can only work in active/passive mode.

The detailed high availability strategy for the OpenStack services is defined in the following table.

|      Service     |       Process              |  Mode  | HA stragegy |
|------------------|----------------------------|:------:|-------------|
| Support services |MariaDB - Galera            | A/A    | HAProxy / app cluster |
| Support services |RabbitMQ                    | A/A    | App cluster / service config |
| Support services |HAProxy                     | A/A    | Keepalived  |
| Support services |MongoDB                     | A/A    | App cluster |
| Support services |Memcached                   | A/A    | Service configuration |
| Support services |Redis                       | A/A    | App cluster (Sentinel)|
| Keystone         |openstack-keystone          | A/A    | HAProxy     |
| Glance           |openstack-glance-api        | A/A    | HAProxy     |
| Glance           |openstack-glance-registry   | A/A    | HAProxy     |
| Nova             |openstack-nova-api          | A/A    | HAProxy     |
| Nova             |openstack-nova-cert         | A/A    |             |
| Nova             |openstack-nova-compute      | A/A    |             |
| Nova             |openstack-nova-scheduler    | A/A    |             |
| Nova             |openstack-nova-conductor    | A/A    |             |
| Nova             |openstack-nova-novncproxy   | A/A    | HAProxy     |
| Cinder           |openstack-cinder-api        | A/A    | HAProxy     |
| Cinder           |openstack-cinder-scheduler  | A/A    |             |
| Cinder           |openstack-cinder-volume     | **A/P**| No HA       |
| Cinder           |openstack-cinder-backup     | A/A    |             |
| Neutron          |neutron-server              | A/A    | HAProxy     |
| Neutron          |neutron-dhcp-agent          | A/A    | Multiple DHCP agents |
| Neutron          |neutron-l3-agent            | A/A    | L3 HA       |
| Neutron          |neutron-metadata-agent      | A/A    |             |
| Neutron          |neutron-lbaas-agent         | **A/P**|             |
| Neutron          |neutron-openvswitch-agent   | A/A    |             |
| Neutron          |neutron-metering-agent      | A/A    |             |
| Horizon          |httpd                       | A/A    | HAProxy     |
| Ceilometer       |openstack-ceilometer-api    | A/A    | HAProxy     |
| Ceilometer       |openstack-ceilometer-central| A/A    | Workload partitioning: tooz + Redis|
| Ceilometer       |openstack-ceilometer-compute| A/A    |             |
| Ceilometer       |openstack-ceilometer-alarm-notifier| A/A    |             |
| Ceilometer       |openstack-ceilometer-evaluator| A/A    |             |
| Ceilometer       |openstack-ceilometer-notification| A/A    |             |
| Heat             |openstack-heat-api          | A/A    | HAProxy     |
| Heat             |openstack-heat-cfn          | A/A    |             |
| Heat             |openstack-heat-cloudwatch   | A/A    |             |
| Heat             |openstack-heat-engine       | A/A    |             |
| Swift            |openstack-swift-proxy       | A/A    | HAProxy     |
| Swift            |openstack-swift-account     | A/A    | HAProxy     |
| Swift            |openstack-swift-container   | A/A    | HAProxy     |
| Swift            |openstack-swift-object      | A/A    | HAProxy     |
| Sahara           |openstack-sahara-api        | A/A    | HAProxy     |
| Sahara           |openstack-sahara-engine     | A/A    |             |
| Trove            |openstack-trove-api         | A/A    | HAProxy     |
| Trove            |openstack-trove-engine      | A/A    |             |
| Trove            |openstack-trove-conductor   | A/A    |             |

**Notes:**

1.  There are known issues with cinder-volume that recommend setting it as active-passive for now, see <https://review.openstack.org/#/c/101237> and <https://bugzilla.redhat.com/show_bug.cgi?id=1193229>
2.  While there will be multiple Neutron LBaaS agents running, each agent will manage a set of load balancers, that cannot be failed over to another node.

Architecture limitations
------------------------

This architecture has some inherent limitations that should be kept in mind during deployment and daily operations. The following sections describe those limitations.

### Keepalived and network partitions

In case of a network partitioning, there is a chance that two or more nodes running keepalived claim to hold the same VIP, which may lead to an undesired behaviour. Since keepalived uses VRRP over multicast to elect a master (VIP owner), a network partition in which keepalived nodes cannot communicate will result in the VIPs existing on two nodes. When the network partition is resolved, the duplicate VIPs should also be resolved. Note that this network partition problem with VRRP is a known limitation for this architecture.

### Cinder-volume as a single point of failure

There are currently concerns over the cinder-volume service ability to run as a fully active-active service. During the Liberty timeframe, this is being worked on, see [1](https://github.com/Akrog/test-cinder-atomic-states). Thus, cinder-volume will only be running on one of the controller nodes, even if it will be configured on all nodes. In case of a failure in the node running cinder-volume, it should be started in a surviving controller node.

### Neutron-lbaas-agent as a single point of failure

The current design of the Neutron LBaaS agent using the HAProxy driver does not allow high availability for the tenant load balancers. The neutron-lbaas-agent service will be enabled and running on all controllers, allowing for load balancers to be distributed across all nodes. However, a controller node failure will stop all load balancers running on that node until the service is recovered or the load balancer is manually removed and created again.

### Service monitoring and recovery required

An external service monitoring infrastructure is required to check the OpenStack service health, and notify operators in case of any failure. This architecture does not provide any facility for that, so it would be necessary to integrate the OpenStack deployment with any existing monitoring environment.

### Manual recovery after a full cluster restart

Some support services used by RDO / RHEL OSP use their own form of application clustering. Usually, these services maintain a cluster quorum, that may be lost in case of a simultaneous restart of all cluster nodes, e.g. during a power outage. Each service will require its own procedure to regain quorum:

-   Galera: [Galera bootstrap instructions](keepalived/galera-bootstrap.md)
-   RabbitMQ: [RabbitMQ cluster restart](keepalived/rabbitmq-restart.md)
-   MongoDB: [MongoDB cluster recovery](keepalived/mongodb-recovery.md)

Implementation
--------------

The implementation will be split into two articles:

-   [Controller node implementation](keepalived/controller-node.md)
-   [Compute node implementation](keepalived/compute-node.md)
