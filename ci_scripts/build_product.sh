#!/usr/bin/env bash
test -z "${1}" && exit 199
productsToBuild="${1}"
shift
defaultOS=${1:-alpine}
shift
OSList=${*}

HERE=$(cd $(dirname ${0});pwd)
if test -n "${CI_COMMIT_REF_NAME}" ;then
  . ${CI_PROJECT_DIR}/ci_scripts/ci_tools.lib.sh
else 
  # shellcheck source=~/projects/devops/pingidentity-docker-builds/ci_scripts/ci_tools.lib.sh
  . ${HERE}/ci_tools.lib.sh
fi

# TODO: make it work for local
# usage ()
# {
# cat <<END_USAGE
# Usage: build.sh {options}
#     where {options} include:

#     -p, --product
#         The name of the product for which to build a docker image
#     -o, --os
#         the name of the operating system for which to build a docker image
#     --help
#         Display general usage information
# END_USAGE
# exit 99
# }
    # -v, --version
    #     the version of the product for which to build a docker image
    #     this setting overrides the versions in the version file of the target product
    # --use-cache
    #     use cached layers. useful to avoid re-building unchanged images, notably: pingbase
    # --dry-run
    #     does everything except actually call the docker command and prints it instead
    # --pretty
    #     do not display detailed output

# while ! test -z "${1}" ; do
#     case "${1}" in
#         -o|--os)
#             shift
#             if test -z "${1}" ; then
#                 echo "You must provide an OS"
#                 usage
#             fi
#             OSesToBuild="${1}"
#             ;;

#         -p|--product)
#             shift
#             if test -z "${1}" ; then
#                 echo "You must provide a product to build"
#                 usage
#             fi
#             productsToBuild="${1}"
#             ;;

        # -v|--version)
        #     shift
        #     if test -z "${1}" ; then
        #         echo "You must provide a version to build"
        #         usage
        #     fi
        #     versionsToBuild="${1}"
        #     ;;
        
        # --use-cache)
        #     useCache=" "
        #     ;;
        
        # --dry-run)
        #     dryRun="echo"
        #     ;;

        # --pretty)
        #     pretty="true"
        #     ;;

#         --help)
#             usage
#             ;;
#         *)
#             echo "Unrecognized option"
#             usage
#             ;;
#     esac
#     shift
# done

exitCode=0
for OSToBuild in ${OSList:-alpine centos ubuntu} ; do
    "${HERE}/build_and_tag.sh" "${productsToBuild}" "${defaultOS}" "${OSToBuild}" #"${versionsToBuild}"
    exitCode=${?}
    if test ${exitCode} -ne 0 ; then
        echo "Build break for ${1} on ${OSToBuild}"
        break
    fi
done

history | tail -100

exit ${exitCode}