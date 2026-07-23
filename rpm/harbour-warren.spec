Name:       harbour-warren
Summary:    A colony idle game for Sailfish OS
Version:    0.5.0
Release:    1
Group:      Applications/Amusements
License:    MIT
URL:        https://github.com/nicosouv/harbour-warren
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Sql)
BuildRequires:  desktop-file-utils

%description
Warren is a colony idle game. Start with a handful of badgers and a hole in the ground: forage,
build, mine, keep the lights on, raise an army and raid your neighbours. A narrator judges you
throughout. Fully offline: no ads, no account, no telemetry.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5 "VERSION=%{version}"
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
%qmake5_install

desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_datadir}/dbus-1/services/harbour.warren.service
