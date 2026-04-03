FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    jq \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-pip \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Create a runner user
RUN useradd -m -s /bin/bash runner \
    && usermod -aG sudo runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create GitHub-compatible workspace structure as root
RUN mkdir -p /github/workspace && \
    chown -R runner:runner /github /github/workspace


# Switch to runner user and set working directory to GitHub Actions workspace
USER runner
WORKDIR /github/workspace

# Download and install GitHub Actions runner
ARG RUNNER_ARCH=arm64
RUN RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//') \
    && echo "Installing GitHub Actions Runner version: $RUNNER_VERSION" \
    && curl -o actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && rm actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && sudo ./bin/installdependencies.sh

# Copy our startup script
COPY --chown=runner:runner start.sh /github/workspace/start.sh
RUN chmod +x /github/workspace/start.sh

CMD ["/github/workspace/start.sh"]