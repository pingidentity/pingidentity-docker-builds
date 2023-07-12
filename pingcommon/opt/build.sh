#!/usr/bin/env sh
test -f "/opt/build.sh.pre" && sh /opt/build.sh.pre

/opt/install_deps.sh

# Update file permissions for the BASE for the default container user,
# and update the /var/lib/nginx owner if necessary.
fixPermissions() {
    test -f /etc/motd || touch /etc/motd
    chmod go+w /etc/motd

    chown -Rf 9031:0 /etc/motd

    # Environment variables for BASE isn't available here.
    BASE=/opt

    #fix permissions to ping user and root group. Removes permissions from others
    chown -Rf 9031:0 "${BASE}"
    chmod -Rf o-rwx "${BASE}"

    # make shell scripts executable for the user
    # this is safe to do "blind" as it only affects files with the .sh extension
    # for the user defined in the image
    find "${BASE}" -type f -iname \*.sh -exec chmod u+x '{}' \+

    #fix group permissions from owner
    chmod -Rf g=u "${BASE}"

    if grep ^nginx: /etc/passwd > /dev/null; then
        # rebase ownerships for nginx to ping user and root group
        find / -xdev -not -path "/sys/*" -not -path "/proc/*" -not -path "/dev/*" -user nginx -exec chown 9031 {} +
        find / -xdev -not -path "/sys/*" -not -path "/proc/*" -not -path "/dev/*" -group nginx -exec chgrp 0 {} +
    fi
}

# create stubs for volume mounts
for dir in "backup" "in" "logs" "out"; do
    mkdir "/opt/${dir}"
done

# Do we need this ?
# chmod -Rf a+rwx /opt

# Remove get-product-bits.sh. It is not needed at runtime.
rm -f "/opt/get-product-bits.sh"

test -f "/opt/build.sh.post" && sh /opt/build.sh.post

# generate the staging manifest
find "/opt/staging" > "/opt/staging-manifest.txt"

fixPermissions

# delete self
rm -f "${0}"
set +x
echo "Build done."

exit 0
