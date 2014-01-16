#!/bin/sh
# This script reassign Amazon Elastic IP (Virtual IP) to this server.

# =================
# --- Variables ---
# =================

source `pwd`/haproxy_monitor.conf

# ---

HAPROXY_NODE_IP=`/sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://'`

echo `date` "Haproxy node IP = $HAPROXY_NODE_IP"

# ============================
# --- Network Interface ID ---
# ============================

NETWORK_INTERFACE_ID=`/opt/aws/bin/ec2-describe-addresses --aws-access-key $AWSAccessKeyId --aws-secret-key $AWSSecretKey --region $REGION | grep $HAPROXY_NODE_IP | awk '{print $7;}'`

echo `date` "Network interface ID = $NETWORK_INTERFACE_ID"

# ==========================================
# --- Reassign Virtual IP to this server ---
# ==========================================

ec2-assign-private-ip-addresses -n $NETWORK_INTERFACE_ID --secondary-private-ip-address $VIP --allow-reassignment --aws-access-key $AWSAccessKeyId --aws-secret-key $AWSSecretKey --region $REGION

echo `date` "Reassign virtual IP done."
