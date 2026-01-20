# Dockerfile - Wolfi (glibc-based, small, up-to-date)
FROM cgr.dev/chainguard/wolfi-base:latest

# Switch to root for package installation
USER root

# Basis-System (Wolfi uses glibc - no compatibility issues with mise/chezmoi)
RUN apk add --no-cache \
  zsh \
  bash \
  git \
  curl \
  wget \
  ca-certificates \
  openssh-client \
  gnupg \
  sudo \
  shadow \
  glibc-locale-posix

# Entwickler-Tools
RUN apk add --no-cache \
  neovim \
  tmux \
  ripgrep \
  fd \
  fzf \
  bat

# Python für deine Backend-Projekte
RUN apk add --no-cache \
  python3 \
  py3-pip \
  python3-dev \
  build-base \
  libffi-dev \
  openssl-dev

# Node.js (für LazyVim LSP-Server)
RUN apk add --no-cache nodejs npm

# Kubernetes-Tools
RUN apk add --no-cache kubectl helm

# AWS CLI
RUN apk add --no-cache aws-cli

# Terraform
RUN apk add --no-cache terraform

# Docker CLI (für Docker-in-Docker mit Homelab)
RUN apk add --no-cache docker-cli

# User-Setup (wichtig für Volume-Permissions)
ARG USERNAME=alex
ARG USER_UID=1000
ARG USER_GID=1000

RUN addgroup -g $USER_GID $USERNAME && \
  adduser -D -u $USER_UID -G $USERNAME -s /bin/zsh $USERNAME && \
  mkdir -p /etc/sudoers.d && \
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
  chmod 440 /etc/sudoers.d/$USERNAME && \
  mkdir -p /home/$USERNAME && \
  chown -R $USERNAME:$USERNAME /home/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME

# Create directories needed by containerEnv
RUN mkdir -p /home/$USERNAME/.cache/tmp /home/$USERNAME/.local/bin

# Set PATH early so tools installed by pip are found
ENV PATH="/home/$USERNAME/.local/bin:$PATH"
ENV EDITOR=nvim
ENV TMPDIR="/home/$USERNAME/.cache/tmp"

# Mise für Tool-Management
RUN curl https://mise.run | sh && \
  echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc

# Chezmoi für deine Dotfiles
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /home/$USERNAME/.local/bin

# LazyVim Setup
RUN git clone https://github.com/LazyVim/starter ~/.config/nvim && \
  nvim --headless "+Lazy! sync" +qa

# Python-Tools
RUN pip3 install --user --no-cache-dir --break-system-packages \
  uv \
  ruff \
  black \
  pytest \
  httpie

# Beads - AI-native issue tracking
RUN curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

CMD ["/bin/zsh"]
