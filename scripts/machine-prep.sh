#!/bin/bash
echo $(date) " - Starting Machine Prep Script"

export USERNAME_ORG=$1
export PASSWORD_ACT_KEY="$2"
export POOL_ID=$3
#export MINORVERSION=${15}

# Remove RHUI
rm -f /etc/yum.repos.d/rh-cloud.repo
sleep 10

# Register Host with Cloud Access Subscription
echo $(date) " - Register host with Cloud Access Subscription"

subscription-manager register --force --username="$USERNAME_ORG" --password="$PASSWORD_ACT_KEY" || subscription-manager register --force --activationkey="$PASSWORD_ACT_KEY" --org="$USERNAME_ORG"
RETCODE=$?

if [ $RETCODE -eq 0 ]
then
    echo "Subscribed successfully"
elif [ $RETCODE -eq 64 ]
then
    echo "This system is already registered."
else
    echo "Incorrect Username / Password or Organization ID / Activation Key specified"
    exit 3
fi

subscription-manager attach --pool=$POOL_ID > attach.log
if [ $? -eq 0 ]
then
    echo "Pool attached successfully"
else
    grep attached attach.log
    if [ $? -eq 0 ]
    then
        echo "Pool $POOL_ID was already attached and was not attached again."
    else
        echo "Incorrect Pool ID or no entitlements available"
        exit 4
    fi
fi

# Disable all repositories and enable only the required ones
echo $(date) " - Disabling all repositories and enabling only the required repos"

subscription-manager repos --disable="*"

subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.11-rpms" \
    --enable="rhel-7-server-ansible-2.6-rpms"

# Update system to latest packages
echo $(date) " - Update system to latest packages"
yum -y update
echo $(date) " - System update complete"

# Install base packages and update system to latest packages
echo $(date) " - Install base packages"
yum -y install vim wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools kexec-tools sos psacct ansible
echo $(date) " - Base package installation complete"

# Install OpenShift utilities
echo $(date) " - Installing OpenShift utilities"
yum -y install openshift-ansible #-3.11.${MINORVERSION}
echo $(date) " - OpenShift utilities installation complete"


# Grow Root File System
#echo $(date) " - Grow Root FS"

#rootdev=`findmnt --target / -o SOURCE -n`
#rootdrivename=`lsblk -no pkname $rootdev`
#rootdrive="/dev/"$rootdrivename
#name=`lsblk  $rootdev -o NAME | tail -1`
#part_number=${name#*${rootdrivename}}

#growpart $rootdrive $part_number -u on
#xfs_growfs $rootdev

#if [ $? -eq 0 ]
#then
#    echo "Root partition expanded"
#else
#    echo "Root partition failed to expand"
#    exit 6
#fi

# Install Docker
echo $(date) " - Installing Docker"
yum -y install docker 

# Update docker config for insecure registry
echo "
# Adding insecure-registry option required by OpenShift
OPTIONS=\"\$OPTIONS --insecure-registry 172.30.0.0/16\"
" >> /etc/sysconfig/docker

# Create thin pool logical volume for Docker
echo $(date) " - Creating thin pool logical volume for Docker and staring service"

#DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 )

#echo "
# Adding OpenShift data disk for docker
#DEVS=${DOCKERVG}
#VG=docker-vg
#" >> /etc/sysconfig/docker-storage-setup

# Running setup for docker storage
#docker-storage-setup
#if [ $? -eq 0 ]
#then
#   echo "Docker thin pool logical volume created successfully"
#else
#   echo "Error creating logical volume for Docker"
#   exit 5
#fi

# Enable and start Docker services

systemctl enable docker
systemctl start docker

echo $(date) " - Script Complete"