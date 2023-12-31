#!/usr/bin/env bash

IDENTIFIER="# File appended"
PAM_FILE="/etc/pam.d/common-password"
SUDOERS_FILE="/etc/sudoers"
SERVICES_FOLDER="$HOME/.local/share/systemd/user"
STARTUP_SERVICE="custom-startup.service"
STARTUP_SERVICE_FILE="$SERVICES_FOLDER/$STARTUP_SERVICE"

appendFile() {
    local file="$1"
    local content="$2"

    if ! grep -q "$IDENTIFIER" "$file"; then
        cat <<EOF >> "$file"
$content
EOF
        echo "Added extra config to $file successfully"
    fi
}

# Check if password length limitations are already removed
if ! grep -q "minlen=1" "$PAM_FILE"; then
    # Remove the password length limitations
    if sudo sed -i 's|pam_unix.so obscure yescrypt|pam_unix.so minlen=1 obscure yescrypt|' "$PAM_FILE"; then
        echo "Password length limitations removed"
    else
        echo "Failed to remove password length limitations. Check permissions or try again."
        exit 1
    fi
fi

# Enable asterisks for sudo password input
if ! sudo grep -q "env_reset,pwfeedback" "$SUDOERS_FILE"; then
    if sudo sed -i 's|env_reset|env_reset,pwfeedback|' "$SUDOERS_FILE"; then
        echo "Enabled asterisks for sudo password input"
    else
        echo "Failed to enable asterisks for sudo password input."
        exit 1
    fi
fi

# Enable startup service
if ! test -f "$STARTUP_SERVICE_FILE"; then
    mkdir -p "$SERVICES_FOLDER"
    cp "services/$STARTUP_SERVICE" "$STARTUP_SERVICE_FILE"
    if systemctl --user enable "$STARTUP_SERVICE"; then
        echo "Enabled startup service successfully"
    else
        echo "Failed to enable startup service."
    fi
fi

bashRc=$(
    cat << EOF
$IDENTIFIER
if [[ -n \$SSH_CONNECTION ]]; then
  sh -c "gnome-session-inhibit --inhibit suspend --reason \"SSH connection active\" --inhibit-only > /dev/null 2>&1 &"
fi

alias update="sudo apt update -y && sudo apt upgrade -y ; sudo flatpak update -y"
alias rwayd="sudo waydroid container restart"
EOF
)

profile=$(
    cat << EOF
$IDENTIFIER
$HOME/.local/bin/login
EOF
)

# Add extra config to .bashrc
appendFile ~/.bashrc "$bashRc"

# Add extra config to .profile
appendFile ~/.profile "$profile"
