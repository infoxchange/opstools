checkrestart
------------

This is a Nagios plugin for Debian or RedHat Linux to check for processes that should be restarted, on the grounds that they are using libraries or other files which have since been updated eg. after security updates have been applied.

This plugin is derived from the Python script 'checkrestart' from the Debian package debian-goodies, with the following patch from Tiger Computing applied:

[https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=568359]
(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=568359)

plus subsequent modifications to provide more useful detail in the Nagios output, and provide compatability with RPM-based distributions

### Requires
* dpkg-based (Debian/Ubuntu) or rpm-based (RedHat/CentOS/SuSE) Linux distribution
* Python

## Sample Output

When all is good...

```
	Obsolete files used by: 0 processes, 0 packages, 0 ports:
```

When all is not good...

```
Obsolete files used by: 29 processes, 15 packages, 19 ports: nfs-common(UDP:49947 60371 UDP:54756 50045) rpcbind(UDP:111 UDP:955 111) bind9(53 UDP:53) openssh-server(22) ntp(UDP:123) ... udev cron at rsyslog util-linux ruby1.9.1 bash
```
Up to 5 packages with listening ports are listed. The ellipsis '...' indicates that some information has been omitted for brevity. 

Affected TCP ports are listed with no prefix, and UDP ports are prefixed with 'UDP:'

Next, up to 5 packages are listed that have running processes, but have no ports open, and do have a corresponding init script (eg. cron in the example below).

Lastly, up to 5 packages are listed that have running processes, but no ports open and no init script. (eg. 
bash in the example below).

Processes that are not associated with a package are counted in the N processes message, but are not listed (eg. a process from /usr/local/bin)

No performance data is included in the output.

When a newer kernel is installed than the currently running kernel (ie a reboot is required):
```
Kernel installed 3.2.65-1+deb7u2 running 3.2.65-1+deb7u1, Obsolete files used by: 0 processes, 0 packages, 0 ports:
```

## Usage

This should be run using NRPE, and requires root privilges to give complete coverage.

Sample Nagios config

```
define service {
  use                            generic-service-quiet          ; template name
  service_description            checkrestart
  hostgroup_name                 linux-servers                  ; hostgroup name
  check_command                  check_nrpe_1arg!checkrestart -t 30
}
```

`nrpe.cfg` config

```
command[checkrestart]=/usr/bin/sudo /usr/lib/nagios/plugins/checkrestart --nagios -b /usr/lib/nagios/plugins/ixa/checkrestart.blacklist
```

`/etc/sudoers` config

```
Defaults:nagios !requiretty
nagios	ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins/checkrestart
```
