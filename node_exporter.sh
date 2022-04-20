#!/bin/bash
NODE_EXPORTER_VERSION=1.2.0
RED='\033[0;31m'
#Functions

intall_node_exporter() {
    
    if [[ -d $(which node_exporter) ]] && [[ -f "/etc/systemd/system/exporterd.service" ]];
    then
        echo -e "Node exporter package is already installed and service is already created! Are you sure to re-install?(y/n)? "
        read -r answer
        if [ "$answer" != "${answer#[Nn]}" ];
        then
            echo -e "Terminating...\n"
            return
        else
            rm -rf "$(which node_exporter)"
            rm etc/systemd/system/exporterd.service
        fi
    fi
    
    echo -e "Updating packages...\n"
    
    sudo apt-get update && sudo apt-get upgrade -y
    
    echo -e "Installing node_exporter package...\n"
    
    wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" && \
    tar xvf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" && \
    rm "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" && \
    sudo mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64" node_exporter && \
    chmod +x "$HOME/node_exporter/node_exporter" && \
    mv "$HOME/node_exporter/node_exporter" /usr/bin && \
    rm -Rvf "$HOME/node_exporter/"
    
    echo -e "Creating exporterd service file...\n"
    
    printf %s "[Unit]
    Description=node_exporter
    After=network-online.target
    [Service]
    User=$USER
    ExecStart=/usr/bin/node_exporter
    Restart=always
    RestartSec=3
    LimitNOFILE=65535
    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/exporterd.service
    
    echo -e "Enabling exporterd service...\n"
    
    sudo systemctl daemon-reload
    sudo systemctl enable exporterd
    sudo systemctl restart exporterd
    
    echo -e "Exporterd service is running!\n"
    
    echo -e "Check service logs:\n"
    echo -e "sudo journalctl -u exporterd -f\n"
}

remove_node_exporter() {
    echo -e "Removing node_exporter...\n"
    
    rm -rf "$(which node_exporter)"
    rm etc/systemd/system/exporterd.service
    
    echo -e "node_exporter has been sucessfully deleted!\n"
}

main() {
    PS3="Choose an option: "
    options=(
        "Install node_exporter package"
        "Remove node_exporter"
        "Quit"
    )
    
    select opt in "${options[@]}"
    do
        case $opt in
            "Install node_exporter package")
                intall_node_exporter
                break
            ;;
            "Remove node_exporter")
                remove_node_exporter
                break
            ;;
            "Quit")
                break
            ;;
            *)
                echo -e "\n${RED}Invalid option: $REPLY${NC}\n"
            ;;
        esac
    done
}

main