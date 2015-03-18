Introduction
------------

A load-balancing proxy is used to provide scalability and load balancing for OpenStack API services and some of the supporting services. All requests will be distributed using a round-robin algorithm between all available controller nodes, and HAProxy itself will monitor the availability of each service. In case a node or service goes down, HAProxy will remove it from the active pool after a timeout has been reached, tipically a few seconds.

The following commands will be executed on all controller nodes.

Install packages
----------------

    yum install -y haproxy openstack-selinux

Allow binding to non-local IPs
------------------------------

    echo net.ipv4.ip_nonlocal_bind=1 >> /etc/sysctl.d/haproxy.conf
    echo 1 > /proc/sys/net/ipv4/ip_nonlocal_bind

Configure HAProxy
-----------------

    cat > /etc/haproxy/haproxy.cfg << EOF
    global
        daemon
        stats socket /var/lib/haproxy/stats
    defaults
        mode tcp
        maxconn 10000
        timeout connect 5s
        timeout client 30s
        timeout server 30s

    listen monitor
        bind 192.168.1.220:9300 
        mode http
        monitor-uri /status
        stats enable
        stats uri /admin
        stats realm Haproxy\ Statistics
        stats authroot:redhat
        stats refresh 5s

    frontend vip-db
        bind 192.168.1.220:3306
        timeout client 90m
        default_backend db-vms-galera
    backend db-vms-galera
        option httpchk
        stick-table type ip size 2
        stick on dst
        timeout server 90m
        server rhos6-node1 192.168.1.221:3306 check inter 1s port 9200 on-marked-down shutdown-sessions
        server rhos6-node2 192.168.1.222:3306 check inter 1s port 9200 on-marked-down shutdown-sessions
        server rhos6-node3 192.168.1.223:3306 check inter 1s port 9200 on-marked-down shutdown-sessions

    # Note the RabbitMQ entry is only needed for CloudForms compatibility
    # and should be removed in the future
    frontend vip-rabbitmq
        option clitcpka
        bind 192.168.1.220:5672
        timeout client 900m
        default_backend rabbitmq-vms
    backend rabbitmq-vms
        option srvtcpka
        balance roundrobin
        timeout server 900m
        server rhos6-node1 192.168.1.221:5672 check inter 1s
        server rhos6-node2 192.168.1.222:5672 check inter 1s
        server rhos6-node3 192.168.1.223:5672 check inter 1s

    frontend vip-keystone-admin
        bind 192.168.1.220:35357
        default_backend keystone-admin-vms
        timeout client 600s
    backend keystone-admin-vms
        balance roundrobin
        timeout server 600s
        server rhos6-node1 192.168.1.221:35357 check inter 1s on-marked-down shutdown-sessions
        server rhos6-node2 192.168.1.222:35357 check inter 1s on-marked-down shutdown-sessions
        server rhos6-node3 192.168.1.223:35357 check inter 1s on-marked-down shutdown-sessions

    frontend vip-keystone-public
        bind 192.168.1.220:5000
        default_backend keystone-public-vms
        timeout client 600s
    backend keystone-public-vms
        balance roundrobin
        timeout server 600s
        server rhos6-node1 192.168.1.221:5000 check inter 1s on-marked-down shutdown-sessions
        server rhos6-node2 192.168.1.222:5000 check inter 1s on-marked-down shutdown-sessions
        server rhos6-node3 192.168.1.223:5000 check inter 1s on-marked-down shutdown-sessions

    frontend vip-glance-api
        bind 192.168.1.220:9191
        default_backend glance-api-vms
    backend glance-api-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:9191 check inter 1s
        server rhos6-node2 192.168.1.222:9191 check inter 1s
        server rhos6-node3 192.168.1.223:9191 check inter 1s

    frontend vip-glance-registry
        bind 192.168.1.220:9292
        default_backend glance-registry-vms
    backend glance-registry-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:9292 check inter 1s
        server rhos6-node2 192.168.1.222:9292 check inter 1s
        server rhos6-node3 192.168.1.223:9292 check inter 1s

    frontend vip-cinder
        bind 192.168.1.220:8776
        default_backend cinder-vms
    backend cinder-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:8776 check inter 1s
        server rhos6-node2 192.168.1.222:8776 check inter 1s
        server rhos6-node3 192.168.1.223:8776 check inter 1s

    frontend vip-swift
        bind 192.168.1.220:8080
        default_backend swift-vms
    backend swift-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:8080 check inter 1s
        server rhos6-node2 192.168.1.222:8080 check inter 1s
        server rhos6-node3 192.168.1.223:8080 check inter 1s

    frontend vip-neutron
        bind 192.168.1.220:9696
        default_backend neutron-vms
    backend neutron-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:9696 check inter 1s
        server rhos6-node2 192.168.1.222:9696 check inter 1s
        server rhos6-node3 192.168.1.223:9696 check inter 1s

    frontend vip-nova-vnc-novncproxy
        bind 192.168.1.220:6080
        default_backend nova-vnc-novncproxy-vms
    backend nova-vnc-novncproxy-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:6080 check inter 1s
        server rhos6-node2 192.168.1.222:6080 check inter 1s
        server rhos6-node3 192.168.1.223:6080 check inter 1s

    frontend nova-metadata-vms
        bind 192.168.1.220:8775
        default_backend nova-metadata-vms
    backend nova-metadata-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:8775 check inter 1s
        server rhos6-node2 192.168.1.222:8775 check inter 1s
        server rhos6-node3 192.168.1.223:8775 check inter 1s

    frontend vip-nova-api
        bind 192.168.1.220:8774
        default_backend nova-api-vms
    backend nova-api-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:8774 check inter 1s
        server rhos6-node2 192.168.1.222:8774 check inter 1s
        server rhos6-node3 192.168.1.223:8774 check inter 1s

    frontend vip-horizon
        bind 192.168.1.220:80
        timeout client 180s
        cookie SERVERID insert indirect nocache
        default_backend horizon-vms
    backend horizon-vms
        balance roundrobin
        timeout server 180s
        server rhos6-node1 192.168.1.221:80 check inter 1s cookie rhos6-horizon1 on-marked-down shutdown-sessions
        server rhos6-node2 192.168.1.222:80 check inter 1s cookie rhos6-horizon2 on-marked-down shutdown-sessions
        server rhos6-node3 192.168.1.223:80 check inter 1s cookie rhos6-horizon3 on-marked-down shutdown-sessions

    frontend vip-heat-cfn
        bind 192.168.1.220:8000
        default_backend heat-cfn-vms
    backend heat-cfn-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:8000 check inter 1s
        server rhos6-node2 192.168.1.222:8000 check inter 1s
        server rhos6-node3 192.168.1.223:8000 check inter 1s

    frontend vip-heat-cloudw
        bind 192.168.1.220:8003
        default_backend heat-cloudw-vms
    backend heat-cloudw-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:8003 check inter 1s
        server rhos6-node2 192.168.1.222:8003 check inter 1s
        server rhos6-node3 192.168.1.223:8003 check inter 1s

    frontend vip-heat-srv
        bind 192.168.1.220:8004
        default_backend heat-srv-vms
    backend heat-srv-vms
        balance roundrobin
        server rhos6-node1 192.168.1.221:8004 check inter 1s
        server rhos6-node2 192.168.1.222:8004 check inter 1s
        server rhos6-node3 192.168.1.223:8004 check inter 1s

    frontend vip-ceilometer
        bind 192.168.1.220:8777
        timeout client 90s
        default_backend ceilometer-vms
    backend ceilometer-vms
        balance roundrobin
        timeout server 90s
        server rhos6-node1 192.168.1.221:8777 check inter 1s
        server rhos6-node2 192.168.1.222:8777 check inter 1s
        server rhos6-node3 192.168.1.223:8777 check inter 1s

    EOF

Note we are **not** starting haproxy yet.

Once HAproxy is started, you can monitor progress of your service configuration by going to [<http://controller-vip.example.com:9300/admin>](http://controller-vip.example.com:9300/admin) (root/redhat, remember to set a sensible password). With this you will be able to see which services are running on which nodes, as seen by HAproxy.
