#
# Example of spec file for rpm build
#

Summary: Jdk Program
Name: jdk
Version: 1.0
Release: 1.el5
License: LGPL
Group: Application/System
Vendor: Vmediax.com
Source: jdk
URL: http://vmediax.com/download/jdk.tar.gz
Distribution: CentOS 5.9 x86_64
Packager: wangdiwen <wangdiwen@vmediax.com>
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Prefix: /opt/program

%define install_path		/opt/program
%define bin_path			/opt/program/bin
%define etc_path			/opt/program/etc
%define package_name		jdk

%description
This is java run env of TVwall frontend, we call it jdk.
Developed by develop-1@vmediax.com, and packaged by wangdiwen@vmediax.com.

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
mkdir -p $RPM_BUILD_ROOT%{etc_path}

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
