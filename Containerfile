FROM registry.access.redhat.com/ubi9/ubi

RUN --mount=type=secret,id=rhel-org-id \
    --mount=type=secret,id=rhel-activation-key \
    subscription-manager register \
      --org="$(cat /run/secrets/rhel-org-id)" \
      --activationkey="$(cat /run/secrets/rhel-activation-key)" && \
    dnf install -y ktls-utils && \
    dnf clean all && \
    subscription-manager unregister

CMD ["/usr/sbin/tlshd", "-s"]
