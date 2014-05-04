#!/bin/sh

PWD_PATH=$(pwd)/./$(dirname $0)
PWD_PATH=${PWD_PATH//\/.\/./}

ROOT_PATH=
BOOT_PATH=/boot
SYSTEM_PATH=/opt/system

## implement functions

function capture_version_and_system_info()
{

    local conf_file=${PWD_PATH}/version
    [ -f "${PWD_PATH}/version" ] && rm -rf $conf_file
    touch $conf_file

    #read -p "please input what you update system for,like [tvwall,terminal]" equipment
    #echo "equipment=${equipment}" >> $conf_file

    local update_version=$(cat ${PWD_PATH}/data/config.ini|grep current_version|awk -F "=" '{print $2}')
    echo "update_tool_version=${update_version}" >> $conf_file

    #sed -i 's/CentOS/VMediaX/g' $ROOT_PATH/etc/redhat-release

    local issue=$(cat ${ROOT_PATH}/etc/issue|head -1)
    echo "issue=${issue}" >> $conf_file

    local kernel_version=$(uname -s -p -i -r)
    echo "kernel=${kernel_version}" >> $conf_file

    local cpu=$(cat /proc/cpuinfo |grep name|awk -F ":" '{print $2;exit}')
    echo "cpu=${cpu## }" >> $conf_file

    local base_board=$(dmidecode -t 2|grep Product|awk -F ":" '{print $2}')
    echo "base_board=${base_board## }" >> $conf_file

    #local video_adaptor=$(dmidecode |grep -i VGA|awk -F ":" '{print $2}')
    local video_adaptor=$(lspci |grep -i VGA|awk -F ":" '{print $3}'|head -n 1)
    echo "video_adaptor=${video_adaptor## }" >> $conf_file

    cp $conf_file $ROOT_PATH/etc


}

function install_tools()
{
    # TO DO
    # Check the rpm tools file exists
    num=`ls ${PWD_PATH}/tools | grep ^tripwire.*rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        echo -e "build_validate_database: ./Tools has no tripwire rpm file"
        return 1
    fi

    name=`ls ${PWD_PATH}/tools/ | grep ^tripwire.*rpm$ | awk '{ print }' | sed -n '1p'`
    local tripwire_tool="${PWD_PATH}/tools/"$name
    # echo $tripwire_tool

    # Install the tripwire tool
    if [ -f "/usr/local/sbin/tripwire" ]; then
        echo -e "build_validate_database: Delete the old tripwire..."
        rpm -e tripwire
    fi

    echo -e "build_validate_database: Install tripwire..."
    rpm -ivh $tripwire_tool

    if [ $? -eq 0 ]; then
        echo "build_validate_database: Install tripwire ok"
    else
        echo "build_validate_database: Install tripwire failed"
        exit 1
    fi
    
    echo "install_tools: Install the tripwire OK!!!"
    return
}


function install_manager_system()
{

    # Install the python27
    num=`ls ${PWD_PATH}/tools | grep ^python27.*rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        echo -e "install_manager_system: ./Tools has no python27 rpm file"
        return 1
    fi

    #name=`ls ${PWD_PATH}/tools/ | grep ^python27.*rpm$ | awk '{ print }' | sed -n '1p'`
    name=`ls ${PWD_PATH}/tools/ | grep ^python27.*rpm$ | awk '{ print }' | tail -1`
    local python27_tool="${PWD_PATH}/tools/"$name

    rpm -q python27
    if [ $? == 0 ]; then
        echo -e "install_manager_system: Delete the old python27..."
        rpm -e python27
    fi

    echo -e "install_manager_system: Install python27..."
    rpm -ivh $python27_tool --prefix=${ROOT_PATH}/usr --nodeps --force

    if [ $? -eq 0 ]; then
        echo -e "install_manager_system: Install python27 ok"
    else
        echo -e "install_manager_system: Install python27 failed"
        # exit 1
    fi

    # Install the restful-server
    num=`ls ${PWD_PATH}/tools | grep ^restful-server.*rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        echo -e "install_manager_system: ./Tools has no restful-server rpm file"
        return 1
    fi

    #name=`ls ${PWD_PATH}/tools/ | grep ^restful-server.*rpm$ | awk '{ print }' | sed -n '1p'`
    name=`ls ${PWD_PATH}/tools/ | grep ^restful-server.*rpm$ | awk '{ print }' | tail -1`
    local restful_tool="${PWD_PATH}/tools/"$name

    rpm -q restful-server
    if [ $? == 0 ]; then
        echo -e "install_manager_system: Delete the old restful-server..."
        rpm -e restful-server
    fi

    echo -e "install_manager_system: Install restful-server..."
    rpm -ivh $restful_tool --prefix=$ROOT_PATH/ --nodeps --force

    if [ $? -eq 0 ]; then
        echo -e "install_manager_system: Install restful-server ok"
    else
        echo -e "install_manager_system: Install restful-server failed"
        # exit 1
    fi

    # Install the web-frontend
    num=`ls ${PWD_PATH}/tools | grep ^web-frontend.*rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        echo -e "install_manager_system: ./Tools has no web-frontend rpm file"
        return 1
    fi

    #name=`ls ${PWD_PATH}/tools/ | grep ^web-frontend.*rpm$ | awk '{ print }' | sed -n '1p'`
    name=`ls ${PWD_PATH}/tools/ | grep ^web-frontend.*rpm$ | awk '{ print }' | tail -1`
    local web_tool="${PWD_PATH}/tools/"$name

    rpm -q web-frontend
    if [ $? == 0 ]; then
        echo -e "install_manager_system: Delete the old web-frontend..."
        rpm -e web-frontend
    fi

    echo -e "install_manager_system: Install web-frontend..."
    rpm -ivh $web_tool --prefix=$ROOT_PATH/ --nodeps --force

    if [ $? -eq 0 ]; then
        echo -e "install_manager_system: Install web-frontend ok"
    else
        echo -e "install_manager_system: Install web-frontend failed"
        # exit 1
    fi

    #local iptables_conf=${ROOT_PATH}/etc/sysconfig/iptables
    #mkdir -p ${ROOT_PATH}/etc/sysconfig/&&cp -ar ${PWD_PATH}/data/iptables ${iptables_conf}

    return
}

function build_validate_database()
{
    # TO DO
    install_tools
    
    if [ -d /usr/local/lib/tripwire ];then
        rm -rf /usr/local/lib/tripwire/tripwire.twd
    fi
    
    echo -e "start init the tripwire database, it will takes some minutes..."
    echo "vmediax"|/usr/local/sbin/tripwire --init  && echo -e "done!" ||  { echo -e "failed" ;return 1;  }

    return 0
}

function deal_system_conf()
{
    ## copy rc.update
    cp ${PWD_PATH}/data/rc.update $ROOT_PATH/etc
    chmod 777 $ROOT_PATH/etc/rc.update
    
    grep -q rc.update $ROOT_PATH/etc/rc.local
    if [ $? != 0 ];then
        echo "bash /etc/rc.update" >> $ROOT_PATH/etc/rc.local
    fi
    
    #echo -e "copy default fstab..."
    #cp ${PWD_PATH}/data/fstab $ROOT_PATH/etc

    echo -e "disable selinux..."
    local selinux_conf=$ROOT_PATH/etc/selinux/config
    sed -i "s#\(SELINUX=.*\)#SELINUX=disabled#" $selinux_conf

    #echo -e "deal zoneinfo file"
    #rm -rf $ROOT_PATH/etc/localtime
    #ln -s /usr/share/zoneinfo/Asia/Shanghai $ROOT_PATH/etc/localtime

    #local count=$(cat ${TMP_PATH}/root/etc/rc.local|wc -l)
    #sed -i "${count} i sed -i \"1 i rootfs / rootfs rw 0 0\" /etc/mtab" $TMP_PATH/root/etc/rc.local


    # enable ip_forward
    local sysctl_conf=$ROOT_PATH/etc/sysctl.conf
    sed -i "s#\(net.ipv4.ip_forward.*\)#net.ipv4.ip_forward = 1#" $sysctl_conf

    ## cp /etc to /opt/system/etc
    
    echo -e "copy /etc start..."
    local conf_file=${PWD_PATH}/data/system_config_file_list.conf
    cat ${conf_file} | while read line
    do
        if [ -z "$line" ]; then
            continue
        fi

        #if [ -f $line ]; then
            echo -e "copy ${line}"
            mkdir -p ${SYSTEM_PATH}${line%/*}
            cp -ar ${ROOT_PATH}${line} ${SYSTEM_PATH}${line%/*}
        #fi
    done

    ####
    #mkdir -p $TMP_PATH/system/etc/sysconfig/restful-server
    #cp -ar $TMP_PATH/root/usr/local/restful-server/conf/* $TMP_PATH/system/etc/sysconfig/restful-server

    ####
    #grep -q vmx-modules $ROOT_PATH/etc/rc.sysinit
    #if [ $? != 0 ];then
    #    echo -e "\nfor file in /etc/sysconfig/vmx-modules/*.modules ; do\n  [ -x \$file ] && \$file\ndone\n" >> $ROOT_PATH/etc/rc.sysinit
    #fi
    
    #mkdir -p $ROOT_PATH/etc/sysconfig/vmx-modules
    #cp ${PWD_PATH}/data/update.modules $ROOT_PATH/etc/sysconfig/vmx-modules/
    #chmod 777 $ROOT_PATH/etc/sysconfig/vmx-modules/update.modules
    
    ##umount_part $TMP_PATH/system

    if [ ! -f $ROOT_PATH/etc/rc.d/init.d/startup ];then
        cp ${PWD_PATH}/data/startup $ROOT_PATH/etc/rc.d/init.d
        chmod 777 $ROOT_PATH/etc/rc.d/init.d/startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc2.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc3.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc4.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc5.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc0.d/K1startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc1.d/K1startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc6.d/K1startup
    fi
    
    #move rpm datebase
    #grep -q /opt/system /usr/lib/rpm/macros
    #if [ $? != 0 ]; then
    #    sed -i 's#/var#/opt/system/var#g' /usr/lib/rpm/macros
    #    mkdir -p $SYSTEM_PATH/var/lib
    #    mv $ROOT_PATH/var/lib/rpm $SYSTEM_PATH/var/lib
    #fi

}


function cut_out_system()
{
    # TO DO
    echo -e "cut_out_system start..."
    local conf_file=${PWD_PATH}/data/cut_out_system.conf
    cat ${conf_file} | while read line
    do
        if [ "$line" == "" -o "${line:0:1}" == "#" ];then
            continue
        fi

        echo $line|grep -q ":"
        if [ $? -eq 0 ]; then
            local path=${line%:*}
            local file_pattern=${line##*:}
            if [ "${file_pattern:0:1}" == "+" ]; then
                local hold_file_list=${file_pattern:1}
                local path_all_file=$(ls $path)
                for file in $path_all_file
                do
                    local is_hold_file=0
                    for hold_file in $hold_file_list
                    do
                        if [ "$hold_file" == "$file" ]; then
                            is_hold_file=1
                            break
                        fi
                    done
                    if [ "$is_hold_file" == "1" ]; then
                        continue
                    fi
                    echo -e "remove ${path}/${file}"
                    rm -rf ${path}/${file}
                done
            elif [ "${file_pattern:0:1}" == "-" ]; then
                local remove_file_list=${file_pattern:1}
                local path_all_file=$(ls $path)
                for file in $path_all_file
                do
                    for remove_file in $remove_file_list
                    do
                        if [ "$remove_file" == "$file" ]; then
                            echo -e "remove ${path}/${file}"
                            rm -rf ${path}/${file}
                            break
                        fi
                    done
                done
            fi
        else
            echo -e "remove $line"
            rm -rf $line
        fi
    done
    
    ## extra
    localedef -f UTF-8 -i zh_CN zh_CN.UTF8
    
    echo -e "cut_out_system end..."
    return
}

#if [ "$#" -lt "1" ]; then
    grep -q proxy=http /etc/yum.conf
    if [ $? != 0 ]; then
        echo -e "\nproxy=http://10.1.0.1:8081\n" >> /etc/yum.conf
    fi
    
    #create user mmap
    /usr/bin/id -u mmap
    if [ $? != 0 ];then
        useradd mmap
		if [ -f /home/mmap/.bash_profile ];then
		    echo -e "\nexport PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin\n" >> /home/mmap/.bash_profile
        fi
	fi
    echo -e "mmap@vmediax\nmmap@vmediax" |passwd mmap

    #cut_out_system
    #build_validate_database
    install_manager_system
    deal_system_conf
    capture_version_and_system_info
    exit 0
#fi
