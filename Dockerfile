FROM mcr.microsoft.com/azure-cli:latest

# Add labels to link to GitHub repo
LABEL org.opencontainers.image.title="azuretunnel"
LABEL org.opencontainers.image.description="Image to tunnel through a bastion host to create a network tunnel to private aks clusters"
LABEL org.opencontainers.image.authors="Alex Rudolph"
LABEL org.opencontainers.image.url="https://github.com/Xander-Rudolph/azuretunnel"
LABEL org.opencontainers.image.source="https://github.com/Xander-Rudolph/azuretunnel"
LABEL org.opencontainers.image.documentation="https://github.com/Xander-Rudolph/azuretunnel#readme"
LABEL org.opencontainers.image.licenses="Apache2.0"

# Install necessary packages
RUN yum update -y && yum install -y \
    net-tools \
    jq \
    openssh-clients && \
    yum clean all
    
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
