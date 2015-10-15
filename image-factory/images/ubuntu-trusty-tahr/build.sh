#!/bin/sh

. ../../factory-env.sh

LOG="./build.debug.log"
BASENAME="ubuntu-14.04"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"

IMG=ubuntu-14.04-server-cloudimg-amd64-disk1.img
IMG_URL=http://cloud-images.ubuntu.com/releases/14.04/release/$IMG

TMP_DIR=guest


if [ -f "$IMG" ]; then
    rm $IMG
fi

wget -q $IMG_URL

if [ ! -d "$TMP_DIR" ]; then
    mkdir $TMP_DIR
fi

guestmount -a $IMG -i $TMP_DIR

cp $TMP_DIR/etc/cloud/templates/hosts.debian.tmpl $TMP_DIR/etc/cloud/templates/hosts.tmpl
sed -i "/preserve_hostname/a manage_etc_hosts: true" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s/name: ubuntu/name: cloud/" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s/gecos: Ubuntu/gecos: Cloud user/" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "/ed25519/d" $TMP_DIR/etc/ssh/sshd_config

sed -i "s#LABEL=cloudimg-rootfs#/dev/vda1#" \
    $TMP_DIR/etc/fstab \
    $TMP_DIR/boot/grub/menu.lst \
    $TMP_DIR/boot/grub/grub.cfg

echo "sleep 5" >> $TMP_DIR/etc/init/plymouth-upstart-bridge.conf

sed -i "s/#GRUB_DISABLE_LINUX_UUID/GRUB_DISABLE_LINUX_UUID/" $TMP_DIR/etc/default/grub

guestunmount $TMP_DIR

glance image-create \
       --file $IMG \
       --disk-format qcow2 \
       --container-format bare \
       --name "$TMP_IMG_NAME"

TMP_IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $TMP_IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

packer build -var "source_image=$TMP_IMG_ID" -var "image_name=$IMG_NAME" ../apt-bootstrap.packer.json

echo "======= Deleting temporary image..."

glance image-delete $TMP_IMG_NAME >> $LOG 2>&1

IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

glance image-update --property cw_os=Ubuntu --property cw_origin=Cloudwatt --property hw_rng_model=virtio --min-disk 10 --purge-props $IMG_ID  >> $LOG 2>&1

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"

echo "======= Cleaning unassociated floating ips..."

for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id >> $LOG 2>&1
done

echo "======= Cleaning old images..."

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " |cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs glance image-delete >> $LOG 2>&1

glance image-show $IMG_ID >> $LOG 2>&1

echo "======= Validation testing..."

URCHIN_IMG_ID=$IMG_ID $WORKSPACE/test-tools/urchin $WORKSPACE/test-tools/ubuntu-tests
