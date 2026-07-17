# tlshd image for OpenShift 4.21

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

## Building the image

In order to build this image, you will need an active Red Hat subscription.

### Building on RHEL/Fedora

If you are building under RHEL/Fedora, you need to manage subscriptions on your host rather than in the container. If you're running RHEL and your system is already subscribed, you can run:

```sh
podman build . -t tlshd
```

If your system is not yet registered, the simplest solution may be to acquire an activation key as described in the following section, and then run:

```sh
subscription-manager register --org="$(cat rhel-org-id)" --activationkey="$(cat rhel-activation-key)"
```

Once your system has been successfully registered, build the image:

```sh
podman build . -t tlshd
```

### Building elsewhere

The easiest way to build on non-RHEL/Fedora environments is to use a Red Hat activation key. You can acquire one from <https://console.redhat.com/insights/connector/activation-keys> assuming you have the appropriate entitlements.

1. Place the Red Hat organization id in a file named `rhel-org-id`
2. Place the activation key in a file named `rhel-activation-key`
3. Run:

    ```
    podman build . -t tlshd \
      --secret id=rhel-org-id,src=rhel-org-id \
      --secret id=rhel-activation-key,src=rhel-activation-key
    ```

    (Or similarly if you're using Docker)
