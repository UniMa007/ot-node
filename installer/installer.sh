#!/bin/bash

OTNODE_DIR="/root/ot-node"

text_color() {
    GREEN='\033[0;32m'
    BGREEN='\033[1;32m'
    RED='\033[0;31m'
    BRED='\033[1;31m'
    YELLOW='\033[0;33m'
    BYELLOW='\033[1;33m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
    echo -e "$@$NC"
}

header_color() {
    LIGHTCYAN='\033[1;36m'
    NC='\033[0m' # No Color
    echo -e "${LIGHTCYAN}$@$NC"
}

perform_step() {
    N1=$'\n'
    echo -n "${@: -1}: "

    OUTPUT=$(${@:1:$#-1} 2>&1)

    if [[ $? -ne 0 ]]; then
        text_color $BOLD$RED FAILED
        echo -e "${N1}Step failed. Output of error is:${N1}${N1}$OUTPUT"
        echo -e "${BRED}Press Enter to exit the installer.${NC}"
        read
        exit 1
    else
        text_color $BOLD$GREEN OK
    fi
}

# Function to display a notification box
notification_box() {
    local message="$1"
    text_color "$BOLD$message"
    echo -e "${BRED}Press Enter to exit the installer.${NC}"
    read
}

# Check Ubuntu version
check_ubuntu_version() {
    UBUNTU_VERSION=$(lsb_release -r -s)

    if [[ "$UBUNTU_VERSION" != "20.04" && "$UBUNTU_VERSION" != "22.04" ]]; then
        notification_box "Error: OriginTrail node installer currently requires Ubuntu 20.04 LTS or 22.04 LTS versions in order to execute successfully. You are installing on Ubuntu $UBUNTU_VERSION."
        echo -e "${BRED}Please make sure that you get familiar with the requirements before setting up your OriginTrail node! Documentation: docs.origintrail.io${NC}"
        exit 1
    fi
}

# Check if script is running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        notification_box "Error: This script must be run as root."
        echo -e "${BRED}Please re-run the script as root using 'sudo'.${NC}"
        exit 1
    fi
}

install_aliases() {
    if [[ -f "/root/.bashrc" ]]; then
        if grep -Fxq "alias otnode-restart='systemctl restart otnode.service'" ~/.bashrc; then
            echo "Aliases found, skipping."
        else
            echo "alias otnode-restart='systemctl restart otnode.service'" >> ~/.bashrc
            echo "alias otnode-stop='systemctl stop otnode.service'" >> ~/.bashrc
            echo "alias otnode-start='systemctl start otnode.service'" >> ~/.bashrc
            echo "alias otnode-logs='journalctl -u otnode --output cat -f'" >> ~/.bashrc
            echo "alias otnode-config='nano ~/ot-node/.origintrail_noderc'" >> ~/.bashrc
        fi
    else
        echo "bashrc does not exist. Proceeding with OriginTrail node installation."
    fi
}

install_directory() {
    ARCHIVE_REPOSITORY_URL="github.com/OriginTrail/ot-node/archive"
    BRANCH="v6/release/mainnet"
    BRANCH_DIR="/root/ot-node-6-release-mainnet"

    perform_step wget https://$ARCHIVE_REPOSITORY_URL/$BRANCH.zip "Downloading node files"
    perform_step unzip *.zip "Unzipping node files"
    perform_step rm *.zip "Removing zip file"
    OTNODE_VERSION=$(jq -r '.version' $BRANCH_DIR/package.json)
    perform_step mkdir $OTNODE_DIR "Creating new ot-node directory"
    perform_step mkdir $OTNODE_DIR/$OTNODE_VERSION "Creating new ot-node version directory"
    perform_step mv $BRANCH_DIR/* $OTNODE_DIR/$OTNODE_VERSION/ "Moving downloaded node files to ot-node version directory"
    OUTPUT=$(mv $BRANCH_DIR/.* $OTNODE_DIR/$OTNODE_VERSION/ 2>&1)
    perform_step rm -rf $BRANCH_DIR "Removing old directories"
    perform_step ln -sfn $OTNODE_DIR/$OTNODE_VERSION $OTNODE_DIR/current "Creating symlink from $OTNODE_DIR/$OTNODE_VERSION to $OTNODE_DIR/current"
}

install_firewall() {
    ufw allow 22/tcp && ufw allow 8900 && ufw allow 9000
    yes | ufw enable
}

install_prereqs() {
    export DEBIAN_FRONTEND=noninteractive
    NODEJS_VER="16"

    perform_step install_aliases "Updating .bashrc file with OriginTrail node aliases" > /dev/null 2>&1
    perform_step rm -rf /var/lib/dpkg/lock-frontend "Removing any frontend locks" > /dev/null 2>&1
    perform_step apt update "Updating Ubuntu package repository" > /dev/null 2>&1
    perform_step apt upgrade -y "Updating Ubuntu to the latest version" > /dev/null 2>&1
    perform_step apt install unzip jq -y "Installing unzip, jq" > /dev/null 2>&1
    perform_step apt install default-jre -y "Installing default-jre" > /dev/null 2>&1
    perform_step apt install build-essential -y "Installing build-essential" > /dev/null 2>&1

    # Install nodejs 16 (via NVM).
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash > /dev/null 2>&1
    export NVM_DIR="$HOME/.nvm"
    # This loads nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # This loads nvm bash_completion
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm install v16.20.1 > /dev/null 2>&1
    nvm use v16.20.1 > /dev/null 2>&1

    # Set nodejs 16.20.1 as default and link node to /usr/bin/
    nvm alias default 16.20.1 > /dev/null 2>&1
    sudo ln -s $(which node) /usr/bin/ > /dev/null 2>&1
    sudo ln -s $(which npm) /usr/bin/ > /dev/null 2>&1

    apt remove unattended-upgrades -y > /dev/null 2>&1

    perform_step install_firewall "Configuring firewall" > /dev/null 2>&1
    perform_step apt remove unattended-upgrades -y "Remove unattended upgrades" > /dev/null 2>&1
}


install_fuseki() {
    FUSEKI_VER="apache-jena-fuseki-$(git ls-remote --tags https://github.com/apache/jena | grep -o 'refs/tags/jena-[0-9]*\.[0-9]*\.[0-9]*' | sort -r | head -n 1 | grep -o '[^\/-]*$')"
    FUSEKI_PREV_VER="apache-jena-fuseki-$(git ls-remote --tags https://github.com/apache/jena | grep -o 'refs/tags/jena-[0-9]*\.[0-9]*\.[0-9]*' | sort -r | head -n 3 | tail -n 1 | grep -o '[^\/-]*$')"
    wget -q --spider https://dlcdn.apache.org/jena/binaries/$FUSEKI_VER.zip
    if [[ $? -ne 0 ]]; then
        FUSEKI_VER=$FUSEKI_PREV_VER
    fi

    perform_step wget https://dlcdn.apache.org/jena/binaries/$FUSEKI_VER.zip "Downloading Fuseki"
    perform_step unzip $FUSEKI_VER.zip "Unzipping Fuseki"
    perform_step rm /root/$FUSEKI_VER.zip "Removing Fuseki zip file"
    perform_step mkdir /root/ot-node/fuseki "Making /root/ot-node/fuseki directory"
    perform_step cp /root/$FUSEKI_VER/fuseki-server.jar /root/ot-node/fuseki/ "Copying Fuseki files to $OTNODE_DIR/fuseki/ 1/2"
    perform_step cp -r /root/$FUSEKI_VER/webapp/ /root/ot-node/fuseki/ "Copying Fuseki files to $OTNODE_DIR/fuseki/ 1/2"
    perform_step rm -r /root/$FUSEKI_VER "Removing the remaining /root/$FUSEKI_VER directory"
    perform_step cp $OTNODE_DIR/installer/data/fuseki.service /lib/systemd/system/ "Copying Fuseki service file"
    systemctl daemon-reload
    perform_step systemctl enable fuseki "Enabling Fuseki"
    perform_step systemctl start fuseki "Starting Fuseki"
    perform_step systemctl status fuseki "Fuseki status"
}

install_blazegraph() {
    perform_step wget https://github.com/blazegraph/database/releases/latest/download/blazegraph.jar "Downloading Blazegraph"
    perform_step cp $OTNODE_DIR/installer/data/blazegraph.service /lib/systemd/system/ "Copying Blazegraph service file"
    mv blazegraph.jar $OTNODE_DIR/../blazegraph.jar
    systemctl daemon-reload
    perform_step systemctl enable blazegraph "Enabling Blazegrpah"
    perform_step systemctl start blazegraph "Starting Blazegraph"
    perform_step systemctl status blazegraph "Blazegraph status"
}

install_sql() {
    #check which sql to install/update
    text_color $YELLOW"IMPORTANT NOTE: to avoid potential migration issues from one SQL to another, please select the one you are currently using. If this is your first installation, both choices are valid. If you don't know the answer, select [1].
    "
    while true; do
        read -p "Please select the SQL you would like to use: (Default: MySQL) [1]MySQL [2]MariaDB [E]xit " choice
        case "$choice" in
            [2]* )  text_color $GREEN"MariaDB selected. Proceeding with installation."
                    sql=mariadb
                    perform_step apt-get install curl software-properties-common dirmngr ca-certificates apt-transport-https -y "Installing mariadb dependencies"
                    curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.8
                    perform_step apt-get install mariadb-server -y "Installing mariadb-server"
                    break;;
            [Ee]* ) text_color $RED"Installer stopped by user"; exit;;
            * )     text_color $GREEN"MySQL selected. Proceeding with installation."
                    sql=mysql
                    mysql_native_password=" WITH mysql_native_password"
                    perform_step apt-get install tcllib mysql-server -y "Installing mysql-server"
                    break;;
        esac
    done

    #check old sql password
    OUTPUT=$($sql -u root -e "status;" 2>&1)
    if [[ $? -ne 0 ]]; then
        while true; do
            read -s -p "Enter your old sql password: " oldpassword
            echo
            echo -n "Password check: "
            OUTPUT=$(MYSQL_PWD=$oldpassword $sql -u root -e "status;" 2>&1)
            if [[ $? -ne 0 ]]; then
                text_color $YELLOW"ERROR - The sql repository password provided does not match your sql password. Please try again."
            else
                text_color $GREEN "OK"
                break
            fi
        done
    fi

    #check operationaldb
    if [[ -d "/var/lib/mysql/operationaldb/" ]]; then
        read -p "Old operationaldb repository detected. Would you like to overwrite it ? (Default: No) [Y]es [N]o [E]xit " choice
        case "$choice" in
            [yY]* ) perform_step $(MYSQL_PWD=$oldpassword $sql -u root -e "DROP DATABASE IF EXISTS operationaldb;") "Overwritting slq repository";;
            [eE]* ) text_color $RED"Installer stopped by user"; exit;;
            * )     text_color $GREEN"Keeping previous sql repository"; NEW_DB=FALSE;;
        esac
    fi

    #check sql new password
    read -p "Would you like to change your sql password or add one ? (Default: Yes) [Y]es [N]o [E]xit " choice
    case "$choice" in
        [nN]* ) text_color $GREEN"Keeping previous sql password"; password=$oldpassword;;
        [eE]* ) text_color $RED"Installer stopped by user"; exit;;
        * )     while true; do
                    read -s -p "Enter your new sql password: " password
                    echo
                    read -s -p "Please confirm your new sql password: " password2
                    echo
                    [[ $password = $password2 ]] && break
                    text_color $YELLOW "Password entered do not match. Please try again."
                done
                perform_step $(MYSQL_PWD=$oldpassword $sql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED$mysql_native_password BY '$password';") "Changing sql password";;
    esac

    perform_step $(echo "REPOSITORY_PASSWORD=$password" > $OTNODE_DIR/.env) "Adding sql password to .env"
    if [[ $NEW_DB != FALSE ]]; then
        perform_step $(MYSQL_PWD=$password $sql -u root -e "CREATE DATABASE operationaldb /*\!40100 DEFAULT CHARACTER SET utf8 */;") "Creating new sql repository"
    fi
    if [[ $sql = mysql ]]; then
        perform_step sed -i 's|max_binlog_size|#max_binlog_size|' /etc/mysql/mysql.conf.d/mysqld.cnf "Setting max log size"
        perform_step $(echo -e "disable_log_bin\nwait_timeout = 31536000\ninteractive_timeout = 31536000" >> /etc/mysql/mysql.conf.d/mysqld.cnf) "Adding disable_log_bin, wait_timeout, interactive_timeout to sql config"
    fi
    if [[ $sql = mariadb ]]; then
        perform_step sed -i 's|max_binlog_size|#max_binlog_size|' /etc/mysql/mariadb.conf.d/50-server.cnf "Setting max log size"
        perform_step $(echo -e "disable_log_bin\nwait_timeout = 31536000\ninteractive_timeout = 31536000" >> /etc/mysql/mariadb.conf.d/50-server.cnf) "Adding disable_log_bin, wait_timeout, interactive_timeout to sql config"
    fi
    perform_step systemctl restart $sql "Restarting $sql"
}

request_operational_wallet_keys() {
    WALLET_ADDRESSES=()
    WALLET_PRIVATE_KEYS=()

    echo "You'll now be asked to input addresses and private keys of your operational wallets for $1. Input an empty value to stop."
    wallet_no=1
    while true; do
        read -p "Please input the address for your $1 operational wallet no. $wallet_no:" address
        [[ -z $address ]] && break
        text_color $GREEN "EVM operational wallet address for $blockchain wallet no. $wallet_no: $address"

        read -p "Please input the private key for your $1 operational wallet no. $wallet_no:" private_key
        [[ -z $private_key ]] && break
        text_color $GREEN "EVM operational wallet private key for $blockchain wallet no. $wallet_no: $private_key"

        WALLET_ADDRESSES+=($address)
        WALLET_PRIVATE_KEYS+=($private_key)
        wallet_no=$((wallet_no + 1))
    done

    OP_WALLET_KEYS_JSON=$(jq -n '
        [
        $ARGS.positional as $args
        | ($args | length / 2) as $upto
        | range(0; $upto) as $start
        | [{ evmAddress: $args[$start], privateKey: $args[$start + $upto] }]
        ] | add
        ' --args "${WALLET_ADDRESSES[@]}" "${WALLET_PRIVATE_KEYS[@]}")
}

install_node() {
    # Change directory to ot-node/current
    cd $OTNODE_DIR

    # Request node env with strict input validation
    while true; do
        read -p "Please select node environment: (Default: Mainnet) [T]estnet [M]ainnet [E]xit " choice
        case "$choice" in
            [tT]* ) nodeEnv="testnet"; break;;
            [mM]* ) nodeEnv="mainnet"; break;;
            [eE]* ) text_color $RED "Installer stopped by user"; exit;;
            * ) text_color $RED "Invalid choice. Please enter either [T]estnet, [M]ainnet, or [E]xit."; continue;;
        esac
    done
    echo "NODE_ENV=$nodeEnv" >> $OTNODE_DIR/.env

# Blockchains prompt based on the selected environment
if [ "$nodeEnv" == "mainnet" ]; then
    blockchain_prompt=("OriginTrail Parachain" "Gnosis" "Both")
elif [ "$nodeEnv" == "testnet" ]; then
    blockchain_prompt=("OriginTrail Parachain" "Gnosis" "Both")
fi


# Ask user which blockchain to connect to with strict input validation
while true; do
    read -p "Please select the blockchain you want to connect your node to:
    1. ${blockchain_prompt[0]}
    2. ${blockchain_prompt[1]}
    3. ${blockchain_prompt[2]}
    Your choice: " blockchain_choice

    case "$blockchain_choice" in
        [1]* ) blockchain="${blockchain_prompt[0]}"; break;;
        [2]* ) blockchain="${blockchain_prompt[1]}"; break;;
        [3]* ) blockchain="${blockchain_prompt[2]}"; break;;
        [eE]* ) text_color $RED "Installer stopped by user"; exit;;
        * ) text_color $RED "Invalid choice. Please enter a valid number."; continue;;
    esac
done


# Function to validate Operator Fees input
validate_operator_fees() {
    local blockchain=$1
    local operator_fee_variable="${blockchain}_OPERATOR_FEES"

    read -p "Enter Operator Fees (0% - 100%) for $blockchain: " OPERATOR_FEES
    if (( OPERATOR_FEES >= 0 && OPERATOR_FEES <= 100 )); then
        text_color $GREEN "Operator Fees for $blockchain: $OPERATOR_FEES"
        eval "${operator_fee_variable}=$OPERATOR_FEES"
    else
        text_color $RED "Please enter Operator Fees in the range of 0% - 100%. Try again."
        validate_operator_fees $blockchain
    fi
}


# Case statement to handle blockchain-specific configurations
case "$blockchain" in
    "OriginTrail Parachain" | "Gnosis" )


        if [ "$blockchain" == "OriginTrail Parachain" ]; then
                blockchain="OTP"
        fi


        # Input wallets for the selected blockchain
        request_operational_wallet_keys $blockchain
        EVM_OP_WALLET_KEYS_BLOCKCHAIN=$OP_WALLET_KEYS_JSON

        read -p "Enter your EVM management wallet address for $blockchain: " EVM_MANAGEMENT_WALLET
        text_color $GREEN "EVM management wallet address for $blockchain: $EVM_MANAGEMENT_WALLET"

        read -p "Enter your profile shares token name for $blockchain: " SHARES_TOKEN_NAME
        text_color $GREEN "Profile shares token name for $blockchain: $SHARES_TOKEN_NAME"

        read -p "Enter your profile shares token symbol for $blockchain: " SHARES_TOKEN_SYMBOL
        text_color $GREEN "Profile shares token symbol for $blockchain: $SHARES_TOKEN_SYMBOL"

        # Prompt and validate Operator Fees for the first blockchain
        validate_operator_fees $blockchain
        eval "OPERATOR_FEE=\$${blockchain}_OPERATOR_FEES"

        if [ "$blockchain" == "Gnosis" ]; then
            read -p "Enter your Gnosis RPC endpoint: "  GNOSIS_RPC_ENDPOINT
            text_color $GREEN "Gnosis RPC endpoint: $GNOSIS_RPC_ENDPOINT"
        fi


        ;;
    "Both" )
        if [ "$nodeEnv" == "mainnet" ]; then
            blockchain1="OTP"
            blockchain2="Gnosis"
        elif [ "$nodeEnv" == "testnet" ]; then
            blockchain1="OTP"
            blockchain2="Gnosis"
        fi

        # Input wallets for the first blockchain
        request_operational_wallet_keys $blockchain1
        EVM_OP_WALLET_KEYS_BLOCKCHAIN1=$OP_WALLET_KEYS_JSON

        read -p "Enter your EVM management wallet address for $blockchain1: " EVM_MANAGEMENT_WALLET
        text_color $GREEN "EVM management wallet address for $blockchain1: $EVM_MANAGEMENT_WALLET"

        read -p "Enter your profile shares token name for $blockchain1: " SHARES_TOKEN_NAME
        text_color $GREEN "Profile shares token name for $blockchain1: $SHARES_TOKEN_NAME"

        read -p "Enter your profile shares token symbol for $blockchain1: " SHARES_TOKEN_SYMBOL
        text_color $GREEN "Profile shares token symbol for $blockchain1: $SHARES_TOKEN_SYMBOL"

        # Prompt and validate Operator Fees for the first blockchain
        validate_operator_fees $blockchain1
        OPERATOR_FEES_1=$OTP_OPERATOR_FEES

        # Input wallets for the second blockchain
        request_operational_wallet_keys $blockchain2
        EVM_OP_WALLET_KEYS_BLOCKCHAIN2=$OP_WALLET_KEYS_JSON

        read -p "Enter your EVM management wallet address for $blockchain2: " EVM_MANAGEMENT_WALLET_2
        text_color $GREEN "EVM management wallet address for $blockchain2: $EVM_MANAGEMENT_WALLET_2"

        read -p "Enter your profile shares token name for $blockchain2: " SHARES_TOKEN_NAME_2
        text_color $GREEN "Profile shares token name for $blockchain2: $SHARES_TOKEN_NAME_2"

        read -p "Enter your profile shares token symbol for $blockchain2: " SHARES_TOKEN_SYMBOL_2
        text_color $GREEN "Profile shares token symbol for $blockchain2: $SHARES_TOKEN_SYMBOL_2"

        # Prompt and validate Operator Fees for the second blockchain
        validate_operator_fees $blockchain2
        OPERATOR_FEES_2=$Gnosis_OPERATOR_FEES


        read -p "Enter your Gnosis RPC endpoint: "  GNOSIS_RPC_ENDPOINT
        text_color $GREEN "Gnosis RPC endpoint: $GNOSIS_RPC_ENDPOINT"

        ;;
    * )
        text_color $RED "Invalid blockchain choice. Exiting installer."
        exit;;
esac


perform_step npm ci --omit=dev --ignore-scripts "Executing npm install"

CONFIG_DIR=$OTNODE_DIR/..
perform_step touch $CONFIG_DIR/.origintrail_noderc "Configuring node config file"
perform_step $(jq --null-input --arg tripleStore "$tripleStore" '{"logLevel": "trace", "auth": {"ipWhitelist": ["::1", "127.0.0.1"]}}' > $CONFIG_DIR/.origintrail_noderc) "Adding loglevel and auth values to node config file"


    perform_step $(jq --arg tripleStore "$tripleStore" --arg tripleStoreUrl "$tripleStoreUrl" '.modules.tripleStore.implementation[$tripleStore] |=
        {
            "enabled": "true",
            "config": {
                "repositories": {
                    "privateCurrent": {
                        "url": $tripleStoreUrl,
                        "name": "private-current",
                        "username": "admin",
                        "password": ""
                    },
                    "privateHistory": {
                        "url": $tripleStoreUrl,
                        "name": "private-history",
                        "username": "admin",
                        "password": ""
                    },
                    "publicCurrent": {
                        "url": $tripleStoreUrl,
                        "name": "public-current",
                        "username": "admin",
                        "password": ""
                    },
                    "publicHistory": {
                        "url": $tripleStoreUrl,
                        "name": "public-history",
                        "username": "admin",
                        "password": ""
                    }
                }
            }
        } + .' $CONFIG_DIR/.origintrail_noderc > $CONFIG_DIR/origintrail_noderc_tmp) "Adding node wallets to node config file 1/2"

    perform_step mv $CONFIG_DIR/origintrail_noderc_tmp $CONFIG_DIR/.origintrail_noderc "Adding node wallets to node config file 2/2"

# Set blockchain IDs based on the environment
if [ "$nodeEnv" == "mainnet" ]; then
    otp_blockchain_id=2043
    gnosis_blockchain_id=100
else
    otp_blockchain_id=20430
    gnosis_blockchain_id=10200
fi

# Check if "Both" blockchains are selected
if [ "$blockchain" == "Both" ]; then
  perform_step $(jq --arg otp_blockchain_id "$otp_blockchain_id" --argjson EVM_OP_WALLET_KEYS_BLOCKCHAIN1 "$EVM_OP_WALLET_KEYS_BLOCKCHAIN1" --argjson EVM_OP_WALLET_KEYS_BLOCKCHAIN2 "$EVM_OP_WALLET_KEYS_BLOCKCHAIN2" --arg EVM_MANAGEMENT_WALLET "$EVM_MANAGEMENT_WALLET" --arg SHARES_TOKEN_NAME "$SHARES_TOKEN_NAME" --arg SHARES_TOKEN_SYMBOL "$SHARES_TOKEN_SYMBOL" --argjson OPERATOR_FEES_1 "$OPERATOR_FEES_1" --argjson OPERATOR_FEES_2 "$OPERATOR_FEES_2" --arg gnosis_blockchain_id "$gnosis_blockchain_id" --arg EVM_OPERATIONAL_WALLET_2 "$EVM_OPERATIONAL_WALLET_2" --arg EVM_OPERATIONAL_PRIVATE_KEY_2 "$EVM_OPERATIONAL_PRIVATE_KEY_2" --arg EVM_MANAGEMENT_WALLET_2 "$EVM_MANAGEMENT_WALLET_2" --arg SHARES_TOKEN_NAME_2 "$SHARES_TOKEN_NAME_2" --arg SHARES_TOKEN_SYMBOL_2 "$SHARES_TOKEN_SYMBOL_2" --arg GNOSIS_RPC_ENDPOINT "$GNOSIS_RPC_ENDPOINT" '
    .modules.blockchain.implementation += {
      "otp:'$otp_blockchain_id'": {
        "enabled": true,
        "config": {
          "operationalWallets": $EVM_OP_WALLET_KEYS_BLOCKCHAIN1,
          "evmManagementWalletPublicKey": $EVM_MANAGEMENT_WALLET,
          "sharesTokenName": $SHARES_TOKEN_NAME,
          "sharesTokenSymbol": $SHARES_TOKEN_SYMBOL,
          "operatorFee": $OPERATOR_FEES_1
        }
      },
      "gnosis:'$gnosis_blockchain_id'": {
        "enabled": true,
        "config": {
          "operationalWallets": $EVM_OP_WALLET_KEYS_BLOCKCHAIN2,
          "evmManagementWalletPublicKey": $EVM_MANAGEMENT_WALLET_2,
          "sharesTokenName": $SHARES_TOKEN_NAME_2,
          "sharesTokenSymbol": $SHARES_TOKEN_SYMBOL_2,
          "operatorFee": $OPERATOR_FEES_2,
	  "rpcEndpoints": [$GNOSIS_RPC_ENDPOINT]
        }
      }
    }' $CONFIG_DIR/.origintrail_noderc > $CONFIG_DIR/origintrail_noderc_tmp) "Adding node wallets to node config file 1/2 for Both"
else


  # Single blockchain selected
  if [ "$blockchain" = "OriginTrail Parachain" ] || [ "$blockchain" = "OTP" ]; then
    blockchain="otp"
    blockchain_id="$otp_blockchain_id"
  elif [ "$blockchain" = "Gnosis" ]; then
    blockchain="gnosis"
    blockchain_id="$gnosis_blockchain_id"
  fi
  ADD_GNOSIS_RPC="false"
  if [ "$blockchain" = "gnosis" ]; then
    ADD_GNOSIS_RPC="true"
  fi

  blockchain_arg="$blockchain:$blockchain_id"

  jq --arg blockchain_arg "$blockchain_arg" \
     --argjson EVM_OP_WALLET_KEYS_BLOCKCHAIN "$EVM_OP_WALLET_KEYS_BLOCKCHAIN" \
     --arg EVM_MANAGEMENT_WALLET "$EVM_MANAGEMENT_WALLET" \
     --arg SHARES_TOKEN_NAME "$SHARES_TOKEN_NAME" \
     --arg SHARES_TOKEN_SYMBOL "$SHARES_TOKEN_SYMBOL" \
     --argjson ADD_GNOSIS_RPC "$ADD_GNOSIS_RPC" \
     --arg OPERATOR_FEE "$OPERATOR_FEE" \
     --arg GNOSIS_RPC_ENDPOINT "$GNOSIS_RPC_ENDPOINT" '
    (.modules.blockchain.implementation += {
      ($blockchain_arg): {
        "enabled": true,
        "config": {
          "operationalWallets": $EVM_OP_WALLET_KEYS_BLOCKCHAIN,
          "evmManagementWalletPublicKey": $EVM_MANAGEMENT_WALLET,
          "sharesTokenName": $SHARES_TOKEN_NAME,
          "sharesTokenSymbol": $SHARES_TOKEN_SYMBOL,
          "operatorFee": $OPERATOR_FEE

        }
      }
    }) | if $ADD_GNOSIS_RPC then .modules.blockchain.implementation[$blockchain_arg].config += {"rpcEndpoints": [$GNOSIS_RPC_ENDPOINT]} else . end
  ' "$CONFIG_DIR/.origintrail_noderc" > "$CONFIG_DIR/origintrail_noderc_tmp"
fi

    perform_step mv $CONFIG_DIR/origintrail_noderc_tmp $CONFIG_DIR/.origintrail_noderc "Adding node wallets to node config file 2/2"
    perform_step cp $OTNODE_DIR/installer/data/otnode.service /lib/systemd/system/ "Copying otnode service file"

    systemctl daemon-reload
    perform_step systemctl enable otnode "Enabling otnode"
    perform_step systemctl start otnode "Starting otnode"
    perform_step systemctl status otnode "otnode service status"
}

#For Arch Linux installation
if [[ ! -z $(grep "arch" "/etc/os-release") ]]; then
    source <(curl -s https://raw.githubusercontent.com/OriginTrail/ot-node/v6/develop/installer/data/archlinux)
fi



# Perform checks
header_color "Checking Ubuntu version"
check_ubuntu_version

header_color "Checking root privilege"
check_root



#### INSTALLATION START ####
clear

cd /root

header_color $BGREEN"Welcome to the OriginTrail Installer. Please sit back while the installer runs. "

header_color $BGREEN"Installing OriginTrail node pre-requisites..."

install_prereqs

header_color $BGREEN"Preparing OriginTrail node directory..."

if [[ -d "$OTNODE_DIR" ]]; then
    read -p "Previous ot-node directory detected. Would you like to overwrite it? (Default: Yes) [Y]es [N]o [E]xit " choice
    case "$choice" in
        [nN]* ) text_color $GREEN"Keeping previous ot-node directory.";;
        [eE]* ) text_color $RED"Installer stopped by user"; exit;;
        * ) text_color $GREEN"Reconfiguring ot-node directory."; systemctl is-active --quiet otnode && systemctl stop otnode; perform_step rm -rf $OTNODE_DIR "Deleting $OTNODE_DIR"; install_directory;;
    esac
else
    install_directory
fi

OTNODE_DIR=$OTNODE_DIR/current

header_color $BGREEN"Installing Triplestore (Graph Database)..."

read -p "Please select the database you would like to use: (Default: Blazegraph) [1]Blazegraph [2]Fuseki [E]xit: " choice
case "$choice" in
    [2] ) text_color $GREEN"Fuseki selected. Proceeding with installation."; tripleStore=ot-fuseki; tripleStoreUrl="http://localhost:3030";;
    [Ee] )  text_color $RED"Installer stopped by user"; exit;;
    * )     text_color $GREEN"Blazegraph selected. Proceeding with installation."; tripleStore=ot-blazegraph; tripleStoreUrl="http://localhost:9999";;
esac

if [[ $tripleStore = "ot-fuseki" ]]; then
    if [[ -d "$OTNODE_DIR/../fuseki" ]]; then
        read -p "Previously installed Fuseki triplestore detected. Would you like to overwrite it? (Default: Yes) [Y]es [N]o [E]xit " choice
        case "$choice" in
            [nN]* ) text_color $GREEN"Keeping previous Fuseki installation.";;
            [eE]* ) text_color $RED"Installer stopped by user"; exit;;
            * )     text_color $GREEN"Reinstalling Fuseki."; perform_step rm -rf $OTNODE_DIR/../fuseki "Removing previous Fuseki installation"; install_fuseki;;
        esac
    else
        install_fuseki
    fi
fi

if [[ $tripleStore = "ot-blazegraph" ]]; then
    if [[ -f "blazegraph.jar" ]]; then
        read -p "Previously installed Blazegraph triplestore detected. Would you like to overwrite it? (Default: Yes) [Y]es [N]o [E]xit " choice
        case "$choice" in
            [nN]* ) text_color $GREEN"Keeping old Blazegraph Installation.";;
            [eE]* ) text_color $RED"Installer stopped by user"; exit;;
            * )     text_color $GREEN"Reinstalling Blazegraph."; perform_step rm -rf blazegraph* "Removing previous Blazegraph installation"; install_blazegraph;;
        esac
    else
        install_blazegraph
    fi
fi

header_color $BGREEN"Installing SQL..."

install_sql

header_color $BGREEN"Configuring OriginTrail node..."

install_node

header_color $BGREEN"INSTALLATION COMPLETE !"

journalctl -u otnode --output cat -fn 200

text_color $GREEN "
New aliases added:
otnode-restart
otnode-stop
otnode-start
otnode-logs
otnode-config

To start using aliases, run:
source ~/.bashrc
"
text_color $YELLOW"Logs will be displayed. Press ctrl+c to exit the logs. The node WILL stay running after you return to the command prompt.

If the logs do not show and the screen hangs, press ctrl+c to exit the installation and reboot your server.

"
read -p "Press enter to continue..."
