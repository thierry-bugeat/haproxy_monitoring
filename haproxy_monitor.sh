#!/bin/sh
# This script will monitor Haproxy nodes and take over a Virtual IP (VIP)

source `pwd`/haproxy_monitor.conf

# ---

FAILOVER_SCRIPT="reassign_vip.sh" # Script executed to reassign virtual ip.
SSH_TIMEOUT="-o ConnectTimeout=1"

IP_NODE_1=`ssh $SSH_TIMEOUT $SSH_CONFIG_1 /sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://'`
IP_NODE_2=`ssh $SSH_TIMEOUT $SSH_CONFIG_2 /sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://'`

echo `date` "-- Starting Haproxy monitor"

echo `date` "IP node 1 = $IP_NODE_1"
echo `date` "IP node 2 = $IP_NODE_2"

while [ . ]; do

	HAPROXY_PID_NODE_1=`ssh $SSH_TIMEOUT $SSH_CONFIG_1 "ps cax | grep haproxy" | awk '{print $1;}'`
	HAPROXY_PID_NODE_2=`ssh $SSH_TIMEOUT $SSH_CONFIG_2 "ps cax | grep haproxy" | awk '{print $1;}'`

	echo `date` "Haproxy PID node 1 = $HAPROXY_PID_NODE_1"
	echo `date` "Haproxy PID node 2 = $HAPROXY_PID_NODE_2"

	# ========================================
	# --- All Haproxy instances are down ? ---
	# ========================================

	if [ "$HAPROXY_PID_NODE_1" == "" ] && [ "$HAPROXY_PID_NODE_2" == "" ]
        then
                echo `date` "                 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!                 "
                echo `date` "### CRITICAL ### !!! ALL HAPROXY INSTANCES ARE DOWN !!! ### CRITICAL ###"
                echo `date` "                 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!                 "

	# ======================================
	# --- One Haproxy instance is down ? ---
	# ======================================

	elif [ "$HAPROXY_PID_NODE_1" == "" ] || [ "$HAPROXY_PID_NODE_2" == "" ]
	then
		echo `date` "[WARNING] One Haproxy instance is down !"

		if [ "$HAPROXY_PID_NODE_1" == "" ]
		then
			echo `date` "$IP_NODE_1 haproxy[]: WARNING Service node 1 down"
		fi

		if [ "$HAPROXY_PID_NODE_2" == "" ]
		then
			echo `date` "$IP_NODE_2 haproxy[]: WARNING Service node 2 down"
		fi

		# ==================================
		# --- Who is the master server ? ---
		# ==================================

		OLDIFS=$IFS
		IFS=$'\n'

		for line in `ec2-describe-addresses --aws-access-key $AWSAccessKeyId --aws-secret-key $AWSSecretKey`
		do
      			ENI=`echo $line | awk '{print $7;}'`
        		IP=`echo $line | awk '{print $8;}'`

        		case $IP in
                		$VIP)
                     			ENI_NODE_0=$ENI
                        		;;
                		$IP_NODE_1)
                        		ENI_NODE_1=$ENI
                        		;;
                		$IP_NODE_2)
                        		ENI_NODE_2=$ENI
                        		;;
                		*)
			esac
		done

		IFS=$OLDIFS

		echo `date` "ENI eth0 vip = $ENI_NODE_0"
    		echo `date` "ENI eth0 node 1 = $ENI_NODE_1"
    		echo `date` "ENI eth0 node 2 = $ENI_NODE_2"

		if [ "$ENI_NODE_0" == "$ENI_NODE_1" ]
		then
			MASTER=$IP_NODE_1
			HAPROXY_PID_MASTER=$HAPROXY_PID_NODE_1
			HAPROXY_PID_SLAVE=$HAPROXY_PID_NODE_2
		elif [ "$ENI_NODE_0" == "$ENI_NODE_2" ]
		then
			MASTER=$IP_NODE_2
			HAPROXY_PID_MASTER=$HAPROXY_PID_NODE_2
			HAPROXY_PID_SLAVE=$HAPROXY_PID_NODE_1
		else
			MASTER=""
			HAPROXY_PID_MASTER=""
			HAPROXY_PID_SLAVE=""
		fi

		echo `date` "Master server = $MASTER"

		# =============================
		# --- I'm slave or master ? ---
		# =============================

		IP_LOCALHOST=`/sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://'`	
		echo `date` "IP localhost = $IP_LOCALHOST"

		if [ "$MASTER" == "$IP_LOCALHOST" ]
		then
			MY_STATUS="master"
			echo `date` "I'm the master server."
		else
			MY_STATUS="slave"
			echo `date` "I'm the slave server."
		fi

		# ==========================
		# --- Execute failover ? ---
		# ==========================
		# Failover if :
		# 1) Master Haproxy is down
		# 2) Slave Haproxy is up
		# 3) This server is the slave

		if [ "$HAPROXY_PID_MASTER" == "" ] && [ "$HAPROXY_PID_SLAVE" != "" ] && [ "$MY_STATUS" == "slave" ]
		then
			echo `date` "[WARNING] Haproxy on master server $MASTER is down !"
			echo `date` "[-------] Haproxy on slave server is up."
			echo `date`
			echo `date` "########################"
			echo `date` "### EXECUTE FAILOVER ###"
			echo `date` "########################"
			echo `date`

			source `pwd`/$FAILOVER_SCRIPT

			echo `date` "Failover done."
			echo `date`
		elif [ "$HAPROXY_PID_MASTER" != "" ] && [ "$HAPROXY_PID_SLAVE" == "" ]
		then
			echo `date` "[WARNING] Haproxy on slave server is down!"
		else
			echo `date` "### CRITICAL ###"
		fi
	
	fi

	sleep $CHECK_EVERY

done
