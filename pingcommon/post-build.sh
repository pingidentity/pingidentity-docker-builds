#!/usr/bin/env sh
# it is necessary to make the message of the day writable for the user
# so that the motd facility can work with:
#   - inside-out permissions (when stepped down via gosu or any setuid for that matter)
#   - with outside-in security context
#       - when -u|--user is provided to docker
#       - when security context block is defined in k8s configmap
chmod go+w /etc/motd

# create the mounts
for dir in backup in logs out ; do
    mkdir /opt/${dir}
    # this file allows us to know if the path has been bound to the host or not
    touch /opt/${dir}/.ephemeral
done

chmod -R +rwx /opt/backup /opt/in /opt/logs /opt/out    

# give each file the same permission for others as for the user
chmod -R o=u /opt
rm -f ${0}