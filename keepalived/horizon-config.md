Introduction
------------

The following commands will be executed on all controller nodes, unless otherwise stated.

Install software
----------------

    yum install -y mod_wsgi httpd mod_ssl python-memcached openstack-dashboard

Configure local\_settings and httpd.conf
----------------------------------------

    sed -i -e "s#ALLOWED_HOSTS.*#ALLOWED_HOSTS = ['*',]#g" \
    -e "s#^CACHES#SESSION_ENGINE = 'django.contrib.sessions.backends.cache'\nCACHES#g#" \
    -e "s#locmem.LocMemCache'#memcached.MemcachedCache',\n\t'LOCATION' : [ 'hacontroller1:11211', 'hacontroller2:11211', 'hacontroller3:11211', ]#g" \
    -e 's#OPENSTACK_HOST =.*#OPENSTACK_HOST = "controller-vip.example.com"#g' \
    -e "s#^LOCAL_PATH.*#LOCAL_PATH = '/var/lib/openstack-dashboard'#g" \
    /etc/openstack-dashboard/local_settings

    sed -i -e 's/^Listen.*/Listen 192.168.1.22X:80/g' /etc/httpd/conf/httpd.conf 

Enable service and open firewall port
-------------------------------------

    systemctl enable httpd
    firewall-cmd --add-port=80/tcp
    firewall-cmd --add-port=80/tcp --permanent

Create secret\_key\_store file
------------------------------

On node 1:

    systemctl start httpd
    curl http://controller-vip.example.com/dashboard
    scp /var/lib/openstack-dashboard/.secret_key_store hacontroller2:/var/lib/openstack-dashboard/.secret_key_store
    scp /var/lib/openstack-dashboard/.secret_key_store hacontroller3:/var/lib/openstack-dashboard/.secret_key_store

Import same secret\_key\_store file from node 1 and start httpd
---------------------------------------------------------------

On nodes 2 and 3:

    chown apache:apache /var/lib/openstack-dashboard/.secret_key_store
    chmod 600 /var/lib/openstack-dashboard/.secret_key_store
    systemctl start httpd
