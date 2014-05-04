#!/bin/sh

base_dir=/home/diwen/work/base_system
build_dir=/usr/src/redhat/BUILD
rpm_dir=/usr/src/redhat/RPMS/x86_64

# copy the source
echo ""
echo "copy the restful-server and web-frontend source..."
cp -a $base_dir/restful-server $build_dir
cp -a $base_dir/web-frontend $build_dir

# clear .svn and pyc file
echo ""
echo "clear the .svn and pyc file..."
find $build_dir -name "*.svn" | xargs rm -rf
find $build_dir -name "*.pyc" | xargs rm -f

# build 
echo ""
echo "rpm build... Pls wait..."
rpmbuild -bb restful-server.spec >/dev/null 2>&1
if [ $? -ne 0 ];then
	echo "build restful failed !"
	exit 1
fi
rpmbuild -bb web-frontend.spec >/dev/null 2>&1
if [ $? -ne 0 ];then
	echo "build web-frontend failed !"
	exit 1
fi

# copy the rpm to svn
echo ""
echo "copy the rpm to update svn tools dir..."
cp $rpm_dir/restful-server-*.x86_64.rpm $base_dir/update/tools 
cp $rpm_dir/web-frontend-*-1.el5.x86_64.rpm $base_dir/update/tools 

# tips
echo ""
echo "Now, Everything is OK..."
echo "Good, Luck!"
