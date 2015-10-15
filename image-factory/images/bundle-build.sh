#!/bin/sh

USAGE="\
bundle-build.sh BUNDLE-LABEL CLOUDWATT-BUNDLE-ID BUNDLE-PATH [BUNDLE-SRC-IMG BUNDLE-IMG-OS]

BUNDLE-PATH is relative to bundle-build.sh"

BASENAME=$1
CW_BUNDLE_ID=$2
BUNDLE_PATH=$3
SRC_IMG=$4
IMG_OS=$5

if [ ! "$BASENAME" ]; then
    echo "BUNDLE-LABEL parameter is mandatory"
    echo "$USAGE"
    exit 1
fi

if [ ! "$CW_BUNDLE_ID" ]; then
    echo "CLOUDWATT-BUNDLE-ID parameter is mandatory"
    echo "$USAGE"
    exit 1
fi

if [ ! "$BUNDLE_PATH" ]; then
    echo "BUNDLE-PATH parameter is mandatory"
    echo "$USAGE"
    exit 1
fi

if [ ! "$SRC_IMG" ]; then
    echo "BUNDLE-SRC-IMG parameter is mandatory"
    echo "$USAGE"
    exit 1
fi

if [ ! "$IMG_OS" ]; then
    echo "BUNDLE-IMG-OS parameter is mandatory"
    echo "$USAGE"
    exit 1
fi

if [ ! "$OS_TENANT_ID" ]; then
    echo "OS_TENANT_ID env variable is mandatory"
    exit 1
fi

SELF_PATH=`dirname "$0"`

BUNDLE_PATH="$SELF_PATH/$BUNDLE_PATH"

FACTORY_ENV="$SELF_PATH/../factory-env.sh"
. $FACTORY_ENV

if [ "$?" -ne "0" ]; then
    echo "Could not source factory environment: $FACTORY_ENV"
    exit 1
fi

PACKER_FILE="$SELF_PATH/bundle-bootstrap.packer.json"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"

echo "======= Packer provisionning..."

packer build -var "source_image=$SRC_IMG" -var "image_name=$IMG_NAME" $PACKER_FILE

echo "======= Glance upload..."

IMG_ID="$(glance image-list --owner $OS_TENANT_ID --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"
glance image-update \
    --property cw_bundle=$CW_BUNDLE_ID \
    --property cw_os=$IMG_OS \
    --property cw_origin=Cloudwatt \
    --property hw_rng_model=virtio \
    --min-disk 10 \
    --purge-props $IMG_ID

echo "======= Pruning unassociated floating ips"

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"
for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id
done

echo "======= Deleting deprecated images"

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " | cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs -r glance image-delete

echo "======= Generating Heat Orchestration Template"

if [ ! -d "$BUNDLE_PATH/target" ]; then
    mkdir $BUNDLE_PATH/target
fi
sed "s/\\\$IMAGE\\\$/$IMG_ID/g" $BUNDLE_PATH/heat/$BASENAME.heat.yml > $BUNDLE_PATH/target/$BASENAME.heat.yml

echo "======= Image detail"

glance image-show $IMG_ID
