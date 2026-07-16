Enable nfs-over-tls on OpenShift 4.21.x. OpenShift 4.21 is based on RHEL 9.6:

```sh
sh-5.1# cat /host/etc/os-release
NAME="Red Hat Enterprise Linux CoreOS"
VERSION="9.6.20260504-0 (Plow)"
ID="rhel"
ID_LIKE="fedora"
VERSION_ID="9.6"
PLATFORM_ID="platform:el9"
PRETTY_NAME="Red Hat Enterprise Linux CoreOS 9.6.20260504-0 (Plow)"
ANSI_COLOR="0;31"
LOGO="fedora-logo-icon"
CPE_NAME="cpe:/o:redhat:enterprise_linux:9::baseos"
HOME_URL="https://www.redhat.com/"
DOCUMENTATION_URL="https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9"
BUG_REPORT_URL="https://issues.redhat.com/"
REDHAT_BUGZILLA_PRODUCT="Red Hat Enterprise Linux 9"
REDHAT_BUGZILLA_PRODUCT_VERSION=9.6
REDHAT_SUPPORT_PRODUCT="Red Hat Enterprise Linux"
REDHAT_SUPPORT_PRODUCT_VERSION="9.6"
OSTREE_VERSION='9.6.20260504-0'
VARIANT=CoreOS
VARIANT_ID=coreos
OPENSHIFT_VERSION="4.21"
```

This repository builds a container image containing `tlshd` from RHEL 9.6.
