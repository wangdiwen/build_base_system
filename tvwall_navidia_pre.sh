#!/bin/bash

echo
echo "Use VMediaX RPM REPO ..."
# ======= use yum-repo.vmediax.com rpm source ==========
[ -f "/etc/yum.repos.d/CentOS-Base.repo" ] && {
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
}
cp ./update/data/VMediaX.repo /etc/yum.repos.d/

yum clean all
sleep 2

echo
echo "Add Old driver to blacklist ..."
[ -f /etc/modprobe.d/blacklist.conf ] && {
    grep -q "nouveau" /etc/modprobe.d/blacklist.conf
    [ "$?" != "0" ] && {
        echo -e "# nouveau Navida driver\nblacklist nouveau" >> /etc/modprobe.d/blacklist.conf
    }
}
echo "Rebuild the initramfs image ..."
mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak
dracut -v /boot/initramfs-$(uname -r).img $(uname -r)
sleep 2

echo
echo "Install compile module ..."
yum -y install gcc kernel-devel make

echo
echo "Now, Prepare is OK, "
echo "You must reboot the system, and then"
echo "Run the Navida_xxx.run driver !"

# other dependency pkg
# cloog-ppl cpp glibc-devel glibc-headers kernel-headers libgomp mpfr ppl
