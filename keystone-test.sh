# TEST (might require logout/login to reset the environmet that was set before 
# during initial bootstrap)

unset SERVICE_TOKEN
unset SERVICE_ENDPOINT
. /srv/rhos6/configs/keystonerc_user
keystone token-get
. /srv/rhos6/configs/keystonerc_admin
keystone user-list
