FROM node:22-slim
 
# ---- OS packages -----------------------------------------------------------
# git       - most projects/tools Claude Code touches expect it
# ca-certificates / curl - TLS + fetching things at build/run time
# procps    - gives Claude Code access to `ps` etc. for process management
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
        procps \
        less \
        vim \
    && rm -rf /var/lib/apt/lists/*
 
# ---- Claude Code CLI --------------------------------------------------------
RUN npm install -g @anthropic-ai/claude-code
 
# ---- pnpm --------------------------------------------------------------------
# Node 22 ships Corepack, which manages package-manager versions without a
# separate global npm install. Pin a version so builds are reproducible
# rather than always resolving to whatever "latest" means that day.
RUN corepack enable && corepack prepare pnpm@9 --activate

# ---- Non-root user ----------------------------------------------------------
# Running as root inside a container that edits your host files via a bind
# mount will create root-owned files on the host. Use a regular user instead,
# and let docker-compose pass in matching UID/GID at build time if needed.
ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=1000

# UID:GID Collisions with USER_UID:USER_GID
RUN set -eux; \
    if getent group "${USER_GID}" >/dev/null; then \
        existing_group="$(getent group "${USER_GID}" | cut -d: -f1)"; \
        [ "${existing_group}" = "${USERNAME}" ] || groupmod -n "${USERNAME}" "${existing_group}"; \
    else \
        groupadd --gid "${USER_GID}" "${USERNAME}"; \
    fi; \
    if getent passwd "${USER_UID}" >/dev/null; then \
        existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
        if [ "${existing_user}" != "${USERNAME}" ]; then \
            usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m -g "${USER_GID}" "${existing_user}"; \
        fi; \
    else \
        useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}"; \
    fi
 
# Workspace is where your project will be mounted (see docker-compose.yml)
WORKDIR /workspace
RUN chown -R ${USERNAME}:${USERNAME} /workspace

# ---- Project scaffold templates ---------------------------------------------
# Baked in read-only reference copies of CLAUDE.md / .claude/commands/plan.md
# / .claude/settings.json. The entrypoint script seeds these into whatever
# gets bind-mounted at /workspace (PROJECT_PATH) on container start, but only
# for files that don't already exist there — see docker-entrypoint.sh.
COPY templates/project /opt/claude-templates/project
RUN chmod -R a+rX /opt/claude-templates
 
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER ${USERNAME}
 
# Persist Claude Code config/auth/history across container restarts by
# mounting a volume at $HOME/.claude (wired up in docker-compose.yml)
ENV HOME=/home/${USERNAME}
 

# ---- Global Claude Code instructions ---------------------------------------
# Baked into the image so every project gets these standing instructions
# (plan-first workflow, always-write-Vitest-tests, default permission
# judgment calls) without needing to repeat them per project. See
# claude-global/CLAUDE.md in this build context for the actual content.
#
# NOTE: docker-compose.yml mounts a volume at $HOME/.claude for persistence
# (see CLAUDE_CONFIG_PATH). Docker only seeds a *named volume* from the
# image's directory contents the first time that volume is created — after
# that, whatever's in the volume wins, so edits here won't retroactively
# reach a volume that already exists. If CLAUDE_CONFIG_PATH is set to a host
# path (bind mount) instead, the bind mount fully replaces this directory
# and this file won't be visible at all — copy it to that host path manually
# in that case.
# ---- -----------------------------------------------------------------------
RUN mkdir -p ${HOME}/.claude
COPY --chown=${USERNAME}:${USERNAME} claude-global/CLAUDE.md ${HOME}/.claude/CLAUDE.md


# The entrypoint script seeds missing scaffold files into /workspace
# CMD Keeps the container running so you can `docker compose exec` into it
# (from a terminal or from VS Code's Dev Containers extension) and run
# `claude` on demand, instead of the container running claude once and exiting.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sleep", "infinity"]