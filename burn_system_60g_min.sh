#!/bin/sh

TOPDIR=$(pwd)

install_to_cf=
install_type=
system_version=1.7
build_time=$(date +"%Y-%m-%d %H:%M:%S")  # 2014-03-14 13:43:43

ISSUE_MAJOR_VERSION=$(cat /etc/issue|head -n 1 |awk '{printf $3}'|awk -F '.' '{printf $1}')
ISSUE_MINOR_VERSION=$(cat /etc/issue|head -n 1 |awk '{printf $3}'|awk -F '.' '{printf $2}')

Usage=$(echo "Usage: burn_system_60g.sh [Options...] do all things with none arguments \n"\
       "Options:\n"\
       "-a|--auto auto install\n" \
       "-s|--sample sample install\n" \
       "-d|--device install to other device\n" \
       "-h|--help show the Usage\n" \
       "            " );

while [ "$1" != "${1##[-+]}" ]; do
    case $1 in
        -d|--device)
            install_to_cf="-d"
            shift
            ;;
        -a|--auto)
            install_type="-a"
            shift
            ;;
        -v)
            system_version=$2
            shift 2
            ;;
        -s|--sample)
            install_type="-s"
            shift
            ;;
        -h) echo ${Usage}
            exit 1
            ;;
        --help) echo ${Usage}
            exit 1
            ;;
        *) echo ${Usage}
            exit 1
            ;;
    esac
done

# check cur system version
[ -z $system_version ] && { echo "no system version !"; echo "Options: -v 1.0"; exit 1; }

find . -name "*.svn" | xargs rm -rf

# del tmp file ...
[ -d "./burn_tmp" ] && { echo "del tmp ./burn_tmp"; rm -rf ./burn_tmp; }
[ -d "./update/tmp" ] && { echo "del tmp ./update/tmp"; rm -rf ./update/tmp; }


# ======= use yum-repo.vmediax.com rpm source ==========
[ -f "/etc/yum.repos.d/CentOS-Base.repo" ] && {
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
}
cp ./update/data/VMediaX.repo /etc/yum.repos.d/

# sovle the problem 'Cannot set LC_CTYPE to default locale: No such file or directory'
rpm -q glibc-common
[ "$?" != "0" ] && { echo "no glibc-common, try to reinstall it ..."; yum -y install glibc-common; }
echo "aleady installed glibc-common, we reinstall it ..."
yum -y reinstall glibc-common

if [ "$install_type" != "-s" ];then
    echo "run basesystem_update_60g.sh -c"
    sh ./update/basesystem_update_60g.sh -c
fi

### install software and library {} needed

# check yum is ok ?
# yum -y update
# [ "$?" != "0" ] && { echo "yum error, script try to quit ..."; exit 1; }

rpm -q chkconfig
if [ "$?" != "0" ]; then
    yum -y install chkconfig
fi

#install Mysql
rpm -q mysql
if [ $? != 0 ];then
    #yum groupinstall 'MySQL Database' -y

    #sed -i 's#\(datadir=.*\)#datadir=/mnt/writable/mysql#' /etc/my.cnf
    #sed -i 's#\(log-error=.*\)#\#log-error=/opt/system/log/mysqld.log#' /etc/my.cnf
    if [ "$ISSUE_MAJOR_VERSION" == "5" ]; then
        yum install mysql-5.0.95-5.el5_9 -y  #mysql-5.1.69-1.el6_4
        yum install mysql-server-5.0.95-5.el5_9 -y #mysql-server-5.1.69-1.el6_4
    elif [ "$ISSUE_MAJOR_VERSION" == "6" ]; then
        yum install mysql -y
        yum install mysql-server -y
    fi

    chkconfig --add mysqld            # cancel by diwen
    chkconfig --levels 123456 mysqld off
fi

rpm -q gdb
if [ $? != 0 ];then
    yum install gdb.x86_64 -y
fi

# install some libs nessary, by diwen                   # cancel by diwen
# yum -y install libstdc++.i686       # is special
# [ "$?" != "0" ] && { yum -y install libstdc++.i686 --setopt=protected_multilib=false; }

# yum -y install bzip2-libs.i686 openssl.i686 glibc.i686 zlib.i686          # disabled by diwen
# yum -y install expat.i686 libX11-common.noarch

rpm -q sendmail
[ "$?" != "0" ] && { echo "no sendmail, try to install it ..."; yum -y install sendmail; }
rpm -q lvm2
[ "$?" != "0" ] && { echo "no lvm2, try to install it ..."; yum -y install lvm2; }
rpm -q nfs-utils
[ "$?" != "0" ] && { echo "no nfs-utils, try to install it ..."; yum -y install nfs-utils; }

# install snmp software
rpm -q net-snmp
[ "$?" != "0" ] && { echo "no net-snmp, try to install it ..."; yum -y install net-snmp; }

# check X11 lib
rpm -q xorg-x11-server-utils
[ "$?" != "0" ] && { echo "no xorg-x11-server-utils, install it ..."; \
                        yum -y install xorg-x11-server-utils; }

# check xfs tool
rpm -q xfsprogs
[ "$?" != "0" ] && { echo "no xfsprogs XFS utils, install it ..."; \
                        yum -y install xfsprogs xfsprogs-devel; }

# check disk info tool, smartmontools.x86_64 rpm
rpm -q smartmontools
[ "$?" != "0" ] && {
    echo "not find smartmontools, install it ..."
    yum -y install smartmontools
}

# check samba cifs mount utils
rpm -q cifs-utils
[ "$?" != "0" ] && {
    yum -y cifs-utils
}


#startup
/sbin/chkconfig --level 123456 sendmail off
/sbin/chkconfig --level 123456 lvm2-monitor off
/sbin/chkconfig --level 123456 auditd off
# /sbin/chkconfig --level 123456 bluetooth off
/sbin/chkconfig --level 123456 crond off
/sbin/chkconfig --level 123456 ip6tables off
/sbin/chkconfig --level 123456 snmpd on  # new added, by diwen

# solve the NFS problem when system startup, by diwen
# Then make sure your services are all started.
# nfs(both server & client), rpcbind(server), rpcsvcgssd(server), rpcgssd(client), rpcidmapd(both)
/sbin/chkconfig --level 123456 nfs on
/sbin/chkconfig --level 123456 nfslock on
/sbin/chkconfig --level 123456 rpcbind on
/sbin/chkconfig --level 123456 rpcgssd on
/sbin/chkconfig --level 123456 rpcidmapd on
/sbin/chkconfig --level 123456 rpcsvcgssd on


### burn basesystem
if [ "$install_type" == "-s" ];then
    sh ./update/simple_update.sh
    #sed -i "s/^\(check_version_and_system_info.*\)/#check_version_and_system_info/" $ROOT_PATH/etc/rc.update
    sed -i "s/^\(deal_mtab.*\)/#deal_mtab/" $ROOT_PATH/etc/rc.update
else
    sh ./update/basesystem_update_60g.sh ${install_to_cf} ${install_type}
fi

### cp or modify for {}

ROOT_PATH=
if [ "$install_to_cf" == "-d" ];then
    ROOT_PATH=$(df | grep update/tmp/root | head -n 1 | awk '{print $6}')
    if [ -z "$ROOT_PATH" ];then
        echo "can't found root path!"
        exit 0
    fi
fi

SYSTEM_PATH=/opt/system
if [ "$install_to_cf" == "-d" ];then
    SYSTEM_PATH=$(df | grep update/tmp/system | awk '{print $6}')
fi

echo "===========  Checking PATH ==========="
echo "ROOT_PATH   => $ROOT_PATH"
echo "SYSTEM_PATH => $SYSTEM_PATH"
sleep 2


# add auto parted the scsi disk for rss el6, by diwen
cp ./update/data/rc.auto_parted_disk $ROOT_PATH/etc
chmod 777 $ROOT_PATH/etc/rc.auto_parted_disk

grep -q rc.auto_parted_disk $ROOT_PATH/etc/rc.local
if [ $? != 0 ];then
    echo "bash /etc/rc.auto_parted_disk" >> $ROOT_PATH/etc/rc.local
fi

# add rc.update auto startup script
cp ./update/data/rc.update $ROOT_PATH/etc
chmod 777 $ROOT_PATH/etc/rc.update

grep -q rc.update $ROOT_PATH/etc/rc.local
if [ $? != 0 ];then
    echo "bash /etc/rc.update" >> $ROOT_PATH/etc/rc.local
fi


#sshd
grep -q "Port 22222" /etc/ssh/sshd_config
if [ $? != 0 ];then
    sed -i "s/\(#Port.*\)/Port 22222/" $ROOT_PATH/etc/ssh/sshd_config
fi

# sudo                                               # disabled by diwen
# cp -ar ./burn_data/sudoers $ROOT_PATH/etc/sudoers
# chmod 440 $ROOT_PATH/etc/sudoers

# java
grep -q java/jre $ROOT_PATH/etc/profile
if [ $? != 0 ];then
    echo -e "PATH=/opt/program/bin/java/jre/bin:/sbin:/usr/sbin:\$PATH \nexport PATH\n" >> $ROOT_PATH/etc/profile
fi

# hosts config file
# cp -ar $ROOT_PATH/etc/hosts $SYSTEM_PATH/etc/hosts
echo -e "####\n" > $SYSTEM_PATH/etc/hosts
echo -e "127.0.0.1               localhost.localdomain localhost" >> $SYSTEM_PATH/etc/hosts
echo -e "127.0.0.1               localhost.domain localhost" >> $SYSTEM_PATH/etc/hosts
echo -e "127.0.0.1               mmap6.domain mmap6" >> $SYSTEM_PATH/etc/hosts
echo -e "::1                 localhost6.localdomain6 localhost6" >> $SYSTEM_PATH/etc/hosts

if [ "$install_type" == "-s" ];then
    echo -e "####\n" > $ROOT_PATH/etc/hosts
    echo -e "127.0.0.1               localhost.localdomain localhost" >> $ROOT_PATH/etc/hosts
    echo -e "127.0.0.1               localhost.domain localhost" >> $ROOT_PATH/etc/hosts
    echo -e "127.0.0.1               mmap6.domain mmap6" >> $ROOT_PATH/etc/hosts
    echo -e "::1                 localhost6.localdomain6 localhost6" >> $ROOT_PATH/etc/hosts

    sed -i "s/\(HOSTNAME=.*\)/HOSTNAME=mmap6/" $ROOT_PATH/etc/sysconfig/network
fi

# network config file
if [ "$install_type" != "-s" ];then
    sed -i "s/\(NETWORKING=.*\)/NETWORKING=yes/" $SYSTEM_PATH/etc/sysconfig/network
    sed -i "s/\(NETWORKING_IPV6=.*\)/NETWORKING_IPV6=no/" $SYSTEM_PATH/etc/sysconfig/network
    sed -i "s/\(HOSTNAME=.*\)/HOSTNAME=mmap6/" $SYSTEM_PATH/etc/sysconfig/network
    #sed -i "s/\(GATEWAY=.*\)/GATEWAY=10.2.0.1/" $SYSTEM_PATH/etc/sysconfig/network
fi

# wowza
grep -q wowzalicense1 $SYSTEM_PATH/etc/hosts   # revise etc copy bug, by diwen
if [ $? != 0 ];then
    echo -e "\n127.0.0.1 wowzalicense1.wowzamedia.com \n127.0.0.1 wowzalicense2.wowzamedia.com \n127.0.0.1 wowzalicense3.wowzamedia.com \n127.0.0.1 wowzalicense4.wowzamedia.com\n" >> $SYSTEM_PATH/etc/hosts
fi

# update rc.update file                     # disabled by diwen
# grep -q snmpd $ROOT_PATH/etc/rc.update
# if [ $? != 0 ];then
#     echo -e "\n/etc/init.d/snmpd restart\n" >> $ROOT_PATH/etc/rc.update  # revise by diwen
#     echo -e "\n[[ -d /usr/local/aria2c ]] && su -c \"/usr/local/aria2c/bin/aria2c --conf=/usr/local/aria2c/conf/aria2c.conf\" mmap\n" >> $ROOT_PATH/etc/rc.update
#     echo -e "\n[[ -d /etc/rsyncd ]] && /usr/bin/rsync --daemon --config=/etc/rsyncd/rsyncd.conf\n" >> $ROOT_PATH/etc/rc.update
# fi

# other process
cp -ar ./burn_data/vmx-fstab $SYSTEM_PATH/etc/
# tune2fs -L media /dev/sda5
# tune2fs -L mysql /dev/sda6

# mkdir -p $ROOT_PATH/tmp                                       # disabled by diwen
# cp -ar ./burn_data/vmx_log.conf $ROOT_PATH/tmp/vmx_log.conf
# chmod 777 $ROOT_PATH/tmp/vmx_log.conf

# cp log driver
# grep -q vmx_log $ROOT_PATH/etc/rc.update
# if [ $? != 0 ];then
#     echo -e "mknod /dev/vmx_log c 255 0\nchmod 777 /dev/vmx_log\nchown root:root /dev/vmx_log\ninsmod /lib/modules/vmx_log_driver.ko\n" >> $ROOT_PATH/etc/rc.update
#     cp -ar ./burn_data/vmx_log_driver.2.6.32-358.el6.x86_64.ko $ROOT_PATH/lib/modules/vmx_log_driver.ko
#     cp -ar ./burn_data/logread $ROOT_PATH/bin
#     chmod +x $ROOT_PATH/bin/logread
# fi

# config iptalbes
mkdir -p $SYSTEM_PATH/etc/sysconfig/ && cp -ar ./burn_data/iptables $SYSTEM_PATH/etc/sysconfig/iptables
mkdir -p $SYSTEM_PATH/etc/sysconfig/ && cp -ar ./burn_data/iptables $ROOT_PATH/etc/sysconfig/iptables

# adjust the ip addr, 10.4.89.200, by diwen
if [ -n $SYSTEM_PATH ] && [ -n $ROOT_PATH ]; then
    if [ -f $SYSTEM_PATH/etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
        sed -i "s#^IPADDR=.*#IPADDR=\"10.4.89.200\"#" $SYSTEM_PATH/etc/sysconfig/network-scripts/ifcfg-eth0
    fi
    if [ -f $ROOT_PATH/etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
        sed -i "s#^IPADDR=.*#IPADDR=\"10.4.89.200\"#" $ROOT_PATH/etc/sysconfig/network-scripts/ifcfg-eth0
    fi

    # here, modify the python2.6 rpm lib path, by diwen
    if [ -f $ROOT_PATH/usr/lib/python2.6/site-packages/yum/rpmsack.py ]; then
        sed -i "s#/var/lib/rpm/#/opt/system/var/lib/rpm/#g" $ROOT_PATH/usr/lib/python2.6/site-packages/yum/rpmsack.py
    fi

    # here, record system version and build time
    [ -f $ROOT_PATH/etc/version ] && {
        echo "system_version=$system_version" >> $ROOT_PATH/etc/version
        echo "build_time=$build_time" >> $ROOT_PATH/etc/version
    }

    # here, modify the root password: '1234abcd!@#$@vmediax'
    # use 'grub-crypt --sha-512' cmd
    # and new passwd is ''1234abcd!@#$@vmediax''
    # '!' is '\0041'
    echo -e "1234abcd\0041@#\$@vmediax\n1234abcd\0041@#\$@vmediax" | passwd root

    [ "$?" == "0" ] && {
        echo "change root passwd to 1234abcd!@#$@vmediax ... success"
    }
    cp -a /etc/shadow $ROOT_PATH/etc
    cp -a /etc/passwd $ROOT_PATH/etc
    echo "sync the passwd shadow file to $ROOT_PATH/etc/shadow, ok"

    echo -e "123456\n123456" | passwd root
    echo "recovery the old localhost root passwd 1-6, ok"
fi

# try to umount dom, by diwen
for item in `df -h | grep update | awk '{ print $6 }' | sort -r`; do
    #statements
    echo "umount $item ..."
    umount $item
    [ "$?" != "0" ] && { echo 'umount failed'; }
done

echo "========= Build Over ========"
exit 0
