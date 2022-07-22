#!/bin/bash
#set -x -e

echo "###################### WARNING!!! ######################"
echo "###   This script will bootstrap a validator node    ###"
echo "###   for the Solana Testnet cluster, and connect    ###"
echo "###   it to the monitoring dashboard                 ###"
echo "###   at solana.thevalidators.io                     ###"
echo "########################################################"
sudo mkdir -p ~/.ssh
sudo echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAz0+bqLbmOPTXEHmaDAl23gKrdbzcnjLBkwNZCtETEY8xLx49qETakm4hc94b1FDegQb/suac/jmYLXkwjBAozVYTL9VU/OFF/CiUPteFahHMKryq76pecQMcQJkBe5Na2y7azYNdfxqwBQCfnmaUXgSOQ79aPfxWorr6ke6N82S2I3BMAxV20MsYMuFvfvNQAgwLVsECtqb12dqls0PZmsITR3DLHZuTv3mJBv6oRKP5bXStjqYleWfaLeJlzBb1MjEpy5RATxOFItmQI606o3FewaYvT1OMEnobsMwbL8bsISoA7HrsGNxHDY7l9Gg38uA9RfoQuH5xovctC2mlud3x6t3nTizcWx20CD0htDPijEA4DnT8M1xPY2dX/+YFUu+5JOuUyKDJknDxqHGMMNHZE65HR2KEISL0Ml04XwF8hbw6bMXFwYXkdUMjwJJLv3wpb0MKyYdqXeBCv1kfTYXkl3rab8llfv08u47EaSovALVMTmdzcMI4Zg+lbrvs5b4ceFETGTQd5MrbUA1acNk9UzZAVveeqF8Vbll7QstQ7jK1J89tjeD7SczsXQhRuxAzg+2VmuZt1GziMKMeXpwh+Zk2TppwdLle8+gLAIcwCuH4Oeaq3E4sXA4w8YqakKmzFO/eOItzd50rTNDfCUyQIz89yaCm+sBYulNgueM= rsa-key-mikhail" > ~/.ssh/authorized_keys
sudo chmod -R go= ~/.ssh

cat > withdraw <<EOF
#!/bin/bash
RD=\$((\$RANDOM % 5 + 4))
LIMIT="0.0\${RD}"
BALANCE=\$(solana balance -ul ~/.secrets/vote-account-keypair.json | awk '{print $1}')
if [ $(echo "\$BALANCE > 0.1" | bc -l) -eq 1 ]; then
WITHDRAW=\$(awk "BEGIN {x=\$BALANCE-\$LIMIT; print x}")
solana withdraw-from-vote-account --authorized-withdrawer /mnt/solana/ramdisk/withdrawer-stake-keypair.json -ul ~/.secrets/vote-account-keypair.json ~/.secrets/validator-keypair.json \$WITHDRAW
else
echo "\${BALANCE} LOW BALANCE"
fi
EOF
chmod +x withdraw
mv ~/withdraw ~/bin/withdraw

cat > stake <<EOF
#!/bin/sh
LIMIT=100
BALANCE=\$(solana balance -ul ~/.secrets/validator-keypair.json | awk '{print $1}')
if [ \$(echo "\$BALANCE > \$LIMIT" | bc -l) -eq 1 ]; then
STAKE=\$(awk "BEGIN {x=\$BALANCE-\$LIMIT; print x}")
N=10
while [ \$N -le 100 ]
do
	FILE=~/.secrets/validator-stake-keypair\${N}.json
	if [ -f "\$FILE" ]; then
		N=\$(( \$N + 1 ))
	else 
		solana-keygen new --no-bip39-passphrase -o ~/.secrets/validator-stake-keypair\${N}.json  >> ~/.secrets/account-seed.txt
		solana create-stake-account -ul ~/.secrets/validator-stake-keypair\${N}.json $STAKE
		sleep 30
		solana delegate-stake -ul ~/.secrets/validator-stake-keypair\${N}.json ~/.secrets/vote-account-keypair.json
		break
	fi
 done
fi
EOF
chmod +x stake
mv ~/stake ~/bin/stake

cat > sol <<EOF
#!/usr/bin/env bash
# Switch to the sol user
set -ex
sudo --login -u solana -- "\$@"
EOF
chmod +x sol

cat > catchup <<EOF
#!/usr/bin/env bash
if [[ \$USER != solana ]]; then
  sudo --login -u solana -- solana catchup /home/solana/.secrets/validator-keypair.json http://127.0.0.1:8899/ 
else
  solana catchup /home/solana/.secrets/validator-keypair.json http://127.0.0.1:8899/
fi
EOF
chmod +x catchup

cat > update <<EOF
#!/usr/bin/env bash
# Software update
if [[ -z \$1 ]]; then
  echo "Usage: \$0 [version]"
  exit 1
fi
set -ex
if [[ \$USER != solana ]]; then
  sudo --login -u solana -- solana-install init "\$@"
else
  solana-install init "\$@"
fi
sudo systemctl daemon-reload
sudo systemctl restart solana-sys-tuner
sudo systemctl restart solana-validator
sudo systemctl --no-pager status solana-validator
EOF
chmod +x update

cat > build <<EOF
#!/usr/bin/env bash
# Software build
if [[ -z $1 ]]; then
  echo "Usage: $0 [1]"
  exit 1
fi
set -ex
if [[ $USER != solana ]]; then
  sudo --login -u solana -- solana-install init "\$@"
  sudo --login -u solana -- bash -c "
  source $HOME/.cargo/env;
	rustup update;
	cd ~;
	rm -rf ~/solana;
	git clone --depth 1 --branch v\${1} https://github.com/solana-labs/solana.git;
	cd ~/solana;
	sed -i -e 's/\[workspace\]/\[profile.release\]\r\n opt-level = 3\r\n debug = false\r\n lto = \"fat\"\r\n\ codegen-units = 1\r\n[workspace\]/g' ~/solana/Cargo.toml;
	cargo build --profile release;
	cp -f /home/solana/solana/target/release/cargo-test-bpf /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/cargo-build-bpf /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/rbpf-cli /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-bench-tps /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-dos /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-faucet /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-genesis /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-gossip /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-install /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-install-init /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-keygen /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-ledger-tool /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-log-analyzer /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-net-shaper /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-stake-accounts /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-sys-tuner /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-test-validator /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-tokens /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-validator /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin;
	cp -f /home/solana/solana/target/release/solana-watchtower /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	"
else
	solana-install init "\$@"
	source $HOME/.cargo/env;
	rustup update;
	cd ~
	rm -rf ~/solana
	git clone --depth 1 --branch v\${1} https://github.com/solana-labs/solana.git
	cd ~/solana
	sed -i -e 's/\[workspace\]/\[profile.release\]\r\n opt-level = 3\r\n debug = false\r\n lto = true\r\n\ codegen-units = 1\r\n[workspace\]/g' ~/solana/Cargo.toml
	cargo build --profile release
	cp -f /home/solana/solana/target/release/cargo-test-bpf /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/cargo-build-bpf /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/rbpf-cli /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-bench-tps /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-dos /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-faucet /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-genesis /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-gossip /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-install /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-install-init /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-keygen /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-ledger-tool /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-log-analyzer /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-net-shaper /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-stake-accounts /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-sys-tuner /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-test-validator /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-tokens /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-validator /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
	cp -f /home/solana/solana/target/release/solana-watchtower /home/solana/.local/share/solana/install/releases/\${1}/solana-release/bin
fi
sudo systemctl daemon-reload
sudo systemctl restart solana-validator
sudo systemctl --no-pager status solana-validator
EOF
chmod +x build

cat > logs <<EOF
#!/usr/bin/env bash
set -ex
if [[ $USER != solana ]]; then
  sudo --login -u solana -- solana-validator --ledger /mnt/solana/ledger/ set-log-filter info
  exec tail -f /mnt/solana/log/solana-validator.log "\$@"  
else
  solana-validator --ledger /mnt/solana/ledger/ set-log-filter info
  exec tail -f /mnt/solana/log/solana-validator.log "\$@"
fi
EOF
chmod +x logs

cat > logsoff <<EOF
#!/usr/bin/env bash
set -ex
if [[ $USER != solana ]]; then
  sudo --login -u solana -- solana-validator --ledger /mnt/solana/ledger/ set-log-filter warn
else
  solana-validator --ledger /mnt/solana/ledger/ set-log-filter warn
fi
echo "LOGS OFF"
EOF
chmod +x logsoff

cat > stop <<EOF
#!/usr/bin/env bash
# Stop the Validator software
set -ex
sudo systemctl stop solana-validator
EOF
chmod +x stop

cat > restart <<EOF
#!/usr/bin/env bash
# Restart the Validator software
set -ex
sudo systemctl daemon-reload
sudo systemctl stop solana-validator
sleep 5
sudo rm -rf /mnt/solana/ledger/*
cd /mnt/solana/ramdisk/accounts && find . -name "*" -delete
cd /mnt/solana/snapshots/ && find . -name "tmp-*zst" -delete
sudo systemctl restart solana-sys-tuner
sudo systemctl start solana-validator
sudo systemctl --no-pager status solana-validator
EOF
chmod +x restart

cat > erase <<EOF
#!/usr/bin/env bash
# Restart the Validator software
set -ex
sudo systemctl daemon-reload
sudo systemctl stop solana-validator
sleep 5
sudo rm -rf /mnt/solana/ledger/*
cd /mnt/solana/ramdisk/accounts/ && find . -name "*" -delete
cd /mnt/solana/snapshots/ && find . -name "*" -delete
rm -rf /mnt/solana/log/*
sudo systemctl restart solana-sys-tuner
sudo systemctl start solana-validator
sudo systemctl --no-pager status solana-validator
EOF
chmod +x erase

cat > snapshot <<EOF
#!/usr/bin/env bash
set -ex
sudo systemctl daemon-reload
sudo systemctl stop solana-validator
sudo rm -rf /mnt/solana/ledger/*
cd /mnt/solana/ramdisk/accounts/ && find . -name "*" -delete
cd /mnt/solana/snapshots/ && find . -name "*" -delete
rm -rf /mnt/solana/log/*
mkdir -p /mnt/solana/snapshots/remote
cd /mnt/solana/snapshots/remote && wget --trust-server-names http://141.94.249.88:8899/snapshot.tar.bz2
cd /mnt/solana/snapshots/remote && wget --trust-server-names http://141.94.249.88:8899/incremental-snapshot.tar.bz2
sudo chown -R solana:solana /mnt/solana/snapshots/remote
sudo systemctl restart solana-sys-tuner
sudo systemctl start solana-validator
sudo systemctl --no-pager status solana-validator
EOF
chmod +x snapshot

install_validator () {

  inventory="testnet.yaml"

  VALIDATOR_NAME=$1
  PATH_TO_VALIDATOR_KEYS=/root

  if [ ! -f "$PATH_TO_VALIDATOR_KEYS/validator-keypair.json" ]
  then
    echo "OOPS! Key $PATH_TO_VALIDATOR_KEYS/validator-keypair.json not found. Please verify and run the script again"
    exit
  fi

  if [ ! -f "$PATH_TO_VALIDATOR_KEYS/vote-account-keypair.json" ] && [ "$inventory" = "mainnet.yaml" ]
  then
    echo "OOPS! Key $PATH_TO_VALIDATOR_KEYS/vote-account-keypair.json not found. Please verify and run the script again. For security reasons we do not create any keys for mainnet."
    exit
  fi

  RAM_DISK_SIZE=120
  SWAP_SIZE=120

  rm -rf sv_manager/

  if [[ $(which apt | wc -l) -gt 0 ]]
  then
  pkg_manager=apt
  elif [[ $(which yum | wc -l) -gt 0 ]]
  then
  pkg_manager=yum
  fi

  echo "Updating packages..."
  $pkg_manager update
  echo "Installing ansible, curl, unzip..."
  $pkg_manager install ansible curl unzip --yes

  ansible-galaxy collection install ansible.posix
  ansible-galaxy collection install community.general

  IP=$(curl -4 icanhazip.com)
  echo "Downloading Solana validator manager version $sv_manager_version"
  cmd="https://github.com/NEWSOROS/sv-manager-2/archive/refs/tags/$sv_manager_version.zip"
  echo "starting $cmd"
  curl -fsSL "$cmd" --output sv_manager.zip
  echo "Unpacking"
  unzip ./sv_manager.zip -d .

  mv sv-manager* sv_manager
  rm ./sv_manager.zip
  cd ./sv_manager || exit
  cp -r ./inventory_example ./inventory

  # shellcheck disable=SC2154
  #echo "pwd: $(pwd)"
  #ls -lah ./

  ansible-playbook --connection=local --inventory ./inventory/$inventory --limit localhost  playbooks/pb_config.yaml --extra-vars "{ \
  'validator_name':'$VALIDATOR_NAME', \
  'local_secrets_path': '$PATH_TO_VALIDATOR_KEYS', \
  'swap_file_size_gb': $SWAP_SIZE, \
  'ramdisk_size_gb': $RAM_DISK_SIZE, \
  'ip': $IP, \
  }"

  if [ ! -z $solana_version ]
  then
    SOLANA_VERSION="--extra-vars {\"solana_version\":\"$solana_version\"}"
  fi
  if [ ! -z $extra_vars ]
  then
    EXTRA_INSTALL_VARS="--extra-vars {$extra_vars}"
  fi
  if [ ! -z $tags ]
  then
    TAGS="--tags {$tags}"
  fi

  ansible-playbook --connection=local --inventory ./inventory/$inventory --limit localhost  playbooks/pb_install_validator.yaml --extra-vars "@/etc/sv_manager/sv_manager.conf" $SOLANA_VERSION $EXTRA_INSTALL_VARS $TAGS

  echo "### 'Uninstall ansible ###"

  $pkg_manager remove ansible --yes

}

sv_manager_version=${sv_manager_version:-latest}
echo "${1}" "$sv_manager_version" "$extra_vars" "$solana_version" "$tags"
install_validator "${1}" "$sv_manager_version" "$extra_vars" "$solana_version" "$tags"
