FROM mcr.microsoft.com/azure-cli:2.50.0-ubuntu-20.04

# Install necessary packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    net-tools \
    jq \
    openssh-client && \
    rm -rf /var/lib/apt/lists/*
    
# Install aks tools
RUN az aks install-cli
# when querying bastion another extension is required
RUN az config set extension.use_dynamic_install=yes_without_prompt 
RUN az extension add --upgrade -n bastion

# Add the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default environment variables
ENV ENVIRONMENT=""
ENV REGION=""
ENV VM_PREFIX=""
ENV PORT=50081
ENV ROUTING_PORT=50080
ENV RESOURCE_SSH_PORT=22
ENV AZURE_CLIENT_ID=""
ENV AZURE_TENANT_ID=""
ENV AZURE_CLIENT_SECRET=""
ENV SUBSCRIPTION_ID=""
ENV USER=""

EXPOSE ${PORT} ${ROUTING_PORT}
# Set the entrypoint script to run when the container starts
ENTRYPOINT ["/entrypoint.sh"]
