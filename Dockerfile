FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install necessary tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    cloud-image-utils \
    genisoimage \
    novnc \
    websockify \
    wget \
    net-tools \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create working directories
RUN mkdir -p /data /novnc /opt/qemu /cloud-init

# Download Ubuntu 20.04 cloud image
RUN wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -O /opt/qemu/ubuntu.img

# Create cloud-init meta-data
RUN echo 'instance-id: ubuntu-vm\nlocal-hostname: ubuntu-vm' > /cloud-init/meta-data

# Create cloud-init user-data with root login enabled
RUN cat <<EOF > /cloud-init/user-data
#cloud-config
users:
  - name: root
    lock_passwd: false
    passwd: \$6\$gqRzOa5K\$kzNzql7/s9TehZH1DpRSe7qN6G4xQuEFv9kWRvcm54W1Yl8N5yx4tspkmnAGVK2nK3jLU5DkvZ31sH1FLaMjR1
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_pwauth: true
disable_root: false
chpasswd:
  expire: false
  list: |
    root:rootpass
EOF

# Create cloud-init ISO image
RUN genisoimage -output /opt/qemu/seed.iso -volid cidata -joliet -rock /cloud-init/user-data /cloud-init/meta-data

# Download and setup noVNC
RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# Create startup script
RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

DISK="/data/disk.qcow2"
IMG="/opt/qemu/ubuntu.img"
SEED="/opt/qemu/seed.iso"

# Create VM disk if it doesn't exist
if [ ! -f "$DISK" ]; then
    echo "Creating VM disk..."
    qemu-img create -f qcow2 -b "$IMG" -F qcow2 "$DISK" 20G
fi

# Start the VM
qemu-system-x86_64 \
    -m 4096 \
    -smp 4 \
    -cpu max \
    -drive file="$DISK",format=qcow2,if=virtio \
    -drive file="$SEED",format=raw,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net,netdev=net0 \
    -vga virtio \
    -nographic \
    -vnc :0 &

# Start noVNC
sleep 5
websockify --web /novnc 6080 localhost:5900 &

echo "================================================"
echo " 🖥️  Access your VM at: http://localhost:6080"
echo " 🔐 SSH to your VM: ssh root@localhost -p 2222"
echo " 🧾 Username: root | Password: rootpass"
echo "================================================"

wait
EOF

RUN chmod +x /start.sh

VOLUME /data

EXPOSE 6080 2222

CMD ["/start.sh"]
