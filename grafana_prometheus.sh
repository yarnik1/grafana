#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color
PROMETEUS_VERSION=2.28.1
GRAFANA_VERSION=8.0.6
#Functions

install_prometheus() {
    
    if [[ -d "$HOME/prometheus/" ]] && [[ -f "$HOME/prometheus/prometheus.yml" ]];
    then
        echo -n "Prometheus is already installed! Are you sure you want to replace it?(y/n)? "
        read -r answer
        if [ "$answer" != "${answer#[Nn]}" ];
        then
            echo -e "Terminating Prometheus installation.\n"
            
            echo -e "Check Prometheus logs:\n"
            echo  -e "sudo journalctl -u prometheusd -f\n"
            exit
        else
            mkdir "$HOME/backups"
            cp "$HOME/prometheus/prometheus.yml" "$HOME/backups"
            
            echo -e "Old prometheus.yml moved to $HOME/backups\n"
            
            rm -rf "$HOME/prometheus"
            rm /etc/systemd/system/prometheusd.service
        fi
    fi
    
    echo -e "Updating packages...\n"
    
    sudo apt-get update && sudo apt-get upgrade -y
    
    echo -e "Installing Prometheus...\n"
    
    wget "https://github.com/prometheus/prometheus/releases/download/v${PROMETEUS_VERSION}/prometheus-${PROMETEUS_VERSION}.linux-amd64.tar.gz" && \
    tar xvf "prometheus-${PROMETEUS_VERSION}.linux-amd64.tar.gz" && \
    rm "prometheus-${PROMETEUS_VERSION}.linux-amd64.tar.gz" && \
    mv "prometheus-${PROMETEUS_VERSION}.linux-amd64" prometheus
    
    chmod +x "$HOME/prometheus/prometheus"
    
    sed -i.bak "/localhost/d" "$HOME/prometheus/prometheus.yml"
    
    sed -i.bak "s/prometheus/node_exporter/" "$HOME/prometheus/prometheus.yml"
    
    echo -e "Creating prometheusd service file...\n"
    
    printf %s "[Unit]
    Description=prometheus
    After=network-online.target
    [Service]
    User=$USER
    ExecStart=$HOME/prometheus/prometheus \
    --config.file=$HOME/prometheus/prometheus.yml
    Restart=always
    RestartSec=3
    LimitNOFILE=65535
    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/prometheusd.service
    
    echo -e "Enabling prometheusd service...\n"
    
    sudo systemctl daemon-reload
    sudo systemctl enable prometheusd
    sudo systemctl restart prometheusd
    
    echo -e "Prometheus is running!\n"
    
    echo -e "Check Prometheus logs:\n"
    echo  -e "sudo journalctl -u prometheusd -f\n"
}

install_grafana() {
    
    if [[ -f $(which grafana-server) ]];
    then
        echo -n "Grafana service is already created! Are you sure to re-install?(y/n)? "
        read -r answer
        if [ "$answer" != "${answer#[Nn]}" ];
        then
            echo -e "Terminating...\n"
            
            echo -e "Check Grafana logs:\n"
            echo -e "sudo journalctl -u grafana-server -f\n"
            exit
        else
            sudo apt-get purge grafana -y
        fi
    fi
    
    echo -e "Updating packages...\n"
    
    sudo apt-get update && sudo apt-get upgrade -y
    
    echo -e "Installing Grafana...\n"
    
    sudo apt-get install -y adduser libfontconfig1 && \
    wget "https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_amd64.deb" && \
    sudo dpkg -i "grafana_${GRAFANA_VERSION}_amd64.deb" && \
    rm -rf "grafana_${GRAFANA_VERSION}_amd64.deb"
    
    echo -e "Enabling grafana-server service...\n"
    
    sudo systemctl daemon-reload
    sudo systemctl enable grafana-server
    sudo systemctl restart grafana-server
    
    echo -e "Grafana is running!\n"
    
    echo -e "Check Grafana logs:\n"
    echo -e "sudo journalctl -u grafana-server -f\n"
}

add_node_to_config() {
    
    if [[ ! -d "$HOME/prometheus/" ]] && [[ ! -f "$HOME/prometheus/prometheus.yml" ]];
    then
        echo -e "${RED}ERR: Could not find prometheus.yml!${NC}\n"
        exit
    fi
    
    read -rp "Provide an IP of your node: " nodeIP
    read -rp "Provde a name of your node: " nodeName
    
    NODE=$(grep "$nodeIP" "$HOME/prometheus/prometheus.yml" -A 5)
    
    if [ "$NODE" ];
    then
        echo -e "${RED}Prometeus.yml is already contains a node with IP ${nodeIP}!${NC}\n"
        echo "$NODE"
        # TODO: implement overriding
        exit
    fi
    
    echo -e "Adding node with $nodeIP IP and $nodeName label to prometheus.yml...\n"
    
    sed -i.bak '$a\
    - targets: ['"$nodeIP"':9100]\
      labels:\
    label: "'"$nodeName"'"' "$HOME/prometheus/prometheus.yml"
    
    echo -e "prometheus.yml is updated!\n"
    
    echo -e "Reloading grafana-server and prometheusd...\n"
    
    sudo systemctl daemon-reload && \
    sudo systemctl restart grafana-server && \
    sudo systemctl restart prometheusd
    
    echo -e "Grafana and Prometheus are both running!\n"
    
    echo -e "Check Prometheus logs:\n"
    echo -e "sudo journalctl -u prometheusd -f\n"
    
    echo -e "Check Grafana logs:\n"
    echo -e "sudo journalctl -u grafana-server -f\n"
}

remove_node_from_config() {
    
    if [[ ! -d "$HOME/prometheus/" ]] && [[ ! -f "$HOME/prometheus/prometheus.yml" ]];
    then
        echo -e "\n${RED}ERR: Could not find prometheus.yml!${NC}\n"
        exit
    fi
    
    read -rp "Provide an IP of your node: " nodeIP
    
    NODE=$(grep "$nodeIP" "$HOME/prometheus/prometheus.yml")
    
    if [ ! "$NODE" ];
    then
        echo -e "${RED}Prometeus.yml does not contain a node with IP ${nodeIP}. Please check provided node IP.\n"
        echo "$NODE"
        # implement overriding
        exit
    fi
    
    echo -e "Removing node with $nodeIP IP from prometheus.yml...\n"
    
    sed -i.bak "/$nodeIP:9100/,+2 d" "$HOME/prometheus/prometheus.yml"
    
    echo -e "prometheus.yml is updated!\n"
    
    echo -e "Reloading grafana-server and prometheusd...\n"
    
    sudo systemctl daemon-reload && \
    sudo systemctl restart grafana-server && \
    sudo systemctl restart prometheusd
    
    echo -e "Grafana and Prometheus are both running!\n"
    
    echo -e "Check Prometheus logs:\n"
    echo -e "sudo journalctl -u prometheusd -f\n"
    
    echo -e "Check Grafana logs:\n"
    echo -e "sudo journalctl -u grafana-server -f\n"
}

remove_prometheus() {
    echo -e "Removing Prometheus...\n"
    
    rm -rf "$HOME/prometheus"
    rm /etc/systemd/system/prometheusd.service
    
    echo -e "Prometheus has been sucessfully deleted!\n"
}

remove_grafana() {
    echo -e "Removing Grafana...\n"
    
    sudo apt-get purge grafana -y
    
    echo -e "Grafana has been sucessfully deleted!\n"
}

remove_grafana_prometheus() {
    uninstall_grafana
    uninstall_prometheus
}

main() {
    PS3="Choose an option: "
    options=(
        "Install Prometheus package"
        "Install Grafana package"
        "Add node to Prometheus config"
        "Remove node from Prometheus config"
        "Remove Prometheus"
        "Remove Grafana"
        "Remove both Prometheus and Grafana"
        "Quit"
    )
    
    select opt in "${options[@]}"
    do
        case $opt in
            "Install Prometheus package")
                install_prometheus
                break
            ;;
            "Install Grafana package")
                install_grafana
                break
            ;;
            "Add node to Prometheus config")
                add_node_to_config
                break
            ;;
            "Remove node from Prometheus config")
                remove_node_from_config
                break
            ;;
            "Remove Prometheus")
                remove_prometheus
                break
            ;;
            "Remove Grafana")
                remove_grafana
                break
            ;;
            "Remove both Prometheus and Grafana")
                remove_grafana_prometheus
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