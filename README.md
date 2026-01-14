# hytale-hybrid-server
multi-arch dockerized appliance for hytale dedicated servers. optimized for oracle cloud (arm64) and standard x86_64 nodes.

## how it works
this image uses a hybrid architecture to solve the "amd64-only" downloader bottleneck. it detects the system architecture at boot and uses **box64** to emulate the hytale downloader on arm64 nodes, while keeping the java server itself running natively for zero-latency performance.

## what it covers
* **automated setup**: fetches the latest downloader and game binaries on the fly.
* **license guard**: checks for account authorization and provides clear 403 error feedback.
* **performance**: uses java 25 aot caching to speed up world generation on ampere nodes.
* **persistence**: self-healing permissions for bind-mounted volumes.

## instructions
1. **requirements**: port **5520 udp** must be open for the quic protocol.
2. **authorization**: hytale requires two separate oauth steps:
   - **step 1**: authorize the downloader to pull the 3.3gb assets.zip.
   - **step 2**: authorize the server instance at `https://accounts.hytale.com/device` after the first boot.
3. **deployment**:
   ```bash
   docker run -it -p 5520:5520/udp -v $(pwd)/data:/home/container zneh/hytale-hybrid:latest
   ```
   `-v /etc/machine-id:/etc/machine-id:ro` tag is recommended for auth persistence Encrypted.

## environment variables

* `SERVER_MEMORY`: ram limit for java (default: 4096m).
* `SERVER_PORT`: udp port for quic (default: 5520).

