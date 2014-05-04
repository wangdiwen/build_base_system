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

GRUB_SIMPLE_FILE=${PWD_PATH}/data/grub.conf.simple
GRUB_FILE=$GRUB_PATH/grub.conf

DEVICE=$(cat ${PWD_PATH}/data/config.ini|grep cf_card_device|awk -F "=" '{print $2}')

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

function grub_background()
{
    # TO DO
    num=`ls ${PWD_PATH}/data | grep xpm.gz$ | wc -l`
    if [ $num -eq 0 ]; then
        error "grub_background: ./data has no xpm.gz file"
        return 1
    fi

    local file_name=`ls ${PWD_PATH}/data | grep xpm.gz$ | awk '{ print ;exit }'`
    # Start...
    if [ -z "${PWD_PATH}/data/${file_name}" ]; then
        error "grub_background: no xpm file!"
        return 1
    else
        # Get some text info

        # Modify the simple conf file
        SplashImage_T="s#\(splashimage=.*\)#splashimage=(hd0,0)/grub/${file_name}#"
        sed -i $SplashImage_T $GRUB_SIMPLE_FILE

        if [ $? -eq 0 ]; then
            # Repalce the xpm.gz file
            cp ${PWD_PATH}/data/${file_name} $GRUB_PATH

            # Check results
            if [ $? -eq 0 ]; then
                log "grub_background: modify the grub background success"
            fi
        else
            error "grub_background: modify the simple file failed"
        fi
    fi

    return
}

function install_manager_system()
{
    if [ $INSTALL_TO_CF -eq 0 ];then
        umount_part ${ROOT_PATH}/opt/system
        rm -rf ${ROOT_PATH}/opt/system

        mkdir -p ${ROOT_PATH}/opt/system
        mount_part ${DEVICE}3 ${ROOT_PATH}/opt/system || return 1
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

    echo '##################################################'
    echo "restful-server version = $name"
    echo '##################################################'
    sleep 3

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

    local iptables_conf=${ROOT_PATH}/etc/sysconfig/iptables
    mkdir -p ${ROOT_PATH}/etc/sysconfig/&&cp -ar ${PWD_PATH}/data/iptables ${iptables_conf}
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

    local update_version=$(cat ${PWD_PATH}/data/config.ini|grep current_version|awk -F "=" '{print $2}')
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
    cp ${PWD_PATH}/data/rc.update $ROOT_PATH/etc
    chmod 777 $ROOT_PATH/etc/rc.update

    grep -q rc.update $ROOT_PATH/etc/rc.local
    if [ $? != 0 ];then
        echo "bash /etc/rc.update" >> $ROOT_PATH/etc/rc.local
    fi

    info "copy default fstab..."
    cp ${PWD_PATH}/data/fstab $ROOT_PATH/etc

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

    ## cp /etc to /opt/system/etc
    if [ $INSTALL_TO_CF -eq 0 ];then
        umount_part $TMP_PATH/system || exit 1
        umount_part ${ROOT_PATH}/opt/system || exit 1
        rm -rf $SYSTEM_PATH
        mkdir -p $SYSTEM_PATH
        mount_part ${DEVICE}3 $SYSTEM_PATH || return 1
    fi

    info "copy /etc start ..."
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

    ####
    grep -q vmx-modules $ROOT_PATH/etc/rc.sysinit
    if [ $? != 0 ];then
        echo -e "\nfor file in /etc/sysconfig/vmx-modules/*.modules ; do\n  [ -x \$file ] && \$file\ndone\n" >> $ROOT_PATH/etc/rc.sysinit
    fi

    mkdir -p $ROOT_PATH/etc/sysconfig/vmx-modules
    cp ${PWD_PATH}/data/update.modules $ROOT_PATH/etc/sysconfig/vmx-modules/
    chmod 777 $ROOT_PATH/etc/sysconfig/vmx-modules/update.modules

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
    grep -q /opt/system $ROOT_PATH/usr/lib/rpm/macros
    if [ $? != 0 ]; then
        # sed -i 's#/var#/opt/system/var#g' /usr/lib/rpm/macros
        sed -i 's#/var#/opt/system/var#' $ROOT_PATH/usr/lib/rpm/macros  # a bug, by diwen
    fi

    mkdir -p $SYSTEM_PATH/var/lib
    mv $ROOT_PATH/var/lib/rpm $SYSTEM_PATH/var/lib
    # cp -ar $ROOT_PATH/var/lib/rpm $SYSTEM_PATH/var/lib  # revise, by diwen
    cp -ar /var/lib/rpm $SYSTEM_PATH/var/lib            # update magtools, rest and web rpm version info

    if [ -d /opt/system/var/lib/rpm ]; then
        cp -ar /opt/system/var/lib/rpm $SYSTEM_PATH/var/lib
    fi
}

function initrd_repack()
{
    # TO DO
    info "initrd_repack start..."
    if [ $INSTALL_TO_CF -eq 1 ];then
        [ -f /boot/initrd-release.img ]&&rm -rf /boot/initrd-release.img
        [ -f /boot/initrd-develop.img ]&&rm -rf /boot/initrd-develop.img
    fi

    local pkg_path=$(/usr/bin/find /boot/init*.img|grep -v initrd-release|grep -v initrd-develop|grep init|head -1)
    local pkg=${pkg_path##*/}
    ## unpack
    log "cp ${pkg_path} to ${TMP_PATH}/${pkg}.gz..."
    cp ${pkg_path} ${TMP_PATH}/${pkg}.gz

    log "decompress ${TMP_PATH}/${pkg}.gz..."
    gunzip ${TMP_PATH}/${pkg}.gz > /dev/null
    mkdir -p ${TMP_PATH}/initrd
    cd ${TMP_PATH}/initrd
    log "unpack ${TMP_PATH}/${pkg}..."
    cpio -ivdum < ../${pkg}
    cd -
    ## modify init script
    log "modify init script..."
    cp ${TMP_PATH}/initrd/init ${TMP_PATH}/init_release
    cp ${TMP_PATH}/initrd/init ${TMP_PATH}/init_develop

    ## temporary usage
    #cp ${PWD_PATH}/data/init_release ${TMP_PATH}/init_release
    #cp ${PWD_PATH}/data/init_develop ${TMP_PATH}/init_develop
    if [ "$ISSUE_MAJOR_VERSION" == "5" ];then
        local line_mkblkdevs=$((`sed -n '/^mkblkdevs/=' ${TMP_PATH}/initrd/init | awk END'{print $0}'` + 1))
        local line_mkrootdev=$((`sed -n '/^echo Setting up other filesystems/=' ${TMP_PATH}/initrd/init` - 1))

        for model in release develop
        do
            if (($line_mkblkdevs <= $line_mkrootdev))
            then
                log "deleate without avail lines!"
                sed -i "${line_mkblkdevs},${line_mkrootdev}d" ${TMP_PATH}/init_${model}
            fi
            if [ "$model" == "release" ]; then
                local sed_args="$((line_mkblkdevs)) i \/bin\/ash init_release"
                sed -i "$sed_args" ${TMP_PATH}/init_${model}
            else
                local sed_args="$(($line_mkblkdevs-1)) r ${PWD_PATH}/data/develop_init_script_data"
                sed -i "$sed_args" ${TMP_PATH}/init_${model}
            fi
        done
        ## repack initrd
        # relese busybox
        cd ${TMP_PATH}/initrd
        tar -zxf $PWD_PATH/data/busybox.tar.gz .
        cd -
    elif [ "$ISSUE_MAJOR_VERSION" == "6" ];then
        local line_wait_for_loginit=$((`sed -n '/^wait_for_loginit/=' ${TMP_PATH}/initrd/init | awk END'{print $0}'` + 1))
        for model in release develop
        do
            local sed_args="$((line_wait_for_loginit)) i \/bin\/sh init_${model}"
            sed -i "$sed_args" ${TMP_PATH}/init_${model}
        done
    fi


    cp ${TMP_PATH}/init_release ${TMP_PATH}/initrd/init
    cp ${PWD_PATH}/data/init_release ${TMP_PATH}/initrd/
    log "build ${TMP_PATH}/initrd_release.img..."
    cd ${TMP_PATH}/initrd
    find . -print |cpio -o -H newc |gzip -9 > ${TMP_PATH}/initrd-release.img

    rm ${TMP_PATH}/initrd/init_release
    cp ${TMP_PATH}/init_develop ${TMP_PATH}/initrd/init
    cp ${PWD_PATH}/data/init_develop ${TMP_PATH}/initrd/
    log "build ${TMP_PATH}/init_develop.img..."
    find . -print |cpio -o -H newc |gzip -9 > ${TMP_PATH}/initrd-develop.img
    cd -

    cp ${TMP_PATH}/initrd-release.img $BOOT_PATH
    cp ${TMP_PATH}/initrd-develop.img $BOOT_PATH
    ##
    info "initrd_repack end..."
    return
}


function cut_out_system()
{
    # TO DO
    info "cut_out_system start..."
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
                    log "remove ${path}/${file}"
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
                            log "remove ${path}/${file}"
                            rm -rf ${path}/${file}
                            break
                        fi
                    done
                done
            fi
        else
            log "remove $line"
            rm -rf $line
        fi
    done

    ## extra
    localedef -f UTF-8 -i zh_CN zh_CN.UTF8

    info "cut_out_system end..."
    return
}

function mk_label_for_el6()
{
    local SELF_DEVICE=$(mount|grep "on / "|awk '{print $1}')
    local label=(/boot / system _blink prog_bin prog_etc prog_log)
    for i in 1 2 3 5 6 7
    do
        /sbin/tune2fs -L "${label[(($i-1))]}" "${SELF_DEVICE:0:8}${i}" > /dev/null  2>&1
    done
}

function parted_device()
{
    # TO DO
    info "burn system start..."

    check_cf_card ${DEVICE} || { error "cann't found ${DEVICE}!"; exit 1; }

    umount_part $ROOT_PATH/opt/system || exit 1
    umount_part $ROOT_PATH || exit 1
    umount_part $BOOT_PATH || exit 1
    umount_part $SYSTEM_PATH || exit 1

    # update kernel partprobe, by diwen
    # /sbin/partprobe 2>&1

    ## check size of CF
    # echo "Yes"|parted $DEVICE mklabel msdos
    parted -s ${DEVICE} mklabel msdos     # by diwen

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
            root_size=$(($(string_to_number $root_size)/1000000))
        done

        read -p "3.[<=$((($cf_size - $start_part_offset - $boot_size - $root_size))) MB]please press system part size(MB)" system_size
        system_size=$(($(string_to_number $system_size)/1000000))

        read -p "4.[<=$((($cf_size - $start_part_offset - $boot_size - $root_size - $system_size))) MB]please press prog_bin part size(MB)" prog_bin_size
        prog_bin_size=$(($(string_to_number $prog_bin_size)/1000000))

        read -p "5.[<=$((($cf_size - $start_part_offset - $boot_size - $root_size - $system_size - $prog_bin_size))) MB]please press prog_etc part size(MB)" prog_etc_size
        prog_etc_size=$(($(string_to_number $prog_etc_size)/1000000))

        read -p "6.[<=$((($cf_size - $start_part_offset - $boot_size - $root_size - $system_size - $prog_bin_size - $prog_etc_size))) MB]please press prog_log part size(MB)" prog_log_size
        if [ -z $prog_log_size ]; then
            prog_log_size=$(($cf_size - $start_part_offset - $boot_size - $root_size - $system_size - $prog_bin_size - $prog_etc_size))
        else
            prog_log_size=$(($(string_to_number $prog_log_size)/1000000))
        fi
    else
        if (($cf_size >= 3600))
        then
            cf_size=$((3600+$start_part_offset))
            boot_size=100
            root_size=2000
            system_size=200
            prog_bin_size=1000
            prog_etc_size=100
            prog_log_size=200
        elif (($cf_size >= 1800))
        then
            cf_size=$((1800+$start_part_offset))
            boot_size=100
            root_size=1200
            system_size=50
            prog_bin_size=300
            prog_etc_size=50
            prog_log_size=100
        else
            error "space is not enough!"
            return 0
        fi
    fi

    ## parted CF and make label
    for((i=6;i>0;i--))
    do
        parted $DEVICE rm $i > /dev/null
    done

    local has_parted=$start_part_offset
    make_part $DEVICE primary ${has_parted} $((${has_parted}+${boot_size}))M
    has_parted=$(($has_parted+$boot_size))
    sleep 1
    make_part $DEVICE primary $((${has_parted})) $((${has_parted}+${root_size}))
    has_parted=$((${has_parted}+${root_size}))
    sleep 1
    make_part $DEVICE primary $((${has_parted})) $((${has_parted}+${system_size}))
    has_parted=$((${has_parted}+${system_size}))
    sleep 1
    make_part $DEVICE extended $((${has_parted})) $((cf_size))
    sleep 1
    make_part $DEVICE logical $((${has_parted})) $((${has_parted}+${prog_bin_size}))
    has_parted=$((${has_parted}+${prog_bin_size}))
    sleep 1
    make_part $DEVICE logical $((${has_parted})) $((${has_parted}+${prog_etc_size}))
    has_parted=$((${has_parted}+${prog_etc_size}))
    sleep 1
    make_part $DEVICE logical $((${has_parted})) $((${has_parted}+${prog_log_size}))

    sleep 4

    local label=(/boot / system _blink prog_bin prog_etc prog_log)
    for i in 1 2 3 5 6 7
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


    # here, mount /opt partition disk, by diwen
    # sdx5 -> /opt/program/bin
    # sdx6 -> /opt/program/etc
    # sdx7 -> /opt/program/log
    echo "try to create /opt/program/xxx ..."
    [ ! -d "$ROOT_PATH/opt/program/bin" ] && { mkdir -p $ROOT_PATH/opt/program/bin; }
    [ ! -d "$ROOT_PATH/opt/program/etc" ] && { mkdir -p $ROOT_PATH/opt/program/etc; }
    [ ! -d "$ROOT_PATH/opt/program/log" ] && { mkdir -p $ROOT_PATH/opt/program/log; }
    echo "try to mount /opt/program/xxx partition ..."
    mount_part ${DEVICE}5 $ROOT_PATH/opt/program/bin || return 1
    mount_part ${DEVICE}6 $ROOT_PATH/opt/program/etc || return 1
    mount_part ${DEVICE}7 $ROOT_PATH/opt/program/log || return 1


    log "copy root system ..."
    local root_list=(bin lib64 opt usr etc lib sbin tmp var home)
    for path in ${root_list[@]}
    do
        log "cp -ar /${path} $ROOT_PATH"
        if [ -d "/${path}" ]; then
            cp -ar /${path} $ROOT_PATH
        fi
    done

    # del the net card file
    [ -f "$ROOT_PATH/etc/udev/rules.d/70-persistent-net.rules" ] && { rm -rf $ROOT_PATH/etc/udev/rules.d/70-persistent-net.rules; }

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

    log "copy boot system ..."
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
        -g|--grub)
            grub_rework
            shift
            ;;
        -c|--cut)
            cut_out_system
            exit 1
            shift
            ;;
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
        SYSTEM_PATH=${TMP_PATH}/system
        umount_part $ROOT_PATH/opt/system || exit 1
        umount_part $ROOT_PATH || exit 1
        umount_part $BOOT_PATH || exit 1
        umount_part $SYSTEM_PATH || exit 1
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

    cut_out_system
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
    grub_rework
    install_manager_system
    deal_system_conf
    capture_version_and_system_info
    initrd_repack
    exit 0
#fi
