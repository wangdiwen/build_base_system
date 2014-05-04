#!/bin/sh

PWD_PATH=$(pwd)/./$(dirname $0)
PWD_PATH=${PWD_PATH//\/.\/./}
TMP_PATH=${PWD_PATH}/tmp

INSTALL_TO_CF=1
INSTALL_AUTO=1
ROOT_PATH=
BOOT_PATH=/boot
SYSTEM_PATH=/opt/system

GRUB_PATH=/boot/grub

GRUB_SIMPLE_FILE=${PWD_PATH}/std_data/grub.conf.simple
GRUB_FILE=$GRUB_PATH/grub.conf

DEVICE=$(cat ${PWD_PATH}/std_data/config.ini|grep cf_card_device|awk -F "=" '{print $2}')

ISSUE_MAJOR_VERSION=$(cat /etc/issue|head -n 1 |awk '{printf $3}'|awk -F '.' '{printf $1}')
ISSUE_MINOR_VERSION=$(cat /etc/issue|head -n 1 |awk '{printf $3}'|awk -F '.' '{printf $2}')

## base functions
function format_text()
{
    local color="32"
    case $1 in
        RED)
            color="31"
            shift 1
            ;;
        GREEN)
            color="32"
            shift 1
            ;;
        GENERAL)
            color="0"
            shift 1
            ;;
    esac

    if [ "$color" == "0" ]; then
        echo -e "$*"
        return
    fi
    case $TERM in
            #   for the most terminal types we directly know the sequences
        xterm|xterm*|vt220|vt220*)
            term_bold=`echo -ne "\033[${color}m\033[1m";` #`awk 'BEGIN { printf("%c%c%c%c", 27, 91, 49, 109); }' </dev/null 2>/dev/null`
            term_norm=`echo -ne "\033[0m";` #`awk 'BEGIN { printf("%c%c%c", 27, 91, 109); }' </dev/null 2>/dev/null`
            ;;
        vt100|vt100*|cygwin)
            term_bold=`echo -ne "\033[${color}m\033[1m\0\0";` #`awk 'BEGIN { printf("%c%c%c%c%c%c", 27, 91, 49, 109, 0, 0); }' </dev/null 2>/dev/null`
            term_norm=`echo -ne "\033[0m\0\0";` #`awk 'BEGIN { printf("%c%c%c%c%c", 27, 91, 109, 0, 0); }' </dev/null 2>/dev/null`
            ;;
        *)  term_bold=`echo -ne "\033[${color}m\033[1m";`
            term_norm=`echo -ne "\033[0m";`
            ;;
    esac

    echo -e "$term_bold$*$term_norm"

    #sudo echo -e "$*\n" >> $BUILD_LOG_FILE
}

function log()
{
    format_text GENERAL $*
}

function info()
{
    format_text GREEN $*
}

function error()
{
    format_text RED $*
}
## tool functions

function make_part()
{
  local dev=$1
  local ptype=$2
  local start=$3
  local end=$4

  log "start parted $dev mkpart $ptype $start $end ... "
  parted -s -- $dev mkpart $ptype $start $end 
  if [ "$?" -eq 0 ]
  then
    log "done"
  else
    log "failed"
    return 1
  fi
  return 0
}

function mount_part()
{
    df|grep -q "$2"
    if [ $? != 0 ];then
        log "start mount -t ext3 $1 $2..."
        mount -t ext3 $1 $2 2>&1
        if [ $? == 0 ];then
            log "done"
        else
            error "failed"
            return 1
        fi
    fi
    return 0
}

function umount_part()
{
    df|grep -q "$1"
    if [ $? == 0 ];then
        log "start umount $1..."
        umount $1 2>&1
        if [ $? == 0 ];then
            log "done"
        else
            error "failed"
            return 1
        fi
    fi
    return 0
}



function string_to_number()
{
    local size_str=$1
    local number=$size_str
    if [ "${size_str:(-2)}" == "K" ]; then
        number=`echo "scale=0; ${size_str//GB/}*10000/10"|bc`
    elif [ "${size_str:(-1)}" == "KB"  ]; then
        number=`echo "scale=0; ${size_str//G/}*10000/10"|bc`
    elif [ "${size_str:(-2)}" == "GB" ]; then
        number=`echo "scale=0; ${size_str//GB/}*1000*1000*10000/10"|bc`
    elif [ "${size_str:(-1)}" == "G"  ]; then
        number=`echo "scale=0; ${size_str//G/}*1000*1000*10000/10"|bc`
    elif [ "${size_str:(-2)}" == "MB" ]; then
        number=`echo "scale=0; ${size_str//MB/}*1000*10000/10"|bc`
    elif [ "${size_str:(-1)}" == "M"  ]; then
        number=`echo "scale=0; ${size_str//M/}*1000*10000/10"|bc`
    else
        number=`echo "scale=0; ${size_str}*10000000/10"|bc`
    fi
    echo $number
}

function check_cf_card() {
    local hda=$(fdisk -l | grep "Disk ${1}");
    if [ -n "$hda" ]; then
        return 0
    else
        return 1
    fi
}


## implement functions

function install_tools()
{
    # TO DO
    # Check the rpm tools file exists
    num=`ls ${PWD_PATH}/tools | grep ^tripwire.*rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        error "build_validate_database: ./Tools has no tripwire rpm file"
        return 1
    fi

    name=`ls ${PWD_PATH}/tools/ | grep ^tripwire.*rpm$ | awk '{ print }' | sed -n '1p'`
    local tripwire_tool="${PWD_PATH}/tools/"$name
    # echo $tripwire_tool

    # Install the tripwire tool
    if [ -f "/usr/local/sbin/tripwire" ]; then
        error "build_validate_database: Delete the old tripwire..."
        rpm -e tripwire
    fi

    log "build_validate_database: Install tripwire..."
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

function grub_rework()
{
    # TO DO
    grub_password

    echo "cp ${GRUB_SIMPLE_FILE} ${GRUB_FILE}"
    cp $GRUB_SIMPLE_FILE $GRUB_FILE

    # Check the kernel file
    local num=`ls /boot | grep ^vmlinuz | wc -l`
    if [ $num -eq 0 ]; then
        error "grub_rework: has no kernel file"
    fi
    local kernel_name=`ls /boot | grep ^vmlinuz | sed -n '1p'`

    # Modify the grub file
    sed -i "s#kernel-name#${kernel_name}#g" $GRUB_FILE
    log "grub_rework: Check the kernel version $kernel_name OK!"

    return
}

function grub_password()
{
    # TO DO
    # Check the param

    local tmp_file=${TMP_PATH}/tmp.txt

    if [ ! -f $GRUB_SIMPLE_FILE ]; then
        log "grub_password: has no $GRUB_SIMPLE_FILE file"
        return 1
    fi

    # Use grub-md5-crypt tool
    #log "Add grub password..."
    #(
    #    /sbin/grub-md5-crypt
    #)|tee $tmp_file
    #local password=`sed -n '3p' $tmp_file`
    local gurb_passwd="123abc!@#@vmediax"
    if [ $INSTALL_AUTO != 0 ];then 
        read -p "please input grub password:" gurb_passwd
    fi
    #local password=`perl -e 'open FH, "|/sbin/grub-md5-crypt"; print FH "${gurb_passwd}\n${gurb_passwd}\n"' 2>/dev/null | tail -1`
    local password=`echo -e "${gurb_passwd}\n${gurb_passwd}"|/sbin/grub-md5-crypt 2>/dev/null|tail -1`

    local line_num=`sed -n '/^password/=' $GRUB_SIMPLE_FILE`
    # echo "${line_num}s#.*#password --md5 ${password}#"
    sed -i "${line_num}s#.*#password --md5 ${password}#" $GRUB_SIMPLE_FILE >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log "grub_password: add the grub password success"
    else
        error "grub_password: modify the $GRUB_SIMPLE_FILE failed"
        return 1
    fi

    return 0
}

function install_manager_system()
{
    if [ $INSTALL_TO_CF -eq 0 ];then
        umount_part ${ROOT_PATH}
        rm -rf ${ROOT_PATH}/opt/system
        
        mount_part ${DEVICE}2 ${ROOT_PATH} || return 1
        mkdir -p ${ROOT_PATH}/opt/system
    fi

    # Install the python27
    num=`ls ${PWD_PATH}/tools | grep ^python27.*el${ISSUE_MAJOR_VERSION}.x86_64.rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        error "install_manager_system: ./Tools has no python27 rpm file"
        return 1
    fi

    #name=`ls ${PWD_PATH}/tools/ | grep ^python27.*rpm$ | awk '{ print }' | sed -n '1p'`
    name=`ls ${PWD_PATH}/tools/ | grep ^python27.*el${ISSUE_MAJOR_VERSION}.x86_64.rpm$ | awk '{ print }' | tail -1`
    local python27_tool="${PWD_PATH}/tools/"$name

    rpm -q python27
    if [ $? == 0 ]; then
        log "install_manager_system: Delete the old python27..."
        rpm -e python27
    fi

    log "install_manager_system: Install python27..."
    rpm -ivh $python27_tool --prefix=${ROOT_PATH}/usr --nodeps --force

    if [ $? -eq 0 ]; then
        log "install_manager_system: Install python27 ok"
    else
        error "install_manager_system: Install python27 failed"
        # exit 1
    fi

    # Install the restful-server
    num=`ls ${PWD_PATH}/tools | grep ^restful-server.*rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        log "install_manager_system: ./Tools has no restful-server rpm file"
        return 1
    fi

    #name=`ls ${PWD_PATH}/tools/ | grep ^restful-server.*rpm$ | awk '{ print }' | sed -n '1p'`
    name=`ls ${PWD_PATH}/tools/ | grep ^restful-server.*rpm$ | awk '{ print }' | tail -1`
    local restful_tool="${PWD_PATH}/tools/"$name

    rpm -q restful-server
    if [ $? == 0 ]; then
        log "install_manager_system: Delete the old restful-server..."
        rpm -e restful-server
    fi

    log "install_manager_system: Install restful-server..."
    rpm -ivh $restful_tool --prefix=$ROOT_PATH/ --nodeps --force

    if [ $? -eq 0 ]; then
        log "install_manager_system: Install restful-server ok"
    else
        error "install_manager_system: Install restful-server failed"
        # exit 1
    fi

    # Install the web-frontend
    num=`ls ${PWD_PATH}/tools | grep ^web-frontend.*rpm$ | wc -l`
    if [ $num -eq 0 ]; then
        error "install_manager_system: ./Tools has no web-frontend rpm file"
        return 1
    fi

    #name=`ls ${PWD_PATH}/tools/ | grep ^web-frontend.*rpm$ | awk '{ print }' | sed -n '1p'`
    name=`ls ${PWD_PATH}/tools/ | grep ^web-frontend.*rpm$ | awk '{ print }' | tail -1`
    local web_tool="${PWD_PATH}/tools/"$name

    rpm -q web-frontend
    if [ $? == 0 ]; then
        log "install_manager_system: Delete the old web-frontend..."
        rpm -e web-frontend
    fi

    log "install_manager_system: Install web-frontend..."
    rpm -ivh $web_tool --prefix=$ROOT_PATH/ --nodeps --force

    if [ $? -eq 0 ]; then
        log "install_manager_system: Install web-frontend ok"
    else
        error "install_manager_system: Install web-frontend failed"
        # exit 1
    fi

    #local iptables_conf=${ROOT_PATH}/etc/sysconfig/iptables
    #mkdir -p ${ROOT_PATH}/etc/sysconfig/&&cp -ar ${PWD_PATH}/std_data/iptables ${iptables_conf}
    #local count=$(cat ${iptables_conf}|wc -l)
    #local sed_args="$(($count-1)) i -A INPUT -m state --state NEW -m tcp -p tcp --dport 8089 -j ACCEPT"
    #sed -i "$sed_args" ${iptables_conf}

    return
}

function build_validate_database()
{
    # TO DO
    install_tools
    
    if [ -d /usr/local/lib/tripwire ];then
        rm -rf /usr/local/lib/tripwire/tripwire.twd
    fi
    
    log "start init the tripwire database, it will takes some minutes..."
    echo "vmediax"|/usr/local/sbin/tripwire --init  && log "done!" ||  { error "failed" ;return 1;  }

    return 0
}

function capture_version_and_system_info()
{

    local conf_file=$TMP_PATH/version
    [ -f "$TMP_PATH/version" ] && rm -rf $conf_file
    touch $conf_file

    #read -p "please input what you update system for,like [tvwall,terminal]" equipment
    #echo "equipment=${equipment}" >> $conf_file

    local update_version=$(cat ${PWD_PATH}/std_data/config.ini|grep current_version|awk -F "=" '{print $2}')
    echo "update_tool_version=${update_version}" >> $conf_file

    sed -i 's/CentOS/VMediaX/g' $ROOT_PATH/etc/redhat-release

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

function deal_system_conf()
{
    ## copy rc.update
    cp ${PWD_PATH}/std_data/rc.update $ROOT_PATH/etc
    chmod 777 $ROOT_PATH/etc/rc.update
    
    grep -q rc.update $ROOT_PATH/etc/rc.local
    if [ $? != 0 ];then
        echo "bash /etc/rc.update" >> $ROOT_PATH/etc/rc.local
    fi

    info "disable selinux..."
    local selinux_conf=$ROOT_PATH/etc/selinux/config
    sed -i "s#\(SELINUX=.*\)#SELINUX=disabled#" $selinux_conf

    info "deal zoneinfo file"
    rm -rf $ROOT_PATH/etc/localtime
    ln -s /usr/share/zoneinfo/Asia/Shanghai $ROOT_PATH/etc/localtime

    #local count=$(cat ${TMP_PATH}/root/etc/rc.local|wc -l)
    #sed -i "${count} i sed -i \"1 i rootfs / rootfs rw 0 0\" /etc/mtab" $TMP_PATH/root/etc/rc.local


    # enable ip_forward
    local sysctl_conf=$ROOT_PATH/etc/sysctl.conf
    sed -i "s#\(net.ipv4.ip_forward.*\)#net.ipv4.ip_forward = 1#" $sysctl_conf
    
    info "copy /etc start..."
    local conf_file=${PWD_PATH}/data/system_config_file_list.conf
    cat ${conf_file} | while read line
    do
        if [ -z "$line" ]; then
            continue
        fi

        #if [ -f $line ]; then
            log "copy ${line}"
            mkdir -p ${SYSTEM_PATH}${line%/*}
            cp -ar ${ROOT_PATH}${line} ${SYSTEM_PATH}${line%/*}
        #fi
    done

    ####
    #mkdir -p $TMP_PATH/system/etc/sysconfig/restful-server
    #cp -ar $TMP_PATH/root/usr/local/restful-server/conf/* $TMP_PATH/system/etc/sysconfig/restful-server

    ##umount_part $TMP_PATH/system

    if [ ! -f $ROOT_PATH/etc/rc.d/init.d/startup ];then
        cp ${PWD_PATH}/std_data/startup $ROOT_PATH/etc/rc.d/init.d
        chmod 777 $ROOT_PATH/etc/rc.d/init.d/startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc2.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc3.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc4.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc5.d/S99startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc0.d/K1startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc1.d/K1startup
        ln -s ../init.d/startup $ROOT_PATH/etc/rc.d/rc6.d/K1startup
    fi

}


function mk_label_for_el6()
{
    local SELF_DEVICE=$(mount|grep "on / "|awk '{print $1}')
    local label=(/boot / )
    for i in 1 2
    do
        /sbin/tune2fs -L "${label[(($i-1))]}" "${SELF_DEVICE:0:8}${i}" > /dev/null  2>&1
    done
}

function parted_device()
{
    # TO DO
    info "burn system start..."

    check_cf_card ${DEVICE} || { error "cann't found ${DEVICE}!"; exit 1; }

    umount_part $ROOT_PATH || exit 1
    umount_part $BOOT_PATH || exit 1


    ## check size of CF
    echo "Yes"|parted $DEVICE mklabel msdos

    local cf_size=$(parted ${DEVICE} p | grep "Disk ${DEVICE}:" | awk '{print $3}')
    log "the ${DEVICE} size is $cf_size"
    log "the partition strategy we recommended:"
    log "------------------------------------\n" \
    "  LABEL    \t\t 1GB     \t 2 GB    \t 4 GB  \n" \
    "  /boot    \t\t 100 MB   100 MB  \t 100 MB  \n" \
    "  /        \t\t 550 MB    1.2 GB  \t 2 GB  \n" \
    "  system   \t 50 MB   50 MB  \t 200 MB  \n" \
    "  prog_bin \t 200 MB   300 MB  \t 1G  \n" \
    "  prog_etc \t 50 MB   \t 50 MB   \t 100 MB  \n" \
    "  prog_log \t 50 MB   \t 100 MB  200 MB  \n" \
    "------------------------------------"
    cf_size=$(string_to_number $cf_size)
    local start_part_offset=0
    
    local auto="yes"
    if [ $INSTALL_AUTO -eq 1 ];then 
        read -p "Auto parted or not[yes|no]" auto
    fi
    
    if [ "$auto" != "yes" ];then
        cf_size=$(($cf_size*90/100/1000000))

        local boot_size=0
        while [ $boot_size -lt 100 ]
        do
            read -p "1.[<=$((($cf_size - $start_part_offset))) MB]please press /boot part size(MB) >= 100MB:" boot_size
            boot_size=$(($(string_to_number $boot_size)/1000000))
        done

        local root_size=0
        while [ $root_size -lt 1000 ]
        do
            read -p "2.[<=$((($cf_size - $start_part_offset - $boot_size))) MB]please press / part size(MB) >= 1000MB:" root_size
            
        done
        if [ -z $root_size ]; then
            root_size=$(($cf_size - $start_part_offset - $boot_size))
        else
            root_size=$(($(string_to_number $root_size)/1000000))
        fi
    else
        if (($cf_size >= 3600))
        then
            cf_size=$((3600+$start_part_offset))
            boot_size=100
            root_size=3500
        elif (($cf_size >= 1800))
        then
            cf_size=$((1800+$start_part_offset))
            boot_size=100
            root_size=1700
        else
            error "space is not enough!"
            return 0
        fi
    fi

    ## parted CF and make label
    for((i=2;i>0;i--))
    do
        parted $DEVICE rm $i > /dev/null
    done

    local has_parted=$start_part_offset
    make_part $DEVICE primary ${has_parted} $((${has_parted}+${boot_size}))
    has_parted=$(($has_parted+$boot_size))
    sleep 1
    make_part $DEVICE primary $((${has_parted})) $((${has_parted}+${root_size}))
    has_parted=$((${has_parted}+${root_size}))

    sleep 4

    local label=(/boot /)
    for i in 1 2
    do
        log "mklabel for ${DEVICE}${i}"
        mkfs.ext3 "${DEVICE}${i}" > /dev/null  2>&1
        /sbin/tune2fs -L "${label[(($i-1))]}" "${DEVICE}${i}" > /dev/null  2>&1
    done

    /sbin/partprobe 2>&1

    sleep 2

    return 0
}

function burn_system()
{
    ## cp root system to CF
    rm -rf $ROOT_PATH
    mkdir -p $ROOT_PATH
    mount_part ${DEVICE}2 $ROOT_PATH || return 1

    log "copy root system!"
    local root_list=(bin lib64 opt usr etc lib sbin tmp var)
    for path in ${root_list[@]}
    do
        log "cp -ar /${path} $ROOT_PATH"
        if [ -d "/${path}" ]; then
            cp -ar /${path} $ROOT_PATH
        fi
    done

    #make necessary dir
    local mkdir_list=(home proc dev boot root sys opt/system opt/program opt/program/bin opt/program/etc opt/program/log)
    for path in ${mkdir_list[@]}
    do
        log "mkdir -p $ROOT_PATH/${path}"
        mkdir -p $ROOT_PATH/${path}
    done
    
    chmod 777 $ROOT_PATH/opt/program/etc
    chmod 777 $ROOT_PATH/opt/program/log

    ## cp boot system to CF
    rm -rf $BOOT_PATH
    mkdir -p $BOOT_PATH
    mount_part ${DEVICE}1 $BOOT_PATH || return 1

    log "copy boot system!"
    cp -ar /boot/* $BOOT_PATH

    /bin/sync
    return 0
}

function grub_install()
{
    info "install grub..."
    #or local device_name=$(/sbin/grub-install --recheck ${DEVICE} 2>&1 |grep ${DEVICE}|grep -oE '[a-z1-9]+'|head -n 1)
    #local device_name=$(/sbin/grub-install --recheck ${DEVICE} 2>&1 |grep ${DEVICE}|awk '{print $1}'|grep -oE '[a-z0-9]+')
    [ -f /boot/grub/device.map ]&&mv /boot/grub/device.map /boot/grub/device.map.backup
    echo -e "quit\n"|grub --device-map=/boot/grub/device.map
    local device_name=$(cat /boot/grub/device.map|grep ${DEVICE}|awk '{print $1}'|grep -oE '[a-z0-9]+')
    if [ -z $device_name ]; then
        error "device name not found!"
        mv /boot/grub/device.map.backup /boot/grub/device.map
        return 1
    fi

    log "device_name is $device_name"
    /sbin/grub --batch --no-floppy 2>&1 <<EOF >> /dev/null
root ($device_name,0)
setup ($device_name)
quit
EOF

    mv /boot/grub/device.map.backup /boot/grub/device.map

    /bin/sync
    return 0
}
# script implements

grep -q proxy=http /etc/yum.conf
if [ $? != 0 ]; then
    echo -e "\nproxy=http://10.1.0.1:8081\n" >> /etc/yum.conf
fi

Usage=$(echo "Usage: basesys_update.sh [Options...] do all things with none arguments \n"\
       "Options:\n"\
       "-g|--grub modify grub\n" \
       "-c|--cut cut out standard system\n" \
       "-v|--validate build validate database file\n" \
       "-b|--burn burn system to CF card\n" \
       "-h|--help show the Usage\n" \
       "            " );

while [ "$1" != "${1##[-+]}" ]; do
    case $1 in
        #-i|--initrd)
        #    initrd_repack
        #    shift
        #    ;;
        -d|--device)
            INSTALL_TO_CF=0
            shift
            ;;
        -a|--auto)
            INSTALL_AUTO=0
            shift
            ;;
        #-m|--manager)
        #    install_manager_system
        #    shift
        #    ;;
        #-v|--validate)
        #    build_validate_database
        #    shift
        #    ;;
        #-b|--burn)
        #    burn_system
        #    shift
        #    ;;
        -h) log ${Usage}
            exit 1
            ;;
        --help) log ${Usage}
            exit 1
            ;;
        *) log ${Usage}
            exit 1
            ;;
    esac
done

#if [ "$#" -lt "1" ]; then
    
    if [ $INSTALL_TO_CF -eq 0 ];then
        GRUB_PATH=$TMP_PATH/boot/grub
        GRUB_FILE=$GRUB_PATH/grub.conf
    fi
    
    rpm -q ntp
    if [ $? != 0 ];then
        yum install ntp -y
    fi
    
    if [ $INSTALL_TO_CF -eq 0 ];then 
        ROOT_PATH=${TMP_PATH}/root
        BOOT_PATH=${TMP_PATH}/boot
        SYSTEM_PATH=${ROOT_PATH}/opt/system
        umount_part $ROOT_PATH || exit 1
        umount_part $BOOT_PATH || exit 1
    fi

    if [ -d "$TMP_PATH" ]; then
        log "rebuild $TMP_PATH"
        rm -rf $TMP_PATH
    fi
    mkdir -p $TMP_PATH
    
    #create user mmap
    /usr/bin/id -u mmap
    if [ $? != 0 ];then
        useradd mmap
		if [ -f /home/mmap/.bash_profile ];then
		    echo -e "\nexport PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin\n" >> /home/mmap/.bash_profile
        fi
	fi
    echo -e "mmap@vmediax\nmmap@vmediax" |passwd mmap

    #build_validate_database
    if [ $INSTALL_TO_CF -eq 0 ];then 
        parted_device || exit 1
        burn_system || exit 1
        grub_install || exit 1
    else
        if [ "$ISSUE_MAJOR_VERSION" == "6" ];then 
            mk_label_for_el6
        fi
    fi
    #grub_rework
    install_manager_system
    deal_system_conf
    capture_version_and_system_info
    exit 0
#fi
