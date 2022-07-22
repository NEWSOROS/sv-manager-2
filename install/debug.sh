#!/bin/bash
#set -x -e

  echo "Downloading Solana validator manager"
  cmd="https://github.com/NEWSOROS/sv-manager-2/archive/refs/tags/$1.zip"
  echo "starting $cmd"
  curl -fsSL "$cmd" --output sv_manager.zip
  echo "Unpacking"
  unzip ./sv_manager.zip -d .

  mv sv-manager* sv_manager
  rm ./sv_manager.zip
  cd ./sv_manager || exit
  cp -r ./inventory_example ./inventory

  ansible-playbook --connection=local --inventory ./inventory -l local  playbooks/pb_debug.yaml