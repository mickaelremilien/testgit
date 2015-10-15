#!/bin/sh

. ../../factory-env.sh

BASENAME="debian-jessie"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"

IMG=debian-8.1.0-openstack-amd64.qcow2
IMG_URL=http://cdimage.debian.org/cdimage/openstack/current/$IMG

TMP_DIR=debian-jessie-guest

if [ -f "$IMG" ]; then
    rm $IMG
fi

wget -q $IMG_URL

if [ ! -d "$TMP_DIR" ]; then
    mkdir $TMP_DIR
fi

guestmount -a $IMG -i $TMP_DIR

sed -i "s#name: debian#name: cloud#" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#gecos: Debian#gecos: Cloud user#" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#debian#cloud#" $TMP_DIR/etc/sudoers.d/debian-cloud-init
sed -i "/ed25519/d" $TMP_DIR/etc/ssh/sshd_config
sed -i "/gecos/a \ \ \ \ \ shell: \/bin\/bash" $TMP_DIR/etc/cloud/cloud.cfg

guestunmount $TMP_DIR

glance image-create \
       --file $IMG \
       --disk-format qcow2 \
       --container-format bare \
       --name "$TMP_IMG_NAME"

TMP_IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $TMP_IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

packer build -var "source_image=$TMP_IMG_ID" -var "image_name=$IMG_NAME" ../apt-bootstrap.packer.json

glance image-delete $TMP_IMG_NAME

IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

glance image-update --property cw_os=Debian --property cw_origin=Cloudwatt --property hw_rng_model=virtio --min-disk 10 --purge-props $IMG_ID

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"

echo "======= Cleaning unassociated floating ips"

for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id
done

echo "======= Cleaning too old images"

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " |cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs glance image-delete


glance image-show $IMG_ID

URCHIN_IMG_ID=$IMG_ID $WORKSPACE/test-tools/urchin -f "$WORKSPACE/test-tools/ubuntu-tests"
