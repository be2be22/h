# =============================================================================
# Dockerfile — 3x-ui (Farsi) + Xray VLESS-WS for Defang.io
# Single-port deployment (HTTP/WebSocket multiplexing via Nginx reverse proxy)
# =============================================================================
FROM mhsanaei/3x-ui:latest

LABEL maintainer="Cloud Engineer & DevOps Specialist"
LABEL description="3x-ui Farsi panel + Xray (VLESS-WS / Trojan-WS) optimized for Defang.io"
LABEL version="1.0.0"

USER root

# -----------------------------------------------------------------------------
# Install system dependencies: Nginx (reverse proxy), Supervisor (process mgr),
# sqlite3 (DB manipulation for panel settings), curl (healthchecks), openssl
# (random password generation), tzdata (Asia/Tehran timezone).
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        sqlite3 \
        curl \
        openssl \
        bash \
        tzdata \
        ca-certificates \
    && ln -fs /usr/share/zoneinfo/Asia/Tehran /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Create required runtime directories
# -----------------------------------------------------------------------------
RUN mkdir -p \
        /run/nginx \
        /var/log/nginx \
        /var/log/supervisor \
        /var/log/xray \
        /var/www/fake \
        /etc/x-ui

# -----------------------------------------------------------------------------
# Copy configuration files into the image
# -----------------------------------------------------------------------------
COPY nginx.conf          /etc/nginx/nginx.conf
COPY supervisord.conf    /etc/supervisord.conf
COPY init.sh             /init.sh
COPY config.json         /etc/x-ui/config-template.json
COPY fake-page.html      /var/www/fake/index.html

# Ensure init script is executable
RUN chmod +x /init.sh

# -----------------------------------------------------------------------------
# Expose ONLY the main HTTP port (Defang single-port constraint).
# Defang's load balancer terminates TLS and forwards plain HTTP to this port.
# -----------------------------------------------------------------------------
EXPOSE 80

# -----------------------------------------------------------------------------
# Health check — verifies Nginx is serving on port 80
# -----------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
    CMD curl -sf http://localhost/ || exit 1

# -----------------------------------------------------------------------------
# Entrypoint: configure 3x-ui (credentials, port, template) then hand off
# to supervisord which manages both Nginx and 3x-ui.
# -----------------------------------------------------------------------------
ENTRYPOINT ["/init.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
