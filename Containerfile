FROM registry.access.redhat.com/ubi9/ubi

RUN --mount=type=secret,id=rhel-org-id \
    --mount=type=secret,id=rhel-activation-key \
    if [ -s /run/secrets/rhel-activation-key ]; then \
      subscription-manager register \
        --org="$(cat /run/secrets/rhel-org-id)" \
        --activationkey="$(cat /run/secrets/rhel-activation-key)"; \
    fi && \
    dnf install -y ktls-utils && \
    dnf clean all && \
    if [ -s /run/secrets/rhel-activation-key ]; then \
      subscription-manager unregister; \
    fi

CMD ["/usr/sbin/tlshd", "-s"]
