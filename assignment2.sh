#!/bin/bash

echo "========== NETWORK CONFIGURATION START =========="

NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
TARGET_IP="192.168.16.21/24"
GATEWAY="192.168.16.2"
DNS="192.168.16.2"
HOST_ENTRY="192.168.16.21 server1"

# 1. Backup netplan
if [ ! -f "${NETPLAN_FILE}.bak" ]; then
    cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
    echo "[INFO] Netplan backup created at ${NETPLAN_FILE}.bak"
else
    echo "[INFO] Netplan backup already exists"
fi

# 2. Update netplan file if needed
if ! grep -q "$TARGET_IP" "$NETPLAN_FILE"; then
    echo "[INFO] Updating netplan configuration..."
    cat > "$NETPLAN_FILE" <<EOF
network:
    version: 2
    ethernets:
        lan:
            addresses: [$TARGET_IP]
            routes:
              - to: default
                via: $GATEWAY
            nameservers:
                addresses: [$DNS]
                search: [home.arpa, localdomain]
EOF

    echo "[INFO] Applying new netplan configuration..."
    netplan apply && echo "[SUCCESS] Netplan applied." || echo "[ERROR] Netplan apply failed!"
else
    echo "[INFO] Netplan already configured with $TARGET_IP"
fi

# 3. Update /etc/hosts
echo "[INFO] Ensuring /etc/hosts contains correct server1 entry..."
sed -i '/server1/d' /etc/hosts
echo "$HOST_ENTRY" >> /etc/hosts
echo "[INFO] /etc/hosts updated with: $HOST_ENTRY"

echo "========== NETWORK CONFIGURATION COMPLETE =========="

echo "========== SOFTWARE INSTALLATION START =========="

install_and_enable() {
    PKG="$1"
    SERVICE="$2"

    if ! dpkg -l | grep -qw "$PKG"; then
        echo "[INFO] Installing $PKG..."
        apt-get update -y && apt-get install -y "$PKG"
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] $PKG installed"
        else
            echo "[ERROR] Failed to install $PKG"
        fi
    else
        echo "[INFO] $PKG is already installed"
    fi

    echo "[INFO] Enabling and starting $SERVICE service..."
    systemctl enable "$SERVICE"
    systemctl start "$SERVICE"
    systemctl is-active "$SERVICE" && echo "[SUCCESS] $SERVICE is running" || echo "[ERROR] $SERVICE failed to start"
}

install_and_enable apache2 apache2
install_and_enable squid squid

echo "========== SOFTWARE INSTALLATION COMPLETE =========="



echo "========== USER ACCOUNT CONFIGURATION START =========="

USERLIST="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"
DENNIS_EXTRA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for USER in $USERLIST; do
    echo "[INFO] Processing user: $USER"

    if ! id "$USER" &>/dev/null; then
        useradd -m -s /bin/bash "$USER"
        echo "[SUCCESS] Created user $USER"
    else
        echo "[INFO] User $USER already exists"
    fi

    USER_HOME="/home/$USER"
    SSH_DIR="$USER_HOME/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chown "$USER:$USER" "$SSH_DIR"

    # Generate RSA key if not exists
    if [ ! -f "$SSH_DIR/id_rsa.pub" ]; then
        sudo -u "$USER" ssh-keygen -t rsa -b 2048 -N "" -f "$SSH_DIR/id_rsa"
        echo "[SUCCESS] RSA key generated for $USER"
    fi

    # Generate Ed25519 key if not exists
    if [ ! -f "$SSH_DIR/id_ed25519.pub" ]; then
        sudo -u "$USER" ssh-keygen -t ed25519 -N "" -f "$SSH_DIR/id_ed25519"
        echo "[SUCCESS] Ed25519 key generated for $USER"
    fi

    # Build authorized_keys
    > "$AUTH_KEYS"  # Empty file
    cat "$SSH_DIR/id_rsa.pub" >> "$AUTH_KEYS"
    cat "$SSH_DIR/id_ed25519.pub" >> "$AUTH_KEYS"

    # Add special public key to dennis
    if [ "$USER" = "dennis" ]; then
        echo "$DENNIS_EXTRA_KEY" >> "$AUTH_KEYS"
        usermod -aG sudo dennis
        echo "[INFO] Added extra key and sudo access to dennis"
    fi

    chmod 600 "$AUTH_KEYS"
    chown "$USER:$USER" "$AUTH_KEYS"
done

echo "========== USER ACCOUNT CONFIGURATION COMPLETE =========="
