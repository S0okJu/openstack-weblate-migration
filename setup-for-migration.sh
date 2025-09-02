# install zanta-cli

# https://docs.zanata.org/en/latest/client/installation/linux-installation/
function setup_zanata_cli{

    sudo apt-get install zeroinstall-injector openjdk-8-jre -y &&
    
    mkdir -p ~/bin
    export PATH="$HOME/bin:$PATH"

    # skip if it's not installed
    0install destroy zanata-cli || true 
    0install -c add zanata-cli https://raw.githubusercontent.com/zanata/zanata.github.io/master/files/0install/zanata-cli.xml
    0install -c update zanata-cli
}

function prepare-migration {
    sudo apt install python3.10-venv -y
}