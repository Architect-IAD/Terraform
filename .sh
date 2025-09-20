curl -LO https://releases.hashicorp.com/tfstacks/1.0.0-beta1/tfstacks_1.0.0-beta1_darwin_arm64.zip
unzip tfstacks_1.0.0-beta1_darwin_arm64.zip
chmod +x tfstacks
sudo mv tfstacks /opt/homebrew/bin/
tfstacks --help