Introduction
------------

In general, RabbitMQ does a good job at restarting the cluster when all nodes are stared at the same time. However, we may find times were this is not the case, and we will have to restart the cluster manually.

According to [<http://previous.rabbitmq.com/v3_3_x/clustering.html>](http://previous.rabbitmq.com/v3_3_x/clustering.html) *"the last node to go down must be the first node to be brought online. If this doesn't happen, the nodes will wait 30 seconds for the last disc node to come back online, and fail afterwards."*. Thus, it is necessary to find the last node going down and start it. Depending on how the nodes were started, you may see some nodes running and some stopped.

Checking RabbitMQ cluster status
--------------------------------

Run the following command to verify the current RabbitMQ cluster status:

    rabbitmqctl cluster_status

    Cluster status of node rabbit@hacontroller3 ...
    [{nodes,[{disc,[rabbit@hacontroller1,rabbit@hacontroller2,
    rabbit@hacontroller3]}]},
    {running_nodes,[rabbit@hacontroller2,rabbit@hacontroller1,
    rabbit@hacontroller3]},
    {cluster_name,<<"rabbit@hacontroller1.example.com">>},
    {partitions,[]}]

### Some nodes are running

If some nodes are running, the most probable reason is that the failed nodes timed out before finding the last node to come back online. In this case, start rabbitmq-server on the failed nodes.

    [root@hacontroller1 ~]# systemctl start rabbitmq-server

### None of the nodes are running

In this case, we need to find which node should be started first.

Select a node as first node, start rabbitmq-server, then start it on the remaining nodes.

    [root@hacontroller2 ~]# systemctl start rabbitmq-server
    [root@hacontroller3 ~]# systemctl start rabbitmq-server
    [root@hacontroller1 ~]# systemctl start rabbitmq-server

Check that all nodes are running rabbitmq-server. If not, stop any surviving rabbitmq-server and select a different node as first node.
