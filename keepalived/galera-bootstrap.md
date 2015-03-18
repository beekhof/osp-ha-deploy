Introduction
------------

Here is an outline of the steps needed to re-establish/bootstrap Galera quorum.

1.  Determine loss of quorum
2.  Determine systems with last activity
3.  Start first DB on first node
4.  Start DB on remaining nodes

Determine loss of quorum
------------------------

Confirm in the */var/log/mariadb/mariadb.log* on each system, looking for Errors

    140929 11:25:40 [ERROR] WSREP: Local state seqno (1399488) is greater than group seqno (10068): states diverged. Aborting to avoid potential data loss. Remove '/var/lib/mysql//grastate.dat' file and restart if you wish to continue. (FATAL)
    140929 11:25:40 [ERROR] Aborting
    [root@ospha2 ~]#

Also the clustercheck command should so that there are some systems not in sync

    [root@ospha2 ~]# clustercheck
    HTTP/1.1 503 Service Unavailable
    Content-Type: text/plain
    Connection: close
    Content-Length: 36

    Galera cluster node is not synced.
    [root@ospha2 ~]#

Determine systems with last activity
------------------------------------

In this section we attempt to determine which system or systems has the highest valid sequence number for the for the latest UUID.

### Orderly shutdown

If the cluster shutdown correctly the `/var/lib/mysql/grastate.dat` file will have positive numbers for the seqno. Note which system or systems have the greatest seqno. However, if any system has a `-1` value, that indicates the shutdown was not clean and another method to determine the seqno is needed.

    [root@ospha2 ~]# cat /var/lib/mysql/grastate.dat
    # GALERA saved state
    version: 2.1
    uuid:    b048715d-4369-11e4-b7ef-af1999a6c989
    seqno:   -1
    cert_index:
    [root@ospha2 ~]#

### Disorderly Shutdown

The seqno is in the `/var/log/mariadb/mariadb.log` file. Search for lines with "Found save state", ignoring any -1 values. The last value on each line is in the form UUID:seqno.

    [root@ospha1 ~]# tail -n 1000 /var/log/mariadb/mariadb.log | grep "Found saved state"  | grep -v ":-1"
    140923 17:49:19 [Note] WSREP: Found saved state: b048715d-4369-11e4-b7ef-af1999a6c989:2229
    140924 15:37:13 [Note] WSREP: Found saved state: b048715d-4369-11e4-b7ef-af1999a6c989:2248
    140929 11:24:26 [Note] WSREP: Found saved state: b048715d-4369-11e4-b7ef-af1999a6c989:10060
    [root@ospha1 ~]#

    [root@ospha2 ~]# tail -n 1000 /var/log/mariadb/mariadb.log | grep "Found saved state"  | grep -v ":-1"
    140926 14:58:16 [Note] WSREP: Found saved state: b048715d-4369-11e4-b7ef-af1999a6c989:171535
    140929 11:24:28 [Note] WSREP: Found saved state: b048715d-4369-11e4-b7ef-af1999a6c989:1399488
    [root@ospha2 ~]#

    [root@ospha3 ~]# tail -n 2000 /var/log/mariadb/mariadb.log | grep "Found saved state"  | grep -v ":-1"
    140923 17:36:57 [Note] WSREP: Found saved state: b048715d-4369-11e4-b7ef-af1999a6c989:36
    140923 17:43:18 [Note] WSREP: Found saved state: b048715d-4369-11e4-b7ef-af1999a6c989:785
    [root@ospha3 ~]#

Notice all servers have the same UUID (b048715d-4369-11e4-b7ef-af1999a6c989), but server *ospha2* has the largest seqno (1399488).

Start first DB on first node
----------------------------

The following command will initiate the Galera cluster. Since ospha2 had the highest seqno, that is the node to start first.

    [root@ospha2 ~]# sudo -u mysql /usr/libexec/mysqld --wsrep-cluster-address='gcomm://' &
    [1] 1910
    [root@ospha2 ~]# 140929 16:31:00 [Warning] option 'open_files_limit': unsigned value 18446744073709551615 adjusted to 4294967295
    140929 16:31:00 [Warning] Could not increase number of max_open_files to more than 1024 (request: 1835)
    /usr/libexec/mysqld: Query cache is disabled (resize or similar command in progress); repeat this command later

Verify that this brought the this node into sync.

    [root@ospha2 ~]# clustercheck
    HTTP/1.1 200 OK
    Content-Type: text/plain
    Connection: close
    Content-Length: 32

    Galera cluster node is synced.
    [root@ospha2 ~]#

Start DB on remaining nodes
---------------------------

On another cluster member, start the database, and then verify this node reports synced.

    [root@ospha1 ~]#  systemctl start mariadb
    [root@ospha1 ~]# clustercheck
    HTTP/1.1 200 OK
    Content-Type: text/plain
    Connection: close
    Content-Length: 32

    Galera cluster node is synced.
    [root@ospha1 ~]#

Once `clustercheck` returns 200 on all nodes, restart MariaDB on the first node.

    kill <mysql PIDs>
    systemctl start mariadb

