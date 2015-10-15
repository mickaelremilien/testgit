#!/bin/sh

. ../../factory-env.sh

BASENAME="Centos-7"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"

IMG=CentOS-7-x86_64-GenericCloud.qcow2
IMG_URL=http://cloud.centos.org/centos/7/images/$IMG

TMP_DIR=centos-guest

if [ -f "$IMG" ]; then
    rm $IMG
fi

wget -q $IMG_URL

if [ ! -d "$TMP_DIR" ]; then
    mkdir $TMP_DIR
fi

guestmount -a $IMG -i $TMP_DIR

sed -i "s/name: centos/name: cloud/" $TMP_DIR/etc/cloud/cloud.cfg

guestunmount $TMP_DIR

glance image-create \
       --file $IMG \
       --disk-format qcow2 \
       --container-format bare \
       --name "$TMP_IMG_NAME"

TMP_IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $TMP_IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

echo "TMP_IMG_ID found for image $TMP_IMG_NAME=$TMP_IMG_ID"

packer build -var "source_image=$TMP_IMG_ID" -var "image_name=$IMG_NAME" ../yum-bootstrap.packer.json

if [ "$?" != "0" ]; then
  echo "Failed to pack image"
  exit 1
fi

glance image-delete $TMP_IMG_ID
IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $IMG_NAME | tr "|" " " | awk '{print $2}')"

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"

echo "======= Cleaning unassociated floating ips"

for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id
done

echo "======= Cleaning too old images"

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " |cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs glance image-delete

glance image-update --property cw_os=centos --property cw_origin=Cloudwatt --property hw_rng_model=virtio --min-disk 10 --purge-props $IMG_ID
glance image-show $IMG_ID

if [ "$?" = "0" ]; then
  URCHIN_IMG_ID=$IMG_ID $WORKSPACE/test-tools/urchin -f "$WORKSPACE/test-tools/ubuntu-tests"
fi
