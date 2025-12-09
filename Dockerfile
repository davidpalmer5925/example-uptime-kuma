FROM docker.io/alpine:latest AS BUILDER
RUN apk add --no-cache curl jq ca-certificates

WORKDIR /tmp

RUN set -e; \
    echo "--- 1. Obteniendo JSON de Releases ---"; \
    curl -fL -s https://api.github.com/repos/benbjohnson/litestream/releases -o release.json; \
    \
    echo "--- 2. Extrayendo URLs (Beta/Pre-release) ---"; \
    # Filtro para el BINARIO (CLI): linux-amd64 o x86_64, tar.gz, NO vfs
    CLI_URL=$(jq -r '.[0].assets[] | select(.name | (contains("linux-amd64") or contains("linux-x86_64")) and endswith(".tar.gz") and (contains("vfs") | not)) | .browser_download_url' release.json); \
    # Filtro para la EXTENSIÓN (VFS): linux-amd64 o x86_64, tar.gz, SI vfs
    VFS_URL=$(jq -r '.[0].assets[] | select(.name | (contains("linux-amd64") or contains("linux-x86_64")) and endswith(".tar.gz") and contains("vfs")) | .browser_download_url' release.json); \
    \
    if [ -z "$CLI_URL" ] || [ "$CLI_URL" = "null" ]; then echo "Error: URL CLI no encontrada"; exit 1; fi; \
    if [ -z "$VFS_URL" ] || [ "$VFS_URL" = "null" ]; then echo "Error: URL VFS no encontrada"; exit 1; fi; \
    \
    echo "--- 3. Descargando y Extrayendo ---"; \
    # Procesar CLI
    curl -fL "$CLI_URL" -o cli.tar.gz && \
    tar xzvf cli.tar.gz && \
    find . -type f -name "litestream" -exec mv {} /usr/local/bin/litestream \; && \
    chmod +x /usr/local/bin/litestream; \
    \
    # Procesar VFS
    curl -fL "$VFS_URL" -o vfs.tar.gz && \
    tar xzvf vfs.tar.gz && \
    # Creamos carpeta destino para lib
    mkdir -p /usr/local/lib && \
    find . -type f -name "litestream.so" -exec mv {} /usr/local/lib/litestream.so \;

FROM docker.io/louislam/uptime-kuma:1

ARG UPTIME_KUMA_PORT=3001
WORKDIR /app
RUN mkdir -p /app/data

COPY --from=BUILDER /usr/local/bin/litestream /usr/local/bin/litestream
COPY --from=BUILDER /usr/local/lib/litestream.so /usr/local/lib/litestream.so

COPY litestream.yml /etc/litestream.yml
COPY run.sh /usr/local/bin/run.sh

RUN chmod +x /usr/local/bin/run.sh /usr/local/bin/litestream

EXPOSE ${UPTIME_KUMA_PORT}

CMD [ "/usr/local/bin/run.sh" ]
