#
# Example of spec file for rpm build
#

Summary: python27 Program
Name: python27
Version: 2.7
Release: 1.el5
License: GPL
Group: Application/System
Vendor: Vmediax.com
Source: python27.tar.gz
URL: http://vmediax.com/download/tripwire-2.4.2.tar.gz
Distribution: CentOS 5.9
Packager: wangdiwen <wangdiwen@vmediax.com>
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Prefix: /usr

%define install_path		/usr
%define bin_path			/usr/bin
%define include_path		/usr/include
%define lib_path			/usr/lib
%define share_path			/usr/share
%define package_name		python27

%description
This rpm package is python2.7 program, it gives python environment for web manager tool, and it has third party python lib, like ifconfig tools that parse the linux command like "ifconfig eth0".
Good luck!

%prep
#%setup
#setup -q
#setup -c %{name}-%{version}

#%patch

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{install_path}
mkdir -p $RPM_BUILD_ROOT%{bin_path}
mkdir -p $RPM_BUILD_ROOT%{include_path}
mkdir -p $RPM_BUILD_ROOT%{lib_path}
mkdir -p $RPM_BUILD_ROOT%{share_path}

cp -a %{package_name}/bin/* $RPM_BUILD_ROOT%{bin_path}
rm -f $RPM_BUILD_ROOT%{bin_path}/pydoc
rm -f $RPM_BUILD_ROOT%{bin_path}/python
rm -f $RPM_BUILD_ROOT%{bin_path}/python2
cp -a %{package_name}/include/* $RPM_BUILD_ROOT%{include_path}
cp -a %{package_name}/lib/* $RPM_BUILD_ROOT%{lib_path}
cp -a %{package_name}/share/* $RPM_BUILD_ROOT%{share_path}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%{install_path}
%exclude

%defattr(-, root, root)

%preun
%changelog
