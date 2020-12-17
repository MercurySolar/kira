#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

KIRA_SETUP_BASE_TOOLS="$KIRA_SETUP/base-tools-v0.1.10"
if [ ! -f "$KIRA_SETUP_BASE_TOOLS" ]; then
  echo "INFO: Update and Intall basic tools and dependencies..."
  apt-get update -y --fix-missing
  apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    hashdeep \
    python \
    python3 \
    python3-pip \
    software-properties-common \
    tar \
    zip \
    jq \
    php-cli \
    unzip \
    php7.4-gmp \
    php-mbstring \
    md5deep

  pip3 install ECPy

  cd /home/$SUDO_USER
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer

  HD_WALLET_DIR="/home/$SUDO_USER/hd-wallet-derive"
  HD_WALLET_PATH="$HD_WALLET_DIR/hd-wallet-derive.php"
  $KIRA_SCRIPTS/git-pull.sh "https://github.com/KiraCore/hd-wallet-derive.git" "master" "$HD_WALLET_DIR" 555
  FILE_HASH=$(CDHelper hash SHA256 -p="$HD_WALLET_DIR" -x=true -r=true --silent=true -i="$HD_WALLET_DIR/.git,$HD_WALLET_DIR/.gitignore,$HD_WALLET_DIR/tests")
  EXPECTED_HASH="078da5d02f80e96fae851db9d2891d626437378dd43d1d647658526b9c807fcd"

  if [ "$FILE_HASH" != "$EXPECTED_HASH" ]; then
    echo "DANGER: Failed to check integrity hash of the hd-wallet derivaiton tool !!!"
    echo -e "\nERROR: Expected hash: $EXPECTED_HASH, but got $FILE_HASH\n"
    read -p "Press any key to continue..." -n 1
    exit 1
  fi

  cd $HD_WALLET_DIR
  yes "yes" | composer install

  ls -l /bin/hd-wallet-derive || echo "WARNING: Wallet Derive Tool was not found"
  rm /bin/hd-wallet-derive || echo "WARNING: Failed to remove old Wallet Derive symlink"
  ln -s $HD_WALLET_PATH /bin/hd-wallet-derive || echo "WARNING: KIRA Manager symlink already exists"

  cd /home/$SUDO_USER
  TOOLS_DIR="/home/$SUDO_USER/tools"
  KMS_KEYIMPORT_DIR="$TOOLS_DIR/tmkms-key-import"
  $KIRA_SCRIPTS/git-pull.sh "https://github.com/KiraCore/tools.git" "main" "$TOOLS_DIR" 555
  FILE_HASH=$(CDHelper hash SHA256 -p="$TOOLS_DIR" -x=true -r=true --silent=true -i="$TOOLS_DIR/.git,$TOOLS_DIR/.gitignore")
  EXPECTED_HASH="3de9bb95cb065e9cec2e2b35ef68eff9e81a5718e60a16a0c9f31a4f0672dfa2"

  if [ "$FILE_HASH" != "$EXPECTED_HASH" ]; then
    echo "DANGER: Failed to check integrity hash of the kira tools !!!"
    echo -e "\nERROR: Expected hash: $EXPECTED_HASH, but got $FILE_HASH\n"
    read -p "Press any key to continue..." -n 1
    exit 1
  fi

  cd $KMS_KEYIMPORT_DIR
  ls -l /bin/tmkms-key-import || echo "tmkms-key-import symlink not found"
  rm /bin/tmkms-key-import || echo "faild removing old tmkms-key-import symlink"
  ln -s $KMS_KEYIMPORT_DIR/start.sh /bin/tmkms-key-import || echo "tmkms-key-import symlink already exists"
  # MNEMONIC=$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')
  # tmkms-key-import "$MNEMONIC" "$HOME/priv_validator_key.json" "$HOME/signing.key"

  cd /home/$SUDO_USER
  touch $KIRA_SETUP_BASE_TOOLS
else
  echo "INFO: Base tools were already installed."
fi
