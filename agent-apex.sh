#!/bin/bash

# Script para instalar o Apex Agent baseado no Zabbix Agent 7.0
# Desenvolvido por Kallil (Baseado em especificações)

# Diretório base do projeto
BASE_DIR="/opt/apex"
REPO_DIR="$BASE_DIR/repo"
CONFIG_DIR="$BASE_DIR/config"
SCRIPTS_DIR="$BASE_DIR/scripts"
AGENT_NAME="apex-agent"

# Função para detectar o sistema operacional detectando a distribuição
function detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        echo "Não foi possível detectar a distribuição Linux."
        exit 1
    fi
}

# Função para determinar arquitetura
function detect_architecture() {
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH_DIR="amd64"
    elif [[ "$ARCH" == "i686" || "$ARCH" == "i386" ]]; then
        ARCH_DIR="x32"
    else
        echo "Arquitetura não suportada: $ARCH"
        exit 1
    fi
}

# Função para configurar o repositório
function configure_repo() {
    echo "Configurando repositório para $OS ($ARCH_DIR)..."
    local REPO_PATH="$REPO_DIR/$OS/$VERSION_ID/$ARCH_DIR"

    if [[ ! -d "$REPO_PATH" ]]; then
        echo "Repositório não encontrado para $OS $VERSION_ID $ARCH_DIR em $REPO_PATH"
        exit 1
    fi

    case "$OS" in
        debian|ubuntu)
            cp "$REPO_PATH/zabbix.list" /etc/apt/sources.list.d/
            apt update
            ;;
        centos|alma|rocky|rhel|oracle)
            cp "$REPO_PATH/zabbix.repo" /etc/yum.repos.d/
            yum clean all
            ;;
        opensuse|suse)
            zypper ar "$REPO_PATH/zabbix.repo" zabbix
            zypper refresh
            ;;
        amazon)
            cp "$REPO_PATH/zabbix.repo" /etc/yum.repos.d/
            yum clean all
            ;;
        raspbian)
            cp "$REPO_PATH/zabbix.list" /etc/apt/sources.list.d/
            apt update
            ;;
        *)
            echo "Sistema operacional não suportado para configuração do repositório."
            exit 1
            ;;
    esac
}

# Função para instalar o agente
function install_agent() {
    echo "Instalando o Apex Agent..."

    case "$OS" in
        debian|ubuntu|raspbian)
            apt install -y zabbix-agent
            ;;
        centos|alma|rocky|rhel|oracle|amazon)
            yum install -y zabbix-agent
            ;;
        opensuse|suse)
            zypper install -y zabbix-agent
            ;;
        *)
            echo "Sistema operacional não suportado para instalação."
            exit 1
            ;;
    esac

    # Realoca binários e configurações
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SCRIPTS_DIR"

    mv /etc/zabbix/zabbix_agentd.conf "$CONFIG_DIR/zabbix_agentd.conf"
    mv /etc/zabbix/zabbix_agentd.d "$CONFIG_DIR/zabbix_agentd.d"
    mv /usr/sbin/zabbix_agentd "$BASE_DIR/$AGENT_NAME"

    # Criar serviço customizado
    cat <<EOF > /etc/systemd/system/$AGENT_NAME.service
[Unit]
Description=Apex Agent (Baseado no Zabbix Agent)
After=network.target

[Service]
Type=simple
ExecStart=$BASE_DIR/$AGENT_NAME -c $CONFIG_DIR/zabbix_agentd.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Ativar e iniciar o serviço
    systemctl daemon-reload
    systemctl enable $AGENT_NAME
    systemctl start $AGENT_NAME

    # Verificar se o serviço iniciou corretamente
    if systemctl is-active --quiet $AGENT_NAME; then
        echo "$AGENT_NAME iniciado com sucesso."
    else
        echo "Falha ao iniciar $AGENT_NAME. Verifique os logs para mais detalhes."
        exit 1
    fi
}

# Função principal
function main() {
    detect_os
    detect_architecture
    configure_repo
    install_agent

    echo "Instalação do Apex Agent concluída com sucesso."
    echo "Arquivos instalados em $BASE_DIR."
}

# Executar função principal
main
