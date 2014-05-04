#
# Example of spec file for rpm build
#

Summary: Restful Server Program
Name: restful-server
Version: 1.0
Release: 1.el5
License: GPL
Group: Application/System
Vendor: Vmediax.com
Source: restful-server
URL: http://vmediax.com/download/tripwire-2.4.2.tar.gz
Distribution: CentOS 5.9
Packager: wangdiwen <wangdiwen@vmediax.com>
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Prefix: /

%define install_path		/
%define etc_path			/etc/rc.d/init.d
%define etc_path_conf		/opt/system/etc/rc.d/init.d
%define main_path			/usr/local/restful-server
%define common_path			/usr/local/restful-server/common
%define model_path			/usr/local/restful-server/model
%define conf_path			/opt/system/conf/restful-server
%define log_path			/opt/system/log/restful-server
%define package_name		restful-server

%description
This is restful server program, it gives some functions of web manager tools.

%prep
#%setup
#setup -q
#setup -c %{name}-%{version}

#%patch

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{install_path}
mkdir -p $RPM_BUILD_ROOT%{etc_path}
mkdir -p $RPM_BUILD_ROOT%{etc_path_conf}
mkdir -p $RPM_BUILD_ROOT%{common_path}
mkdir -p $RPM_BUILD_ROOT%{model_path}
mkdir -p $RPM_BUILD_ROOT%{conf_path}
mkdir -p $RPM_BUILD_ROOT%{log_path}

cp -a %{package_name}/restful-server.py $RPM_BUILD_ROOT%{main_path}
cp -a %{package_name}/restful-server $RPM_BUILD_ROOT%{etc_path}
cp -a %{package_name}/restful-server $RPM_BUILD_ROOT%{etc_path_conf}
cp -a %{package_name}/common/* $RPM_BUILD_ROOT%{common_path}
cp -a %{package_name}/model/* $RPM_BUILD_ROOT%{model_path}
cp -a %{package_name}/conf/auth_user $RPM_BUILD_ROOT%{conf_path}
cp -a %{package_name}/conf/install_log $RPM_BUILD_ROOT%{conf_path}
cp -a %{package_name}/conf/ntp_server $RPM_BUILD_ROOT%{conf_path}
cp -a %{package_name}/conf/rpm-secret-key $RPM_BUILD_ROOT%{conf_path}
cp -a %{package_name}/conf/startup $RPM_BUILD_ROOT%{conf_path}
cp -a %{package_name}/conf/restful.log $RPM_BUILD_ROOT%{log_path}

%clean
rm -rf $RPM_BUILD_ROOT

%pre
%post
# creatae soft link of start script
if [ ! -f $RPM_INSTALL_PREFIX/etc/rc.d/rc3.d/S90restful-server ];then
	/bin/ln -s ../init.d/restful-server $RPM_INSTALL_PREFIX/etc/rc.d/rc3.d/S90restful-server
fi
if [ ! -f $RPM_INSTALL_PREFIX/etc/rc.d/rc5.d/S90restful-server ];then
	/bin/ln -s ../init.d/restful-server $RPM_INSTALL_PREFIX/etc/rc.d/rc5.d/S90restful-server
fi
# set startup
#chkconfig --add restful-server

# create static route script
if [ ! -f $RPM_INSTALL_PREFIX/etc/sysconfig/static-routes ]; then
	touch $RPM_INSTALL_PREFIX/etc/sysconfig/static-routes
fi
# modify the network config file
sed -i "s/\(.*\)add -\$args$/\1add \$args/g" $RPM_INSTALL_PREFIX/etc/rc.d/init.d/network

%preun
# delete soft link of start script
# uninstall
if [ "$1" = "0" ];then
#chkconfig --del restful-server
#rm -rf $RPM_INSTALL_PREFIX%{main_path}
	rm -f $RPM_INSTALL_PREFIX/etc/rc.d/init.d/restful-server
	rm -f $RPM_INSTALL_PREFIX/etc/rc.d/rc3.d/S90restful-server
	rm -f $RPM_INSTALL_PREFIX/etc/rc.d/rc5.d/S90restful-server
fi

%postun
if [ -d /usr/local/restful-server ];then
	rm -rf /usr/local/restful-server
fi

%files
%{install_path}

%defattr(-, root, root)

%changelog
