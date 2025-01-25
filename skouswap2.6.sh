#!/bin/bash
# skoswap2.5
# aumentar a disponibilidade entre distros linux
# distros: arch / debian

# Função para verificar se está rodando como root e pedir permissão se necessário
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Este script precisa ser executado como root."
        read -p "Deseja executar como root? (s/n): " answer
        if [[ "$answer" =~ ^[Ss]$ ]]; then
            sudo "$0" "$@"
            exit 0
        else
            exit 1
        fi
    fi
}

# Chama a função de verificação de root
check_root "$@"

# Obtém a distribuição do usuário e armazena na variável 'distro'
if [ -f /etc/os-release ]; then
    distro=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
elif [ -f /etc/lsb-release ]; then
    distro=$(grep "^DISTRIB_ID=" /etc/lsb-release | cut -d'=' -f2 | tr -d '"')
else
    distro="Desconhecido"
fi

echo "Distribuição do usuário: $distro"

# Função para verificar o gerenciador de pacotes
gerenciador_pacotes() {
    if command -v apt-get > /dev/null; then
        echo "APT"
    elif command -v pacman > /dev/null; then
        echo "Pacman"
    else
        echo "Gerenciador de pacotes não suportado."
        exit 1
    fi
}

# Função para instalar zram-generator
instalar_zram_generator() {
    local gerenciador=$(gerenciador_pacotes)

    case $gerenciador in
        APT)
            apt-get update
            apt-get install -y zram-tools
            ;;
        Pacman)
            pacman -Sy --noconfirm zram-generator
            ;;
        *)
            echo "Gerenciador de pacotes não suportado."
            exit 1
            ;;
    esac
}

# Função para desativar ZRAM
desativar_zram() {
    if grep -q "/dev/zram0" /proc/swaps; then
        echo "Desativando ZRAM..."
        swapoff /dev/zram0
        sleep 6  # Garantindo que o dispositivo tenha tempo para liberar
        zramctl --reset /dev/zram0 2>/dev/null
        echo "ZRAM desativado com sucesso."
    else
        echo "ZRAM não está ativo ou já foi desativado!"
    fi
}

# Função de configuração do ZRAM
zram_file() {
    choice=$(echo -e "1. Ativar ZRAM 50% da RAM\n2. Ativar ZRAM 100% da RAM\n3. Ativar ZRAM 75% da RAM\n4. Desativar ZRAM\n5. Voltar" | fzf --height 15 --border --ansi --prompt="Escolha uma opção: ")

    case $choice in
        "1. Ativar ZRAM 50% da RAM")
            configurar_zram 50
            ;;
        "2. Ativar ZRAM 100% da RAM")
            configurar_zram 100
            ;;
        "3. Ativar ZRAM 75% da RAM")
            configurar_zram 75
            ;;
        "4. Desativar ZRAM")
            desativar_zram
            ;;
        "5. Voltar")
            return
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
}

# Função para configurar o ZRAM com base na porcentagem fornecida
configurar_zram() {
    percent=$1

    # Instalar zram-generator se necessário
    instalar_zram_generator

    # Desativar ZRAM, se já estiver ativo, para garantir uma configuração limpa
    desativar_zram

    # Configurar ZRAM
    echo "Configurando ZRAM..."
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    zram_size=$((total_ram_kb * percent / 100))

    modprobe zram
    echo $(nproc) > /sys/block/zram0/max_comp_streams
    echo "zstd" > /sys/block/zram0/comp_algorithm
    echo $zram_size > /sys/block/zram0/disksize

    mkswap /dev/zram0
    swapon /dev/zram0

    echo "ZRAM ativado com sucesso."
}

# Função para configurar o Swapfile
swapfile() {
    choice=$(echo -e "1. 1GB\n2. 2GB\n3. 4GB\n4. 8GB\n5. 10GB\n6. Voltar" | fzf --height 15 --border --ansi --prompt="Escolha uma opção: ")

    case $choice in
        "1. 1GB") swap_size=1024 ;;
        "2. 2GB") swap_size=2048 ;;
        "3. 4GB") swap_size=4096 ;;
        "4. 8GB") swap_size=8192 ;;
        "5. 10GB") swap_size=10240 ;;
        "6. Voltar") return ;;
        *)
            echo "Opção inválida!"
            return
            ;;
    esac

    if grep -q "/swapfile" /proc/swaps; then
        swapoff /swapfile
        rm -f /swapfile
    fi

    fallocate -l ${swap_size}M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap defaults 0 0" >> /etc/fstab
    fi

    echo "Swapfile configurado com sucesso!"
    free -h
}

# Função para configurar o swappiness
swappiness() {
    clear
    echo "=== Configuração de Swappiness ==="

    # Exibe o valor atual do swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    echo "Valor atual de swappiness: $current_swappiness"

    # Solicita ao usuário um novo valor de swappiness
    read -p "Digite o novo valor para swappiness (0 a 100): " novo_swappiness

    # Valida a entrada para garantir que seja um número entre 0 e 100
    if [[ "$novo_swappiness" -ge 0 && "$novo_swappiness" -le 100 ]]; then
        # Atualiza o valor de swappiness no sistema
        echo "$novo_swappiness" > /proc/sys/vm/swappiness
        echo "Swappiness atualizado para $novo_swappiness."
        
        # Faz a mudança persistente no arquivo sysctl.conf
        if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
            echo "vm.swappiness=$novo_swappiness" >> /etc/sysctl.conf
        else
            sed -i "s/^vm.swappiness=.*/vm.swappiness=$novo_swappiness/" /etc/sysctl.conf
        fi
    else
        echo "Valor inválido! O valor deve estar entre 0 e 100."
    fi
}


# Menu principal usando fzf
while true; do
    choice=$(echo -e "ZRAM\nSwapfile\nSwappiness\nSair" | fzf --height 15 --border --ansi --prompt="Escolha uma opção: ")

    case $choice in
        "ZRAM") zram_file ;;
        "Swapfile") swapfile ;;
        "Swappiness") swappiness ;;  # Chama a função para configurar o swappiness
        "Sair") exit 0 ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
done

