#
# Example of spec file for rpm build
#

Summary: TV-Wall Backend Program
Name: tvwall
Version: 1.0
Release: 1.el5
License: LGPL
Group: Application/System
Vendor: Vmediax.com
Source: tvwall
URL: http://vmediax.com/download/tvwall.tar.gz
Distribution: CentOS 5.9 x86_64
Packager: wangdiwen <wangdiwen@vmediax.com>
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Prefix: /

%define config_path			/etc/rc.d/init.d
%define install_path		/opt/program
%define bin_path			/opt/program/bin
%define etc_path			/opt/program/etc
%define package_name		tvwall

%description
Welcome to use TV Wall software of vmediax.com company, it works on CentOS5.9 x86_64 system,
Developed by sunpu@vmediax.com, and packaged by wangdiwen@vmediax.com.

%prep
#%setup
#setup -q
#setup -c %{name}-%{version}

#%patch

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{config_path}
mkdir -p $RPM_BUILD_ROOT%{install_path}
mkdir -p $RPM_BUILD_ROOT%{bin_path}
mkdir -p $RPM_BUILD_ROOT%{etc_path}

cp -a %{package_name}/tvwall $RPM_BUILD_ROOT%{config_path}
cp -a %{package_name}/bin/* $RPM_BUILD_ROOT%{bin_path}
cp -a %{package_name}/etc/* $RPM_BUILD_ROOT%{etc_path}

%clean
rm -rf $RPM_BUILD_ROOT

%post

%preun

%files
%{install_path}

%defattr(-, root, root)

%changelog
