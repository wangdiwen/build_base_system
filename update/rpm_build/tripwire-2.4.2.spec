#
# Example of spec file for rpm build
#

Summary: Tripwire Program
Name: tripwire
Version: 2.4.2
Release: 1.el5
License: GPL
Group: Application/System
Vendor: Vmediax.com
Source: tripwire-2.4.2.tar.gz
URL: http://vmediax.com/download/tripwire-2.4.2.tar.gz
Distribution: CentOS 5.9
Packager: wangdiwen <wangdiwen@vmediax.com>
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Prefix: /usr/local

%define install_path /usr/local/
%define sbin_path /usr/local/sbin
%define etc_path /usr/local/etc
%define lib_path /usr/local/lib/tripwire/report
%define package_name tripwire-2.4.2

%description
Tripwire software can help to ensure the integrity of critical system files and directories by identifying all changes made to them. Tripwire configuration options include the ability to receive alerts via email if particulr files are altered and automated integrity checking via a cron job. Using tripwire for insrusion detection and damage assessment helps you keep track of system changes and can speed the recovery from a break-in by reducing the number of files you must restore to repair the system.

%prep
#%setup
#setup -q
#setup -c %{name}-%{version}

#%patch

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{install_path}
mkdir -p $RPM_BUILD_ROOT%{sbin_path}
mkdir -p $RPM_BUILD_ROOT%{etc_path}
mkdir -p $RPM_BUILD_ROOT%{lib_path}

cp -a %{package_name}/sbin/* $RPM_BUILD_ROOT%{sbin_path}
cp -a %{package_name}/etc/* $RPM_BUILD_ROOT%{etc_path}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%{install_path}

%defattr(-, root, root)

%preun
%changelog
