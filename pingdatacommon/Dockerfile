FROM pingidentity/pingcommon
COPY ["_script-util.sh", "/opt/server/lib/"]
COPY ["configure-tools.sh","/opt/"]
COPY [ "18-setup-sequence.sh", "181-check-license.sh","184-generate-topology-descriptor.sh","185-apply-tools-properties.sh","186-install-extensions.sh", "188-apply-configuration.sh", "/opt/staging/hooks/" ]