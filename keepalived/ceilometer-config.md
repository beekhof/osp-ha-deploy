Introduction
------------

In terms of high availability, the Ceilometer central agent deserves special attention. This agent had to run in a single node until the Juno release cycle, since there was no way to coordinate multiple agents and ensure they would not duplicate metrics. Now, multiple central agent instances can run in parallel with workload partitioning among these running instances, using the tooz library with a Redis backend for coordination. See [here](http://docs.openstack.org/admin-guide-cloud/content/section_telemetry-cetral-compute-agent-ha.html) for additional information.

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/ceilometer.scenario).

Install software
----------------

    yum install -y openstack-ceilometer-api openstack-ceilometer-central openstack-ceilometer-collector openstack-ceilometer-common openstack-ceilometer-alarm python-ceilometer python-ceilometerclient

**Note:** python-tooz 0.13.2 or later is required (https://bugzilla.redhat.com/show_bug.cgi?id=1203706). This should be fixed by the Kilo GA date.

Configure ceilometer
--------------------

    openstack-config --set /etc/ceilometer/ceilometer.conf keystone_authtoken identity_uri http://controller-vip.example.com:35357/
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
    openstack-config --set /etc/ceilometer/ceilometer.conf database max_retries -1

    # keep last 5 days data only (value is in secs)
    openstack-config --set /etc/ceilometer/ceilometer.conf database metering_time_to_live 432000
    openstack-config --set /etc/ceilometer/ceilometer.conf api host 192.168.1.22X

Configure coordination URL
--------------------------

    openstack-config --set /etc/ceilometer/ceilometer.conf coordination backend_url 'redis://hacontroller1:26379?sentinel=mymaster&sentinel_fallback=hacontroller2:26379&sentinel_fallback=hacontroller3:26379'

Enable and start Ceilometer services, open firewall ports
---------------------------------------------------------

    systemctl start openstack-ceilometer-central 
    systemctl enable openstack-ceilometer-central 
    systemctl start openstack-ceilometer-collector
    systemctl enable openstack-ceilometer-collector
    systemctl start openstack-ceilometer-api 
    systemctl enable openstack-ceilometer-api 
    systemctl start openstack-ceilometer-alarm-evaluator
    systemctl enable openstack-ceilometer-alarm-evaluator 
    systemctl start openstack-ceilometer-alarm-notifier
    systemctl enable openstack-ceilometer-alarm-notifier
    systemctl start openstack-ceilometer-notification
    systemctl enable openstack-ceilometer-notification
    firewall-cmd --add-port=8777/tcp
    firewall-cmd --add-port=8777/tcp --permanent
    firewall-cmd --add-port=4952/udp
    firewall-cmd --add-port=4952/udp --permanent

Tests
-----

On any node:

    . /root/keystonerc_admin

    for m in storage.objects image network volume instance ; do ceilometer sample-list -m $m | tail -2 ; done
