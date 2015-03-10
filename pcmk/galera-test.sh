clustercheck

# verify sync is done
mysql
SHOW STATUS LIKE 'wsrep%';
quit
