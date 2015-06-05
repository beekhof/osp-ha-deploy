Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

You can find a phd scenario file [here](phd-setup/horizon.scenario).

Install software
----------------

    yum install -y mod_wsgi httpd mod_ssl python-memcached openstack-dashboard

Set secret key
--------------

On node 1:

    openssl rand -hex 10

Take note of the generated random value, then on all nodes:

    sed -i -e "s#SECRET_KEY.*#SECRET_KEY = 'VALUE'#g#" /etc/openstack-dashboard/local_settings

Configure local\_settings and httpd.conf
----------------------------------------

    sed -i -e "s#ALLOWED_HOSTS.*#ALLOWED_HOSTS = ['*',]#g" \
    -e "s#^CACHES#SESSION_ENGINE = 'django.contrib.sessions.backends.cache'\nCACHES#g#" \
    -e "s#locmem.LocMemCache'#memcached.MemcachedCache',\n\t'LOCATION' : [ 'hacontroller1:11211', 'hacontroller2:11211', 'hacontroller3:11211', ]#g" \
    -e 's#OPENSTACK_HOST =.*#OPENSTACK_HOST = "controller-vip.example.com"#g' \
    -e "s#^LOCAL_PATH.*#LOCAL_PATH = '/var/lib/openstack-dashboard'#g" \
    /etc/openstack-dashboard/local_settings

Restart httpd and open firewall port
------------------------------------

    systemctl daemon-reload
    systemctl restart httpd
    firewall-cmd --add-port=80/tcp
    firewall-cmd --add-port=80/tcp --permanent
