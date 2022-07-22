# Solana Validator Manager

### Quick Install

* Log in to your server
* Create the key pair file (you can also upload it via scp if you prefer):
  ````shell
  nano ~/validator-keypair.json
  ````   
  Paste your key pair, save the file (ctrl-O) and exit (ctrl-X).


  If you have a *vote account* key pair, create the key pair file (or upload it via scp):
  ````shell
   nano ~/vote-account-keypair.json
  ````  
  Paste your key pair, save the file (ctrl-O) and exit (ctrl-X).
* Run this command…

````shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NEWSOROS/sv-manager-2/latest/install/install_validator.sh)"
````

That's it, you are all set!

### How to update validator

````shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NEWSOROS/sv-manager-2/latest/install/update_test_validator_version.sh)" --version 1.10.31
````

### how to update monitoring

````shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/NEWSOROS/sv-manager-2/latest/install/update_monitoring.sh)" 
````
