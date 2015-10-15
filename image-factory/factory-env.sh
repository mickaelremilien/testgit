#!/bin/sh

# This file should be source to make the scripts take all values specific to a factory instance.

# Network ID to use for VM deployment during build
if [ -n `which neutron` ] && [ -n "$OS_TENANT_ID" ]; then
  if [ -n "$FACTORY_NETWORK_ID" ]; then
    export FACTORY_NETWORK=`neutron net-show "$FACTORY_NETWORK_ID" | grep "| name" | cut -d"|" -f3 | tr -d " "`
  fi
  if [ -n "$FACTORY_SECURITY_GROUP_ID" ]; then
    export FACTORY_SECURITY_GROUP=`neutron security-group-show $FACTORY_SECURITY_GROUP_ID | grep "| name" | cut -d"|" -f3 | tr -d " "`
  fi
fi

if [ ! "$FACTORY_NETWORK" ]; then
  export FACTORY_NETWORK="17decd89-56a2-4729-8bd6-453ebaa51860"
fi

if [ ! "$FACTORY_SECURITY_GROUP" ]; then
  export FACTORY_SECURITY_GROUP="FACTORY-sg-zh6nltybm7fy"
fi

# Floating IP pool to use
# packer openstack builder does not interpolate var for ip_pool
# so this value should also be put as-is in place in your packer files.
export FACTORY_FLOATING_IP_POOL="6ea98324-0f14-49f6-97c0-885d1b8dc517"
