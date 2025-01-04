#!/bin/bash

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
            # Verificar se o zram-generator está instalado
            if ! pacman -Qi zram-generator &> /dev/null; then
                echo "zram-generator não está instalado. Tentando instalar..."
                
                # Atualizar banco de dados do pacman primeiro
                sudo pacman -Sy
                
                # Tentar instalar o zram-generator
                if ! sudo pacman -S --noconfirm zram-generator; then
                    echo "Erro ao instalar zram-generator. Abortando..."
                    return 1
                fi
            fi

            # Primeiro, verifica e remove ZRAM existente
            if grep -q "zram0" /proc/swaps; then
                echo "Desativando ZRAM existente..."
                sudo swapoff /dev/zram0 2>/dev/null || true
                sudo systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
            fi

            # Parar serviços existentes e limpar completamente
            echo "Parando serviços ZRAM existentes..."
            sudo swapoff -a
            sudo systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
            
            # Forçar remoção do módulo zram
            echo "Removendo módulo ZRAM..."
            if lsmod | grep -q zram; then
                sudo rmmod zram || true
                sleep 2
            fi
            
            # Carregar módulo limpo
            echo "Carregando módulo ZRAM..."
            sudo modprobe zram
            sleep 2
            
            # Configurar ZRAM manualmente
            echo "Configurando ZRAM..."
            # Calcular exatamente 50% da RAM total em bytes
            total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            zram_size=$((total_ram_kb * 512)) # 50% da RAM (KB * 1024 / 2 = KB * 512)
            
            # Configurar número de streams baseado nos CPUs
            echo $(nproc) | sudo tee /sys/block/zram0/max_comp_streams
            
            # Configurar algoritmo e tamanho
            echo "zstd" | sudo tee /sys/block/zram0/comp_algorithm
            echo $zram_size | sudo tee /sys/block/zram0/disksize
            
            # Criar e ativar swap
            echo "Ativando swap ZRAM..."
            sudo mkswap -f /dev/zram0
            sudo swapon -p 100 /dev/zram0

            # Ajustar parâmetros do kernel para otimizar uso do ZRAM
            echo 10 | sudo tee /proc/sys/vm/swappiness
            echo 50 | sudo tee /proc/sys/vm/vfs_cache_pressure

            # Verificar status final
            echo "Status final do ZRAM:"
            if grep -q "zram0" /proc/swaps; then
                echo "ZRAM ativado com sucesso!"
                echo "Tamanho configurado: $((zram_size / 1024 / 1024))MB"
                swapon --show
                echo "Algoritmo de compressão:"
                cat /sys/block/zram0/comp_algorithm
            else
                echo "Falha ao ativar ZRAM"
                echo "Logs do kernel:"
                dmesg | tail -n 20
                echo "Status do módulo zram:"
                lsmod | grep zram
            fi
            free -h
            ;;
        2)
            if grep -q "zram0" /proc/swaps; then
                echo "Desativando ZRAM..."
                sudo swapoff /dev/zram0 2>/dev/null || true
                sudo systemctl stop systemd-zram-setup@zram0.service
                sudo rm -f /etc/systemd/zram-generator.conf
                sudo rm -f /etc/sysctl.d/99-zram.conf
                sudo systemctl daemon-reload
                echo "ZRAM desativado com sucesso!"
            else
                echo "ZRAM não está ativo!"
            fi
            ;;
        3)
            return
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac
}

# Menu principal
while true; do
    clear
    cat << "EOF"
 ____  _  _____  _   _ ______        ___    ____ ____    _____
/ ___|| |/ / _ \| | | / ___\ \      / / \  |  _ \___ \  |___ /
\___ \| ' / | | | | | \___ \\ \ /\ / / _ \ | |_) |__) |   |_ \
 ___) | . \ |_| | |_| |___) |\ V  V / ___ \|  __// __/ _ ___) |
|____/|_|\_\___/ \___/|____/  \_/\_/_/   \_\_|  |_____(_)____/
EOF
    echo "=== Menu Principal ==="
    echo "1. ZRAM"
    echo "2. Sair"
    read -p "Escolha uma opção: " opcao
    
    case $opcao in
        1) zram_file ;;
        2) exit 0 ;;
        *) echo "Opção inválida!" ;;
    esac
    
    read -p "Pressione ENTER para continuar..."
done
