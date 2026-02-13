podman build --no-cache --rm --file Containerfile --tag jitsi:demo .
podman run --interactive --tty --publish 9090:80 --publish 9091:443  --publish 4443:4443 --publish 10000:10000 jitsi:demo
echo "browse https://localhost:9091/"
