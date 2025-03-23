#!/bin/bash 
# skouswap2.6.sh 
# availability for debian based
# now just give cat with zram generator
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script needs to be run as root."
        read -p "Do you want to run as root? (s/n): " answer
        if [[ "$answer" =~ ^[Ss]$ ]]; then
            #  Call the script again with sudo and pass the arguments if any
            sudo "$0" "${@}"   # "$@" is safe to use here, as script arguments are passed
            exit 0
        else
            exit 1
        fi
    fi
}
check_fzf () {
    if ! command -v fzf &> /dev/null; then 
        read -p "fzf is not installed. Do you want to install it? (s/n): " choice
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
        # Check if it is Ubuntu or Debian
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
                
                # Specific configuration for Debian/Ubuntu
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
# Functions for specific calculation of each percentage
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
calculate_110_percent() {
    local ram_total=$1
    echo $(( (ram_total * 110) / 100 ))
}

calculate_125_percent() {
    local ram_total=$1
    echo $(( (ram_total * 125) / 100 ))
}

calculate_150_percent() {
    local ram_total=$1
    echo $(( (ram_total * 150) / 100 ))
}

calculate_175_percent() {
    local ram_total=$1
    echo $(( (ram_total * 175) / 100 ))
}
# Main function to calculate ZRAM size
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
#Function to update the configuration file
update_zram_config() {
    local percentage=$1
    ZRAM_SIZE=$(calculate_zram_size $percentage)
    
    if [ "$ZRAM_SIZE" -eq 0 ]; then
        echo "Invalid option."
        return
    fi

    local gerenciador=$(gerenciador_pacotes)
    
    case $gerenciador in
        APT)
            # Debian/Ubuntu
            echo "Updating ZRAM configuration file to $ZRAM_SIZE MB..."
            echo "PERCENT=$percentage" | sudo tee /etc/default/zramswap > /dev/null
            echo "ALGO=lz4" | sudo tee -a /etc/default/zramswap > /dev/null
            systemctl restart zramswap
            ;;
        Pacman)
            # Arch Linux
            echo "Updating ZRAM configuration file to $ZRAM_SIZE MB..."
            echo -e "[zram0]\nzram-size = $ZRAM_SIZE" | sudo tee /etc/systemd/zram-generator.conf > /dev/null
            systemctl restart systemd-zram-setup@zram0
            ;;
    esac
    
    echo "file updated successfully."
    sleep 2
}

# Submenu de escolha da porcentagem do ZRAM
submenu_zram() {
    OPTION=$(echo -e "50%\n75%\n100%\n110%\n125%\n150%\n175%\nVoltar" | fzf --prompt="Escolha a porcentagem de ZRAM: ")

    case $OPTION in
        "50%") update_zram_config 50 ;;
        "75%") update_zram_config 75 ;;
        "100%") update_zram_config 100 ;;
        "110%") update_zram_config 110 ;;
        "125%") update_zram_config 125 ;;
        "150%") update_zram_config 150 ;;
        "175%") update_zram_config 175 ;;
        "Voltar") return ;;  # Simplesmente retorna ao menu anterior
        *) 
            echo "invalid option."
            sleep 2
            ;;
    esac
}
create_swapfile() {
    local size_mb=$1
    local swapfile="/swapfile"

    # Disable and remove existing swapfile
    if swapon --show | grep -q "$swapfile"; then
        echo "Disabling existing swapfile..."
        swapoff "$swapfile" 2>/dev/null
    fi
    
    if [ -f "$swapfile" ]; then
        echo "Removing old swapfile..."
        rm -f "$swapfile"
    fi

    echo "Criando swapfile de ${size_mb}MB..."
    # Create new swapfile with fallocate (faster) or dd as fallback
    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l ${size_mb}M "$swapfile" || \
        dd if=/dev/zero of="$swapfile" bs=1M count="$size_mb" status=progress
    else
        dd if=/dev/zero of="$swapfile" bs=1M count="$size_mb" status=progress
    fi
    
    chmod 600 "$swapfile"
    mkswap "$swapfile"
    swapon "$swapfile"
    
    # update /etc/fstab
    if ! grep -q "$swapfile" /etc/fstab; then
        echo "$swapfile none swap defaults 0 0" >> /etc/fstab
    fi
    
    echo "Swapfile created and activated successfully."
    echo "Current swap size:"
    free -h | grep Swap
    sleep 2
}
submenu_swapfile() {
    local sizes=("256MB" "512MB" "1GB" "2GB" "4GB" "6GB" "8GB" "10GB" "return")
    local size_values=(256 512 1024 2048 4096 6144 8192 10240)
    
    OPTION=$(printf "%s\n" "${sizes[@]}" | fzf --prompt="Choose swapfile size: ")
    
    case $OPTION in
        "256MB")  create_swapfile 256 ;;
        "512MB")  create_swapfile 512 ;;
        "1GB")    create_swapfile 1024 ;;
        "2GB")    create_swapfile 2048 ;;
        "4GB")    create_swapfile 4096 ;;
        "6GB")    create_swapfile 6144 ;;
        "8GB")    create_swapfile 8192 ;;
        "10GB")   create_swapfile 10240 ;;
        "return") return ;; 
        *)
            echo "Invalid option."
            sleep 2
            ;;
    esac
}
disable_swap() {
    sudo swapoff -a
}
check_root 
gerenciador_pacotes
instalar_zram_generator
check_fzf 
reboot_prompt() {
    read -p "To apply the changes, do you want to restart the system? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Restarting the system..."
        sudo reboot
    else
        echo "The system will not restart."
    fi
}

# Loop do menu principal
while true; do
    OPTION=$(echo -e "ZRAM\nSwapfile\nDisable Swap\nExit" | fzf --prompt="Choose an option: ")

    case $OPTION in
        "ZRAM")
            submenu_zram
            ;;
        "Swapfile")
            submenu_swapfile
            ;;
        "Disable Swap")
            echo "Disabling Swap..."
            disable_swap
            sleep 2
            ;;
        "Exit")
            echo "Exiting..."
            reboot_prompt
            break
            ;;
        *)
            echo "Invalid option. Try again."
            sleep 2
            ;;
    esac
done

