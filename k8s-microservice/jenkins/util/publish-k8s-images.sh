#!/bin/bash -ex

# This script is passed a PRODUCT, an INTERNAL_TAG, a PUBLIC_TAG, an
# OPENSHIFT_BUILD number, and a true/false value LATEST.
# It presumes that the following images are available:
#    build-docker.couchbase.com/cb-vanilla/${short_product}:${INTERNAL_TAG}
#    build-docker.couchbase.com/cb-rhcc/${short_product}:${INTERNAL_TAG}
# where short_product is PRODUCT with the leading "couchbase-" removed.
# Those images will be copied from the source registry to their destinations
# on Docker Hub and RHCC - for RHCC it will also append the OPENSHIFT_BUILD
# number to the public tag.
# On both Docker Hub and RHCC it will also create the redundant -dockerhub
# and -rhcc tags.
# If LATEST=true it will also update the :latest tag.

PRODUCT=$1
INTERNAL_TAG=$2
PUBLIC_TAG=$3
OPENSHIFT_BUILD=$4
LATEST=$5

internal_repo=build-docker.couchbase.com

script_dir=$(dirname $(readlink -e -- "${BASH_SOURCE}"))
build_tools_dir=$(cd "${script_dir}" && git rev-parse --show-toplevel)
source ${build_tools_dir}/utilities/shell-utils.sh
source ${script_dir}/funclib.sh

chk_set PRODUCT
chk_set INTERNAL_TAG
chk_set PUBLIC_TAG
chk_set OPENSHIFT_BUILD
chk_set LATEST

short_product=${PRODUCT/couchbase-/}

vanilla_registry=index.docker.io

# Uncomment when doing local testing
#vanilla_registry=build-docker.couchbase.com

#
# Publish to public registries, including redundant tags
#

################ VANILLA

status Publishing to Docker Hub...
internal_image=${internal_repo}/cb-vanilla/${short_product}:${INTERNAL_TAG}
external_base=${vanilla_registry}/couchbase/${short_product}
images=(${external_base}:${PUBLIC_TAG} ${external_base}:${PUBLIC_TAG}-dockerhub)
if ${LATEST}; then
    images+=(${external_base}:latest)
fi
for image in ${images[@]}; do
    echo @@@@@@@@@@@@@
    echo Copying ${internal_image} to ${image}...
    echo @@@@@@@@@@@@@
    skopeo copy --authfile ${HOME}/.docker/config.json --all \
        docker://${internal_image} docker://${image}
done

################## RHCC

# There is no RHEL build for some products
if product_in_rhcc "${PRODUCT}"; then
    if ${LATEST}; then
        EXTRA_ARG="-r latest"
    fi
    ${build_tools_dir}/rhcc/rhcc-certify-and-publish.sh -s -b \
        -c ${HOME}/.docker/rhcc-metadata.json \
        -p ${PRODUCT} -t ${INTERNAL_TAG} \
        -r ${PUBLIC_TAG} -r ${PUBLIC_TAG}-${OPENSHIFT_BUILD} \
        -r ${PUBLIC_TAG}-rhcc ${EXTRA_ARG}
fi
