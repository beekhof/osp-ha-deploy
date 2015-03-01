. /srv/rhos6/configs/keystonerc_admin
for m in storage.objects image network volume instance ; do ceilometer sample-list -m $m | tail -2 ; done
