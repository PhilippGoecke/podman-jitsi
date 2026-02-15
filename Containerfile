FROM debian:trixie AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=18

WORKDIR /build

# -----------------------------------------------------
# Install build dependencies
# -----------------------------------------------------
RUN apt update && apt install -y \
    git \
    curl \
    ca-certificates \
    build-essential \
    openjdk-17-jdk \
    maven \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------
# Install Node.js + Yarn
# -----------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt install -y nodejs && \
    npm install -g yarn

# -----------------------------------------------------
# Clone sources
# -----------------------------------------------------
RUN git clone https://github.com/jitsi/lib-jitsi-meet.git && \
    git clone https://github.com/jitsi/jitsi-meet.git && \
    git clone https://github.com/jitsi/jicofo.git && \
    git clone https://github.com/jitsi/jitsi-videobridge.git

# -----------------------------------------------------
# Build lib-jitsi-meet
# -----------------------------------------------------
WORKDIR /build/lib-jitsi-meet

RUN npm install && \
    npm run build

# -----------------------------------------------------
# Build jitsi-meet web
# -----------------------------------------------------
WORKDIR /build/jitsi-meet

RUN npm install && \
    make

# -----------------------------------------------------
# Build Jicofo
# -----------------------------------------------------
WORKDIR /build/jicofo

RUN mvn package -DskipTests

# -----------------------------------------------------
# Build Videobridge
# -----------------------------------------------------
WORKDIR /build/jitsi-videobridge

RUN mvn package -DskipTests


# =====================================================
# STAGE 2 — Runtime Image
# =====================================================
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt/jitsi

# -----------------------------------------------------
# Install runtime dependencies only
# -----------------------------------------------------
RUN apt update && apt install -y \
    openjdk-17-jre-headless \
    nginx \
    ffmpeg \
    ca-certificates \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------
# Copy build artifacts
# -----------------------------------------------------

# Web frontend
COPY --from=builder /build/jitsi-meet /opt/jitsi/jitsi-meet

# Jicofo
COPY --from=builder /build/jicofo/target/jicofo*.jar \
    /opt/jitsi/jicofo.jar

# Videobridge
COPY --from=builder /build/jitsi-videobridge/target/jitsi-videobridge*.jar \
    /opt/jitsi/jvb.jar

# -----------------------------------------------------
# Nginx configuration
# -----------------------------------------------------
RUN rm /etc/nginx/sites-enabled/default

COPY nginx.conf /etc/nginx/conf.d/jitsi.conf

# -----------------------------------------------------
# Create runtime user
# -----------------------------------------------------
RUN useradd -r -m -u 1000 jitsi && \
    chown -R jitsi:jitsi /opt/jitsi

USER jitsi

# -----------------------------------------------------
# Startup script
# -----------------------------------------------------
USER root

RUN cat << 'EOF' > /start.sh
#!/bin/bash
set -e

echo "[+] Starting Nginx..."
service nginx start

echo "[+] Starting Jicofo..."
java \
  -Xms512m \
  -Xmx1024m \
  -jar /opt/jitsi/jicofo.jar &

echo "[+] Starting Videobridge..."
java \
  -Xms1g \
  -Xmx2g \
  -jar /opt/jitsi/jvb.jar &

wait -n
EOF

RUN chmod +x /start.sh

# -----------------------------------------------------
# Network ports
# -----------------------------------------------------
EXPOSE 80 443 4443 10000/udp

# -----------------------------------------------------
# Launch
# -----------------------------------------------------
CMD ["/start.sh"]
