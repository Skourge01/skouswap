#!/bin/bash 
# skouswap2.6.sh 
# disponibilidade para debian based
# agora apenas ira dar cat com zram generator 
# mudando apenas um valor e concluindo 
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Este script precisa ser executado como root."
        read -p "Deseja executar como root? (s/n): " answer
        if [[ "$answer" =~ ^[Ss]$ ]]; then
            # Chama o script novamente com sudo e passa os argumentos, se houver
            sudo "$0" "${@}"   # "$@" é seguro de usar aqui, já que são passados os argumentos do script
            exit 0
        else
            exit 1
        fi
    fi
}
check_fzf () {
    if ! command -v fzf &> /dev/null; then 
        read -p "O fzf não está instalado. Deseja instalá-lo? (s/n): " choice
        if [[ "$choice" == [sS] ]]; then 
            if [[ -f /etc/arch-release ]]; then
                sudo pacman -S fzf
            elif [[ -f /etc/debian_version ]]; then
                sudo apt update && sudo apt install fzf
            fi
        else 
            echo "Instalação do fzf cancelada." 
        fi 
    else
        echo "O fzf já está instalado."
    fi
}

gerenciador_pacotes() {
    if command -v apt-get > /dev/null; then
        # Verifica se é Ubuntu ou Debian
        if [ -f /etc/debian_version ]; then
            echo "APT"
        else
            echo "Gerenciador de pacotes não suportado."
            exit 1
        fi
    elif command -v pacman > /dev/null; then
        echo "Pacman"
    else
        echo "Gerenciador de pacotes não suportado."
        exit 1
    fi
}
instalar_zram_generator() {
    local gerenciador=$(gerenciador_pacotes)

    case $gerenciador in
        APT)
            if ! dpkg -l | grep -q "zram-tools"; then
                echo "Instalando zram-tools..."
                apt-get update
                apt-get install -y zram-tools
                
                # Configuração específica para Debian/Ubuntu
                if [ -f /etc/default/zramswap ]; then
                    sed -i 's/^ALGO=.*/ALGO=lz4/' /etc/default/zramswap
                    systemctl restart zramswap
                fi
            else
                echo "zram-tools já está instalado."
            fi
            ;;
        Pacman)
            if ! pacman -Qi zram-generator &> /dev/null; then
                echo "Instalando zram-generator..."
                pacman -Sy --noconfirm zram-generator
            else
                echo "zram-generator já está instalado."
            fi
            ;;
        *)
            echo "Gerenciador de pacotes não suportado."
            exit 1
            ;;
    esac
}
# Funções para cálculo específico de cada porcentagem
calculate_50_percent() {
    local ram_total=$1
    echo $(( ram_total / 2 ))
}

calculate_75_percent() {
    local ram_total=$1
    echo $(( (ram_total * 3) / 4 ))
}

calculate_100_percent() {
    local ram_total=$1
    echo $ram_total
}
# Função principal para calcular o tamanho do ZRAM
calculate_zram_size() {
    local ram_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    local percentage=$1
    
    case $percentage in
        50)
            calculate_50_percent $ram_total
            ;;
        75)
            calculate_75_percent $ram_total
            ;;
        100)
            calculate_100_percent $ram_total
            ;;
        *)
            echo 0
            ;;
    esac
}
# Função para atualizar o arquivo de configuração
update_zram_config() {
    local percentage=$1
    ZRAM_SIZE=$(calculate_zram_size $percentage)
    
    if [ "$ZRAM_SIZE" -eq 0 ]; then
        echo "Opção inválida."
        return
    fi

    local gerenciador=$(gerenciador_pacotes)
    
    case $gerenciador in
        APT)
            # Configuração para Debian/Ubuntu
            echo "Atualizando o arquivo de configuração do ZRAM para $ZRAM_SIZE MB..."
            echo "PERCENT=$percentage" | sudo tee /etc/default/zramswap > /dev/null
            echo "ALGO=lz4" | sudo tee -a /etc/default/zramswap > /dev/null
            systemctl restart zramswap
            ;;
        Pacman)
            # Configuração para Arch Linux
            echo "Atualizando o arquivo de configuração do ZRAM para $ZRAM_SIZE MB..."
            echo -e "[zram0]\nzram-size = $ZRAM_SIZE" | sudo tee /etc/systemd/zram-generator.conf > /dev/null
            systemctl restart systemd-zram-setup@zram0
            ;;
    esac
    
    echo "Arquivo atualizado com sucesso."
    sleep 2
}
# Submenu de escolha de porcentagem
submenu_zram() {
    OPTION=$(echo -e "50%\n75%\n100%" | fzf --prompt="Escolha a porcentagem de ZRAM: ")

    case $OPTION in
        "50%")
            update_zram_config 50
            ;;
        "75%")
            update_zram_config 75
            ;;
        "100%")
            update_zram_config 100
            ;;
        *)
            echo "Opção inválida."
            sleep 2
            ;;
    esac
}
create_swapfile() {
    local size_mb=$1
    local swapfile="/swapfile"

    # Desativar e remover swapfile existente
    if swapon --show | grep -q "$swapfile"; then
        echo "Desativando swapfile existente..."
        swapoff "$swapfile" 2>/dev/null
    fi
    
    if [ -f "$swapfile" ]; then
        echo "Removendo swapfile antigo..."
        rm -f "$swapfile"
    fi

    echo "Criando swapfile de ${size_mb}MB..."
    # Criar novo swapfile com fallocate (mais rápido) ou dd como fallback
    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l ${size_mb}M "$swapfile" || \
        dd if=/dev/zero of="$swapfile" bs=1M count="$size_mb" status=progress
    else
        dd if=/dev/zero of="$swapfile" bs=1M count="$size_mb" status=progress
    fi
    
    chmod 600 "$swapfile"
    mkswap "$swapfile"
    swapon "$swapfile"
    
    # Atualizar /etc/fstab
    if ! grep -q "$swapfile" /etc/fstab; then
        echo "$swapfile none swap defaults 0 0" >> /etc/fstab
    fi
    
    echo "Swapfile criado e ativado com sucesso."
    echo "Tamanho atual do swap:"
    free -h | grep Swap
    sleep 2
}
submenu_swapfile() {
    local sizes=("256MB" "512MB" "1GB" "2GB" "4GB" "6GB" "8GB" "10GB")
    local size_values=(256 512 1024 2048 4096 6144 8192 10240)
    
    OPTION=$(printf "%s\n" "${sizes[@]}" | fzf --prompt="Escolha o tamanho do swapfile: ")
    
    case $OPTION in
        "256MB")  create_swapfile 256 ;;
        "512MB")  create_swapfile 512 ;;
        "1GB")    create_swapfile 1024 ;;
        "2GB")    create_swapfile 2048 ;;
        "4GB")    create_swapfile 4096 ;;
        "6GB")    create_swapfile 6144 ;;
        "8GB")    create_swapfile 8192 ;;
        "10GB")   create_swapfile 10240 ;;
        *)
            echo "Opção inválida."
            sleep 2
            ;;
    esac
}
check_root 
gerenciador_pacotes
instalar_zram_generator
check_fzf 
# Loop principal do menu
while true; do
    OPTION=$(echo -e "ZRAM\nSwapfile\nSair" | fzf --prompt="Escolha uma opção: ")

    case $OPTION in
        "ZRAM")
            submenu_zram
            ;;
        "Swapfile")
            submenu_swapfile
            ;;
        "Sair")
            echo "Saindo..."
            break
            ;;
        *)
            echo "Opção inválida. Tente novamente."
            sleep 2
            ;;
    esac
done