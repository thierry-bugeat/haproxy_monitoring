#!/bin/sh
# This script will monitor Haproxy nodes and take over a Virtual IP (VIP)

source `pwd`/haproxy_monitor.conf

# ---

FAILOVER_SCRIPT="reassign_vip.sh" # Script executed to reassign virtual ip.
SSH_TIMEOUT="-o ConnectTimeout=1"

SYSTEM_STABLE="yes"

IP_NODE_1=`ssh $SSH_TIMEOUT $SSH_CONFIG_1 /sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://'`
IP_NODE_2=`ssh $SSH_TIMEOUT $SSH_CONFIG_2 /sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://'`

echo `date` "-- Starting Haproxy monitor"

echo `date` "IP node 1 = $IP_NODE_1"
echo `date` "IP node 2 = $IP_NODE_2"

while [ . ]; do

    HAPROXY_PID_NODE_1=`ssh $SSH_TIMEOUT $SSH_CONFIG_1 "ps cax | grep haproxy$" | awk '{print $1;}'`
    HAPROXY_PID_NODE_2=`ssh $SSH_TIMEOUT $SSH_CONFIG_2 "ps cax | grep haproxy$" | awk '{print $1;}'`

    # ==============================
    # --- Come back to stability ---
    # ==============================

    if [ "$SYSTEM_STABLE" == "no" ] && [ "$HAPROXY_PID_NODE_1" != "" ] && [ "$HAPROXY_PID_NODE_2" != "" ]
    then
        SYSTEM_STABLE="yes"
        echo `date` "[NOTICE] Come back to stability. All is done."
    fi

    # ========================================
    # --- All Haproxy instances are down ? ---
    # ========================================

    if [ "$HAPROXY_PID_NODE_1" == "" ] && [ "$HAPROXY_PID_NODE_2" == "" ]
    then
        SYSTEM_STABLE="no"

        echo `date` "                 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!                 "
        echo `date` "### CRITICAL ### !!! ALL HAPROXY INSTANCES ARE DOWN !!! ### CRITICAL ###"
        echo `date` "                 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!                 "

    # ======================================
    # --- One Haproxy instance is down ? ---
    # ======================================

    elif [ "$HAPROXY_PID_NODE_1" == "" ] || [ "$HAPROXY_PID_NODE_2" == "" ]
    then

        SYSTEM_STABLE="no"

        if [ "$HAPROXY_PID_NODE_1" == "" ]
        then
            echo `date` "[WARNING] Haproxy node 1 ($IP_NODE_1) is down."
        fi

        if [ "$HAPROXY_PID_NODE_2" == "" ]
        then
            echo `date` "[WARNING] Haproxy node 2 ($IP_NODE_2) is down."
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

        # =============================
        # --- I'm slave or master ? ---
        # =============================

        IP_LOCALHOST=`/sbin/ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://'`	
        echo `date` "Master $MASTER / Localhost $IP_LOCALHOST"

        if [ "$MASTER" == "$IP_LOCALHOST" ]
        then
            MY_STATUS="master"
        else
            MY_STATUS="slave"
        fi

        # ==========================
        # --- Execute failover ? ---
        # ==========================
        # Failover if :
        # 1) Master Haproxy is down
        # 2) Slave Haproxy is up
        # 3) This server is the slave

        if [ "$MY_STATUS" == "master" ]
        then
            echo `date` "I'm master. Nothing to do."
        elif [ "$MY_STATUS" == "slave" ] && [ "$HAPROXY_PID_MASTER" != "" ]
        then
            echo `date` "I'm slave & master is up. Nothing to do."
        elif [ "$MY_STATUS" == "slave" ] && [ "$HAPROXY_PID_MASTER" == "" ] && [ "$HAPROXY_PID_SLAVE" != "" ]
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
        else
            echo `date` "### CRITICAL ###"
        fi

    fi

    sleep $CHECK_EVERY

done
