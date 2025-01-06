#!/bin/bash 
# skoswap2.4 
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
    if grep -q "zram0" /proc/swaps; then
        echo "Desativando ZRAM..."
        swapoff /dev/zram0
        sleep 5  # Aumentada a pausa para 5 segundos
        echo "ZRAM desativado com sucesso."
    else
        echo "ZRAM não está ativo!"
    fi
}

zram_file() {
    clear
    echo "=== Configuração de ZRAM ==="
    echo "1. Ativar ZRAM 50% da RAM"
    echo "2. Desativar ZRAM"
    echo "3. Voltar"
    
    read -p "Escolha uma opção: " zram_option
    
    case $zram_option in
        1)
            clear
            # Instalar zram-generator se necessário
            instalar_zram_generator

            # Desativar ZRAM, se já estiver ativo, para garantir uma configuração limpa
            desativar_zram

            # Configurar ZRAM
            echo "Configurando ZRAM..."
            total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            zram_size=$((total_ram_kb * 512)) # 50% da RAM

            modprobe zram
            echo $(nproc) > /sys/block/zram0/max_comp_streams
            echo "zstd" > /sys/block/zram0/comp_algorithm
            echo $zram_size > /sys/block/zram0/disksize

            mkswap /dev/zram0
            swapon /dev/zram0

            echo "ZRAM ativado com sucesso."
            ;;
        2)
            desativar_zram  # Chama a função para desativar ZRAM
            ;;
        3)
            return
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
}

swapfile() {
    clear
    echo "=== Configuração de Swapfile ==="
    echo "1. 1GB"
    echo "2. 2GB"
    echo "3. 4GB"
    echo "4. 8GB"
    echo "5. 10GB"
    echo "6. Voltar"
    
    read -p "Escolha uma opção: " swap_option
    
    case $swap_option in
        1) swap_size=1024 ;;
        2) swap_size=2048 ;;
        3) swap_size=4096 ;;
        4) swap_size=8192 ;;
        5) swap_size=10240 ;;
        6) return ;;
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

# Menu principal
while true; do
    clear
    printf "\033[1;34m=== SKOUSWAP2.4 %s ===\033[0m\n" 

    echo "=== seu sistema e $distro linux  ==="
    echo "1. ZRAM"
    echo "2. Swapfile"
    echo "3. Sair"
    read -p "Escolha uma opção: " opcao
    
    case $opcao in
        1) zram_file ;;
        2) swapfile ;;
        3) exit 0 ;;
        *) echo "Opção inválida!" ;;
    esac
    
    read -p "Pressione ENTER para continuar..."
done
