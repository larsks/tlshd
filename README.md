# Enabling NFS over TLS on OpenShift 4.21

Many environments require encryption-in-transit for data moving between storage devices and compute nodes. If you are relying on NFS for network storage, an attractive option is NFS-over-TLS. This is not officially supported in OpenShift 4.21, but we can make it work. This repository provides an image that will run the necessary userspace components to get NFS-over-TLS working on OpenShift 4.21.

## History

While NFS and TLS are both relatively ancient technologies, they have only recently learned how to play well together:

- [RFC 9289](https://datatracker.ietf.org/doc/rfc9289/), which standardized NFS-over-TLS, was introduced in 2022.
- Linux support for RPC-over-TLS was introduced [in 2022](https://lore.kernel.org/all/165030062272.5246.16956092606399079004.stgit@oracle-102.nfsv4.dev/)
- Linux support for a user-space TLS listener to handle handshakes was introduced [in 2023](https://lore.kernel.org/all/167398608926.5631.13511197621584108600.stgit@91.116.238.104.host.secureserver.net/)
- Linux client support for NFS-over-TLS was introduced [in 2023](https://lore.kernel.org/linux-nfs/168545533442.1917.10040716812361925735.stgit@oracle-102.nfsv4bat.org/) and was merged in commit [dfab92f](https://github.com/torvalds/linux/commit/dfab92f27c600fea3cadc6e2cb39f092024e1fef), landing in Kernel 6.5. 

## Alternatives

Without NFS-over-TLS support, your options for encrypting NFS traffic are limited:

- You can make use of Kerberos privacy extensions, but this requires processes to have a valid Kerberos ticket in order to access the storage. Setting up a Kerberos infrastructure is an additional level of complication, and figuring out how to make this work in an environment like OpenShift is left as an exercise to the reader.
- You could connect to your storage over a TLS tunnel, but that has performance implications and may be difficult to achieve with vendor CSI drivers.

## Support on OpenShift

OpenShift 4.21 is built on RHCOS 9.6, which like RHEL 9.6 is using kernel 5.14, which might sound like we are out of luck. Fortunately, Red Hat has backported the NFS-over-TLS support to RHEL 9 (9.6 and later). The default RHCOS images used by OpenShift include the necessary kernel components, but do not include the user-space `tlshd` daemon that handles the TLS handshake.

The simplest way of resolving this is to spawn a [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/) that runs a pod with appropriate privileges on every node in the cluster. That is the solution implemented in this repository.

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

If you are running Docker rather than Podman, the command line will be similar.

## Validation

We can verify that our cluster is communicating with the storage server over a TLS connection by capturing a packet trace: 

```sh
tcpdump -i any -nn -w packets -s0 host 10.8.0.9 and port 2049
```

In the following output from `tshark -nn -r packets`, we can clearly see the TLS handshake and data subsequently transferring over the TLS channel.

```
    1   0.000000    10.8.0.20 → 10.8.0.9     TCP 80 810 → 2049 [SYN] Seq=0 Win=62720 Len=0 MSS=8960 SACK_PERM TSval=3035995703 TSecr=0 WS=128
    2   0.000133     10.8.0.9 → 10.8.0.20    TCP 80 2049 → 810 [SYN, ACK] Seq=0 Ack=1 Win=62636 Len=0 MSS=8960 SACK_PERM TSval=3506682772 TSecr=3035995703 WS=512
    3   0.000200    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=1 Ack=1 Win=62720 Len=0 TSval=3035995703 TSecr=3506682772
    4   0.000311    10.8.0.20 → 10.8.0.9     NFS 116 V4 NULL Call
    5   0.000364     10.8.0.9 → 10.8.0.20    TCP 72 2049 → 810 [ACK] Seq=1 Ack=45 Win=62976 Len=0 TSval=3506682772 TSecr=3035995703
    6   0.000425     10.8.0.9 → 10.8.0.20    NFS 108 V4 NULL Reply (Call In 4)
    7   0.000449    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=45 Ack=37 Win=62720 Len=0 TSval=3035995703 TSecr=3506682772
    8   0.304613    10.8.0.20 → 10.8.0.9     TLSv1.3 423 Client Hello (SNI=10.8.0.9)
    9   0.307528     10.8.0.9 → 10.8.0.20    TLSv1.3 1785 Server Hello, Change Cipher Spec, Application Data, Application Data, Application Data, Application Data, Application Data
   10   0.307578    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=396 Ack=1750 Win=61056 Len=0 TSval=3035996010 TSecr=3506683079
   11   0.308705    10.8.0.20 → 10.8.0.9     TLSv1.3 78 Change Cipher Spec
   12   0.311505    10.8.0.20 → 10.8.0.9     TLSv1.3 176 Application Data, Application Data
   13   0.311634     10.8.0.9 → 10.8.0.20    TCP 72 2049 → 810 [ACK] Seq=1750 Ack=506 Win=62976 Len=0 TSval=3506683083 TSecr=3035996011
   14   0.312115    10.8.0.20 → 10.8.0.9     TLSv1.3 138 Application Data
   15   0.312232     10.8.0.9 → 10.8.0.20    TLSv1.3 122 Application Data
   16   0.352786    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=572 Ack=1800 Win=61056 Len=0 TSval=3035996056 TSecr=3506683084
   17   0.394870    10.8.0.20 → 10.8.0.9     TCP 80 47490 → 2049 [SYN] Seq=0 Win=62720 Len=0 MSS=8960 SACK_PERM TSval=3035996098 TSecr=0 WS=128
   18   0.394995     10.8.0.9 → 10.8.0.20    TCP 80 2049 → 47490 [SYN, ACK] Seq=0 Ack=1 Win=62636 Len=0 MSS=8960 SACK_PERM TSval=2768233791 TSecr=3035996098 WS=512
   19   0.395054    10.8.0.20 → 10.8.0.9     TCP 72 47490 → 2049 [ACK] Seq=1 Ack=1 Win=62720 Len=0 TSval=3035996098 TSecr=2768233791
   20   0.396916    10.8.0.20 → 10.8.0.9     NFS 1044 V4 NULL Call
   21   0.396968     10.8.0.9 → 10.8.0.20    TCP 72 2049 → 47490 [ACK] Seq=1 Ack=973 Win=73216 Len=0 TSval=2768233793 TSecr=3035996100
   22   0.397992     10.8.0.9 → 10.8.0.20    NFS 156 V4 NULL Reply (Call In 20)
   23   0.398035    10.8.0.20 → 10.8.0.9     TCP 72 47490 → 2049 [ACK] Seq=973 Ack=85 Win=62720 Len=0 TSval=3035996101 TSecr=2768233794
   24   0.398533    10.8.0.20 → 10.8.0.9     TCP 72 47490 → 2049 [FIN, ACK] Seq=973 Ack=85 Win=62720 Len=0 TSval=3035996101 TSecr=2768233794
   25   0.398621    10.8.0.20 → 10.8.0.9     TLSv1.3 478 Application Data
   26   0.398688     10.8.0.9 → 10.8.0.20    TCP 72 2049 → 47490 [FIN, ACK] Seq=85 Ack=974 Win=73216 Len=0 TSval=2768233794 TSecr=3035996101
   27   0.398736    10.8.0.20 → 10.8.0.9     TCP 72 47490 → 2049 [ACK] Seq=974 Ack=86 Win=62720 Len=0 TSval=3035996102 TSecr=2768233794
   28   0.399700     10.8.0.9 → 10.8.0.20    TLSv1.3 290 Application Data
   29   0.399752    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=978 Ack=2018 Win=60928 Len=0 TSval=3035996103 TSecr=3506683171
   30   0.400044    10.8.0.20 → 10.8.0.9     TLSv1.3 478 Application Data
   31   0.401487     10.8.0.9 → 10.8.0.20    TLSv1.3 290 Application Data
   32   0.401676    10.8.0.20 → 10.8.0.9     TLSv1.3 378 Application Data
   33   0.402095     10.8.0.9 → 10.8.0.20    TLSv1.3 290 Application Data
   34   0.402362    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   35   0.402498     10.8.0.9 → 10.8.0.20    TLSv1.3 254 Application Data
   36   0.402678    10.8.0.20 → 10.8.0.9     TLSv1.3 294 Application Data
   37   0.403022     10.8.0.9 → 10.8.0.20    TLSv1.3 270 Application Data
   38   0.403185    10.8.0.20 → 10.8.0.9     TLSv1.3 258 Application Data
   39   0.403415     10.8.0.9 → 10.8.0.20    TLSv1.3 370 Application Data
   40   0.403562    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   41   0.403767     10.8.0.9 → 10.8.0.20    TLSv1.3 242 Application Data
   42   0.403846    10.8.0.20 → 10.8.0.9     TLSv1.3 286 Application Data
   43   0.404006     10.8.0.9 → 10.8.0.20    TLSv1.3 250 Application Data
   44   0.404087    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   45   0.404301     10.8.0.9 → 10.8.0.20    TLSv1.3 242 Application Data
   46   0.404432    10.8.0.20 → 10.8.0.9     TLSv1.3 286 Application Data
   47   0.404584     10.8.0.9 → 10.8.0.20    TLSv1.3 250 Application Data
   48   0.404654    10.8.0.20 → 10.8.0.9     TLSv1.3 282 Application Data
   49   0.404783     10.8.0.9 → 10.8.0.20    TLSv1.3 214 Application Data
   50   0.405062    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   51   0.405228     10.8.0.9 → 10.8.0.20    TLSv1.3 242 Application Data
   52   0.405317    10.8.0.20 → 10.8.0.9     TLSv1.3 286 Application Data
   53   0.405466     10.8.0.9 → 10.8.0.20    TLSv1.3 330 Application Data
   54   0.405588    10.8.0.20 → 10.8.0.9     TLSv1.3 294 Application Data
   55   0.405733     10.8.0.9 → 10.8.0.20    TLSv1.3 266 Application Data
   56   0.405820    10.8.0.20 → 10.8.0.9     TLSv1.3 350 Application Data
   57   0.406164     10.8.0.9 → 10.8.0.20    TLSv1.3 378 Application Data
   58   0.406386    10.8.0.20 → 10.8.0.9     TLSv1.3 350 Application Data
   59   0.406775     10.8.0.9 → 10.8.0.20    TLSv1.3 378 Application Data
   60   0.407095    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   61   0.407487     10.8.0.9 → 10.8.0.20    TLSv1.3 242 Application Data
   62   0.407631    10.8.0.20 → 10.8.0.9     TLSv1.3 286 Application Data
   63   0.407804     10.8.0.9 → 10.8.0.20    TLSv1.3 250 Application Data
   64   0.407941    10.8.0.20 → 10.8.0.9     TLSv1.3 282 Application Data
   65   0.408130     10.8.0.9 → 10.8.0.20    TLSv1.3 214 Application Data
   66   0.408427    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   67   0.408630     10.8.0.9 → 10.8.0.20    TLSv1.3 242 Application Data
   68   0.408778    10.8.0.20 → 10.8.0.9     TLSv1.3 286 Application Data
   69   0.408944     10.8.0.9 → 10.8.0.20    TLSv1.3 330 Application Data
   70   0.449775    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=5674 Ack=6122 Win=57728 Len=0 TSval=3035996153 TSecr=3506683180
   71   0.450305    10.8.0.20 → 10.8.0.9     TLSv1.3 286 Application Data
   72   0.450536     10.8.0.9 → 10.8.0.20    TLSv1.3 258 Application Data
   73   0.450622    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=5888 Ack=6308 Win=57600 Len=0 TSval=3035996153 TSecr=3506683222
   74   0.474839    10.8.0.20 → 10.8.0.9     TLSv1.3 282 Application Data
   75   0.475035     10.8.0.9 → 10.8.0.20    TLSv1.3 330 Application Data
   76   0.475189    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   77   0.475436     10.8.0.9 → 10.8.0.20    TLSv1.3 266 Application Data
   78   0.475593    10.8.0.20 → 10.8.0.9     TLSv1.3 306 Application Data
   79   0.475768     10.8.0.9 → 10.8.0.20    TLSv1.3 418 Application Data
   80   0.475992    10.8.0.20 → 10.8.0.9     TLSv1.3 290 Application Data
   81   0.476125     10.8.0.9 → 10.8.0.20    TLSv1.3 330 Application Data
   82   0.476231    10.8.0.20 → 10.8.0.9     TLSv1.3 298 Application Data
   83   0.476407     10.8.0.9 → 10.8.0.20    TLSv1.3 266 Application Data
   84   0.476533    10.8.0.20 → 10.8.0.9     TLSv1.3 314 Application Data
   85   0.476752     10.8.0.9 → 10.8.0.20    TLSv1.3 210 Application Data
   86   0.476902    10.8.0.20 → 10.8.0.9     TLSv1.3 342 Application Data
   87   0.477138     10.8.0.9 → 10.8.0.20    TLSv1.3 202 Application Data
   88   0.477341    10.8.0.20 → 10.8.0.9     TLSv1.3 330 Application Data
   89   0.477493     10.8.0.9 → 10.8.0.20    TLSv1.3 202 Application Data
   90   0.477665    10.8.0.20 → 10.8.0.9     TLSv1.3 334 Application Data
   91   0.478078     10.8.0.9 → 10.8.0.20    TLSv1.3 358 Application Data
   92   0.478208    10.8.0.20 → 10.8.0.9     TLSv1.3 322 Application Data
   93   0.478651     10.8.0.9 → 10.8.0.20    TLSv1.3 358 Application Data
   94   0.518753    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=8276 Ack=8528 Win=55680 Len=0 TSval=3035996222 TSecr=3506683250
   95   7.863550    10.8.0.20 → 10.8.0.9     TLSv1.3 286 Application Data
   96   7.863827     10.8.0.9 → 10.8.0.20    TLSv1.3 258 Application Data
   97   7.863897    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=8490 Ack=8714 Win=55552 Len=0 TSval=3036003567 TSecr=3506690635
   98  13.574403    10.8.0.20 → 10.8.0.9     TLSv1.3 298 Application Data
   99  13.574974     10.8.0.9 → 10.8.0.20    TLSv1.3 266 Application Data
  100  13.575042    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=8716 Ack=8908 Win=55424 Len=0 TSval=3036009278 TSecr=3506696346
  101  15.613858    10.8.0.20 → 10.8.0.9     TLSv1.3 406 Application Data
  102  15.614931     10.8.0.9 → 10.8.0.20    TLSv1.3 458 Application Data
  103  15.614992    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=9050 Ack=9294 Win=55040 Len=0 TSval=3036011318 TSecr=3506698386
  104  15.618428    10.8.0.20 → 10.8.0.9     TLSv1.3 358 Application Data
  105  15.619106     10.8.0.9 → 10.8.0.20    TLSv1.3 282 Application Data
  106  15.619361    10.8.0.20 → 10.8.0.9     TLSv1.3 314 Application Data
  107  15.619611     10.8.0.9 → 10.8.0.20    TLSv1.3 274 Application Data
  108  15.659774    10.8.0.20 → 10.8.0.9     TCP 72 810 → 2049 [ACK] Seq=9578 Ack=9706 Win=54784 Len=0 TSval=3036011363 TSecr=3506698391
   .
   .
   .
```

## Deploying on OpenShift

The [deploy](deploy/) directory contains [Kustomize] manifests for deploying this image. These manifests are built for the Mass Open Cloud environment, which includes an Everpure storage appliance. You will need to update the manifests to include an appropriate TLS certificate for your storage server, and you will need to modify the StorageClass to make it appropriate for your environment.

Once the manifests have been configured to your liking, you can deploy everything by running:

```
oc deploy -k deploy
```

This will start a `tlshd` pod in the `tlshd` namespace.

[kustomize]: https://kustomize.io/
