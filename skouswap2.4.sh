#!/bin/bash
# Habilitar modo estrito de bash
set -euo pipefail
IFS=$'\n\t'

# Definir variáveis globais
declare -r SCRIPT_VERSION="2.4"
declare -r SCRIPT_NAME="$(basename "$0")"
declare -r LOG_FILE="/var/log/skouswap.log"

# Função de logging
log() {
    local level="$1"
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Função para tratamento de erros
error_handler() {
    local line_number=$1
    local error_code=$2
    log "ERROR" "Erro na linha ${line_number} (código: ${error_code})"
    exit "${error_code}"
}

trap 'error_handler ${LINENO} $?' ERR

# Função para verificar dependências
check_dependencies() {
    local deps=("swapon" "swapoff" "fallocate" "mkswap")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log "ERROR" "Dependência não encontrada: $dep"
            exit 1
        fi
    done
}

# Função para detectar hardware
detect_hardware() {
    local mem_total
    local cpu_cores
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    cpu_cores=$(nproc)
    
    # Exportar variáveis para uso global
    export TOTAL_RAM=$mem_total
    export CPU_CORES=$cpu_cores
    export IS_SSD=$([ "$(cat /sys/block/$(lsblk -no pkname $(findmnt -n -o SOURCE /))/queue/rotational)" = "0" ] && echo "true" || echo "false")
}

# Função otimizada para configurar ZRAM
configure_zram() {
    local size=$1
    local algorithm=${2:-"zstd"}
    local priority=${3:-100}
    
    # Parar serviços existentes
    systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
    swapoff -a || true
    
    # Remover e recarregar módulo
    if lsmod | grep -q zram; then
        rmmod zram || true
        sleep 1
    fi
    
    modprobe zram
    
    # Configurar ZRAM com valores otimizados
    echo "$CPU_CORES" > /sys/block/zram0/max_comp_streams
    echo "$algorithm" > /sys/block/zram0/comp_algorithm
    echo "$size" > /sys/block/zram0/disksize
    
    # Otimizar parâmetros do kernel
    sysctl -w vm.swappiness=10
    sysctl -w vm.vfs_cache_pressure=50
    sysctl -w vm.page-cluster=0
    
    mkswap -L zram0 /dev/zram0
    swapon -p "$priority" /dev/zram0
}

# Função otimizada para configurar swapfile
configure_swapfile() {
    local size=$1
    local path=${2:-"/swapfile"}
    
    # Desativar swap existente
    swapoff "$path" 2>/dev/null || true
    
    # Criar swapfile com alocação otimizada
    if "$IS_SSD"; then
        # Otimização para SSD
        fallocate -l "${size}M" "$path"
    else
        # Otimização para HDD
        dd if=/dev/zero of="$path" bs=1M count="$size" status=progress
    fi
    
    chmod 600 "$path"
    mkswap -L swapfile "$path"
    
    # Configurar parâmetros baseados no tipo de disco
    if "$IS_SSD"; then
        sysctl -w vm.swappiness=10
        sysctl -w vm.page-cluster=0
    else
        sysctl -w vm.swappiness=30
        sysctl -w vm.page-cluster=3
    fi
    
    swapon "$path"
    
    # Atualizar fstab se necessário
    if ! grep -q "$path" /etc/fstab; then
        echo "$path none swap defaults 0 0" >> /etc/fstab
    fi
}

# Função principal otimizada
main() {
    check_dependencies
    detect_hardware
    
    # Verificar root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script precisa ser executado como root"
        exit 1
    fi
    
    # Detectar distribuição
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=$ID
    else
        log "ERROR" "Não foi possível determinar a distribuição"
        exit 1
    fi
    
    # Menu principal com interface melhorada
    while true; do
        clear
        printf "\033[1;34m=== SKOUSWAP %s ===\033[0m\n" "$SCRIPT_VERSION"
        printf "Sistema: %s (%s)\n" "$DISTRO" "$PRETTY_NAME"
        printf "RAM Total: %s MB\n" "$((TOTAL_RAM/1024))"
        printf "CPUs: %s\n\n" "$CPU_CORES"
        
        echo "1. Configurar ZRAM"
        echo "2. Configurar Swapfile"
        echo "3. Sair"
        
        read -r -p "Escolha uma opção: " option
        
        case $option in
            1) zram_file ;;
            2) swapfile ;;
            3) exit 0 ;;
            *) log "WARN" "Opção inválida" ;;
        esac
    done
}

# Iniciar script
main "$@"
