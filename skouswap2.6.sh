#!/bin/bash
# skouswap2.6.sh
# Available for Debian-based systems
# Now it will simply display with zram generator,
# changing just one value and finishing

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root."
        read -r -p "Do you want to re-execute the script with sudo? (y/n): " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            # Call the script again with sudo and pass any arguments
            if sudo -v; then
                sudo "$0"
            else
                echo "You do not have sudo privileges."
                exit 1
            fi
            exit 0
        else
            exit 1
        fi
    fi
}

check_fzf() {
    if ! command -v fzf &>/dev/null; then
        read -p "fzf is not installed. Do you want to install it? (y/n): " choice
        if [[ "$choice" == [yY] ]]; then
            if [[ -f /etc/arch-release ]]; then
                sudo pacman -S fzf
            elif [[ -f /etc/debian_version ]]; then
                sudo apt update && sudo apt install fzf
            fi
        else
            echo "fzf installation cancelled."
        fi
    else
        echo "fzf is already installed."
    fi
}

package_manager() {
    if command -v apt-get >/dev/null; then
        # Check if it is Ubuntu or Debian
        if [ -f /etc/debian_version ]; then
            echo "APT"
        else
            echo "Package manager not supported."
            exit 1
        fi
    elif command -v pacman >/dev/null; then
        echo "Pacman"
    else
        echo "Package manager not supported."
        exit 1
    fi
}

install_zram_generator() {
    local manager
    manager=$(package_manager)

    case $manager in
    APT)
        if ! dpkg -l | grep -q "zram-tools"; then
            echo "Installing zram-tools..."
            apt-get update
            apt-get install -y zram-tools

            # Specific configuration for Debian/Ubuntu
            if [ -f /etc/default/zramswap ]; then
                sed -i 's/^ALGO=.*/ALGO=lz4/' /etc/default/zramswap
                systemctl restart zramswap
            fi
        else
            echo "zram-tools is already installed."
        fi
        ;;
    Pacman)
        if ! pacman -Qi zram-generator &>/dev/null; then
            echo "Installing zram-generator..."
            pacman -Sy --noconfirm zram-generator
        else
            echo "zram-generator is already installed."
        fi
        ;;
    *)
        echo "Package manager not supported."
        exit 1
        ;;
    esac
}

# Functions for specific percentage calculations
calculate_50_percent() {
    local ram_total=$1
    echo $((ram_total / 2))
}

calculate_75_percent() {
    local ram_total=$1
    echo $(((ram_total * 3) / 4))
}

calculate_100_percent() {
    local ram_total=$1
    echo $ram_total
}

# Main function to calculate the ZRAM size
calculate_zram_size() {
    local ram_total
    ram_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
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

# Function to update the configuration file
update_zram_config() {
    local percentage=$1
    ZRAM_SIZE=$(calculate_zram_size $percentage)

    if [ "$ZRAM_SIZE" -eq 0 ]; then
        echo "Invalid option."
        return
    fi

    local manager
    manager=$(package_manager)

    case $manager in
    APT)
        # Configuration for Debian/Ubuntu
        echo "Updating the ZRAM configuration file to $ZRAM_SIZE MB..."
        echo "PERCENT=$percentage" | sudo tee /etc/default/zramswap >/dev/null
        echo "ALGO=lz4" | sudo tee -a /etc/default/zramswap >/dev/null
        systemctl restart zramswap
        ;;
    Pacman)
        # Configuration for Arch Linux
        echo "Updating the ZRAM configuration file to $ZRAM_SIZE MB..."
        echo -e "[zram0]\nzram-size = $ZRAM_SIZE" | sudo tee /etc/systemd/zram-generator.conf >/dev/null
        systemctl restart systemd-zram-setup@zram0
        ;;
    esac

    echo "File updated successfully."
    sleep 2
}

# Submenu for ZRAM percentage selection
submenu_zram() {
    OPTION=$(echo -e "50%\n75%\n100%" | fzf --prompt="Choose the ZRAM percentage: ")

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
        echo "Invalid option."
        sleep 2
        ;;
    esac
}

create_swapfile() {
    local size_mb=$1
    local swapfile="/swapfile"

    # Deactivate and remove existing swapfile
    if swapon --show | grep -q "$swapfile"; then
        echo "Deactivating existing swapfile..."
        swapoff "$swapfile" 2>/dev/null
    fi

    if [ -f "$swapfile" ]; then
        echo "Removing old swapfile..."
        rm -f "$swapfile"
    fi

    echo "Creating a swapfile of ${size_mb}MB..."
    # Create a new swapfile using fallocate (faster) or dd as fallback
    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l ${size_mb}M "$swapfile" ||
            dd if=/dev/zero of="$swapfile" bs=1M count="$size_mb" status=progress
    else
        dd if=/dev/zero of="$swapfile" bs=1M count="$size_mb" status=progress
    fi

    chmod 600 "$swapfile"
    mkswap "$swapfile"
    swapon "$swapfile"

    # Update /etc/fstab
    if ! grep -q "$swapfile" /etc/fstab; then
        echo "$swapfile none swap defaults 0 0" >>/etc/fstab
    fi

    echo "Swapfile created and activated successfully."
    echo "Current swap size:"
    free -h | grep Swap
    sleep 2
}

submenu_swapfile() {
    local sizes=("256MB" "512MB" "1GB" "2GB" "4GB" "6GB" "8GB" "10GB")
    local size_values=(256 512 1024 2048 4096 6144 8192 10240)

    OPTION=$(printf "%s\n" "${sizes[@]}" | fzf --prompt="Choose the swapfile size: ")

    local selected_index
    selected_index=$(printf "%s\n" "${sizes[@]}" | grep -n -m 1 -w "$OPTION" | cut -d':' -f1)

    if [[ -n "$selected_index" ]]; then
        local size=${size_values[$((selected_index - 1))]}
        create_swapfile "$size"
    else
        echo "Invalid option."
        sleep 2
    fi
}

check_root
package_manager
install_zram_generator
check_fzf

# Main menu loop
while true; do
    OPTION=$(echo -e "ZRAM\nSwapfile\nExit" | fzf --prompt="Choose an option: ")

    case $OPTION in
    "ZRAM")
        submenu_zram
        ;;
    "Swapfile")
        submenu_swapfile
        ;;
    "Exit")
        echo "Exiting..."
        break
        ;;
    *)
        echo "Invalid option. Try again."
        sleep 2
        ;;
    esac
done
