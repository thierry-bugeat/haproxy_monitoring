haproxy_monitoring
==================

Haproxy monitoring on Amazon EC2 instances & virtual IP failover.

Source: http://aws.amazon.com/articles/2127188135977316

In this article, the failover works only if the server is down.  
The failover doesn't works if Haproxy service is down.  

**Here, we will monitor Haproxy service 
and take over virtual IP if Haproxy master is down.**

Follow these changes for step 5 & 6 :

5a. Configure SSH connexions between Haproxy nodes
--------------------------------------------------

Copy your pem files on each Haproxy node (Directory : "/root/.ssh/")

Create file "/root/.ssh/config" on each Haproxy node with the following content.

	Host haproxy01
	        User ec2-user
	        Hostname 10.0.0.11
	        IdentityFile ~/.ssh/haproxy01.pem

	Host haproxy02
	        User ec2-user
	        Hostname 10.0.0.12
	        IdentityFile ~/.ssh/haproxy02.pem

Don't forget to change IdentifyFile ("haproxy01.pem" & "haproxy02.pem" in this example) by your own pem filenames.

Try the SSH connection from Haproxy node 1 to node 2

	[ec2-user@ip-10-0-0-11 ~]$ sudo -s
	[root@ip-10-0-0-11 ec2-user]# ssh haproxy02

Try the SSH connection from Haproxy node 2 to node 1

	[ec2-user@ip-10-0-0-12 ~]$ sudo -s
	[root@ip-10-0-0-12 ec2-user]# ssh haproxy01



5b. Download haproxy_monitor.zip archive and configure haproxy_monitor.conf file.
---------------------------------------------------------------------------------

Connect to Haproxy Node #1. Change to the root user, navigate to the root user's home
directory, download and unzip the archive "haproxy_monitor.zip". Make scripts
executables with the following commands:

	[ec2-user@ip-10-0-0-11 ~]$ sudo -s
	[root@ip-10-0-0-11 ec2-user]# cd /root
	[root@ip-10-0-0-11 ~]# wget http://thierry.bugeat.free.fr/misc/haproxy_monitor.zip
	[root@ip-10-0-0-11 ~]# unzip -j haproxy_monitor.zip
	[root@ip-10-0-0-11 ~]# chmod a+x haproxy_monitor.sh
	[root@ip-10-0-0-11 ~]# chmod a+x reassign_vip.sh

Open file "haproxy_monitor.conf" and edit the following variables to match your settings :

	VIP             : This should point to private virtual IP address
                      that will float between the two Haproxy Nodes 
                      (10.0.0.10 in this example).

	REGION          : This should point to region where your Haproxy nodes 
                      are running (us-east-1 in this example).
                      For region value see : 
                      http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region

	AWSAccessKeyId	: See https://console.aws.amazon.com/iam/home?#users
                      Find your user name...
                      click [Create New Access Key]
                      Download "rootkey.csv" file and upload it on each Haproxy node. 
                      (Directory : "/root/")
                      "rootkey.csv" content should look like...
                      AWSAccessKeyId=XXXXXXXXXXXXXX
                      AWSSecretKey=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	AWSSecretKey	: 

	SSH_CONFIG_1	: Ssh hostname to use to contact Haproxy node 1.
	                  (haproxy01 in this example)

	SSH_CONFIG_2	: Ssh hostname to use to contact Haproxy node 2. 
	                  (haproxy02 in this example)

Configure haproxy_monitor.sh to be started by cron at boot and start haproxy_monitor.sh: 

	[root@ip-10-0-0-11 ~]# echo '@reboot /root/haproxy_monitor.sh >> /tmp/haproxy_monitor.log' | crontab
	[root@ip-10-0-0-11 ~]# ./haproxy_monitor.sh >> /tmp/haproxy_monitor.log &
	[root@ip-10-0-0-11 ~]# 

Verify that the script is running by viewing the log file:

	[root@ip-10-0-0-11 ~]# tail /tmp/haproxy_monitor.log 
	Thu Jan 16 13:00:00 UTC 2014 -- Starting Haproxy monitor
	[root@ip-10-0-0-11 ~]#

Now connect to Haproxy Node #2 and issue the same commands as you did previously on Haproxy Node #1.



6. Test Your Configuration
--------------------------

You are done! You may now test your configuration. Watch the haproxy_monitor.log 
file on Haproxy Node #2 while you restart Haproxy Node #1 and observe the script 
take over the VIP.

Haproxy Node #2

    [root@ip-10-0-0-12 ~]# tail -f /tmp/haproxy_monitor.log 
    Fri Jan 17 10:22:47 UTC 2014 -- Starting Haproxy monitor
    Fri Jan 17 10:22:47 UTC 2014 IP node 1 = 10.0.0.11
    Fri Jan 17 10:22:47 UTC 2014 IP node 2 = 10.0.0.12

Now stop Haproxy service on node 1 and observe logs on Haproxy node 2

    Fri Jan 17 10:23:35 UTC 2014 [WARNING] Haproxy node 1 (10.0.0.11) is down.
    Fri Jan 17 10:23:37 UTC 2014 ENI eth0 vip = eni-xxxxxxxx
    Fri Jan 17 10:23:37 UTC 2014 ENI eth0 node 1 = eni-xxxxxxxx
    Fri Jan 17 10:23:37 UTC 2014 ENI eth0 node 2 = eni-xxxxxxxx
    Fri Jan 17 10:23:37 UTC 2014 Master server = 10.0.0.11
    Fri Jan 17 10:23:37 UTC 2014 IP localhost = 10.0.0.12
    Fri Jan 17 10:23:37 UTC 2014 I'm the slave server.
    Fri Jan 17 10:23:37 UTC 2014 [WARNING] Haproxy on master server 10.0.0.11 is down !
    Fri Jan 17 10:23:37 UTC 2014 [-------] Haproxy on slave server is up.
    Fri Jan 17 10:23:37 UTC 2014
    Fri Jan 17 10:23:37 UTC 2014 ########################
    Fri Jan 17 10:23:37 UTC 2014 ### EXECUTE FAILOVER ###
    Fri Jan 17 10:23:37 UTC 2014 ########################
    Fri Jan 17 10:23:37 UTC 2014
    Fri Jan 17 10:23:37 UTC 2014 Haproxy node IP = 10.0.0.12
    Fri Jan 17 10:23:39 UTC 2014 Network interface ID = eni-xxxxxxxx
    RETURN  true
    Fri Jan 17 10:23:41 UTC 2014 Reassign virtual IP done.
    Fri Jan 17 10:23:41 UTC 2014 Failover done.
    Fri Jan 17 10:23:41 UTC 2014

Now restart Haproxy on node 1. 

    Fri Jan 17 10:32:38 UTC 2014 [NOTICE] Come back to stability. All is done.



7. How to install Amazon EC2 API tools on Debian Wheezy 7.3 instance
--------------------------------------------------------------------

Quick example  

	[admin@ip-10-0-0-11 ~]$ sudo -s
	[root@ip-10-0-0-11 admin]# cd /root
    [root@ip-10-0-0-11 ~] wget http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
    [root@ip-10-0-0-11 ~] unzip ec2-api-tools.zip -d /opt && mv /opt/ec2-api-tools* /opt/aws
    [root@ip-10-0-0-11 ~] apt-get install openjdk-7-jre
    [root@ip-10-0-0-11 ~] export EC2_HOME=/opt/aws/
    [root@ip-10-0-0-11 ~] export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/

Export variables at instance startup

    [root@ip-10-0-0-11 ~] echo "export EC2_HOME=/opt/aws/" >> /etc/profile.d/aws.sh
    [root@ip-10-0-0-11 ~] echo "export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/" >> /etc/profile.d/aws.sh
