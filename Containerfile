FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt upgrade -y \
  && apt install -y --no-install-recommends --no-install-suggests curl ca-certificates gnupg2 apt-transport-https \
  && rm -rf "/var/lib/apt/lists/*" \
  && rm -rf /var/cache/apt/archives

# Add Jitsi repository
RUN curl -sL https://download.jitsi.org/jitsi-key.gpg.key | gpg --dearmor -o /usr/share/keyrings/jitsi-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/" > /etc/apt/sources.list.d/jitsi-stable.list

# Install Jitsi Meet
RUN apt update \
  && apt install -y jitsi-meet \
  && rm -rf "/var/lib/apt/lists/*" \
  && rm -rf /var/cache/apt/archives

# Expose ports
EXPOSE 80 443 4443 10000/udp

# Start services
CMD ["/bin/bash", "-c", "service nginx start && service jicofo start && service jitsi-videobridge2 start && tail -f /dev/null"]
