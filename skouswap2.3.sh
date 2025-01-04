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
    echo "1. Ativar ZRAM (Tamanho 256MB até 10GB)"
    echo "2. Desativar ZRAM"
    echo "3. Voltar"
    
    read -p "Escolha uma opção: " zram_option
    
    case $zram_option in
        1)
            clear
            # Primeiro, verifica e remove ZRAM existente
            if grep -q "zram0" /proc/swaps; then
                echo "Desativando ZRAM existente..."
                sudo swapoff /dev/zram0
                sudo rmmod zram
                echo "ZRAM anterior removido."
            fi

            echo "=== Selecione o tamanho do ZRAM (em MB) ==="
            echo "1. 256MB"
            echo "2. 512MB"
            echo "3. 1024MB (1GB)"
            echo "4. 2048MB (2GB)"
            echo "5. 4096MB (4GB)"
            echo "6. 6144MB (6GB)"
            echo "7. 8192MB (8GB)"
            echo "8. 10240MB (10GB)"
            echo "9. Voltar"
            
            read -p "Escolha o tamanho: " size_option
            
            case $size_option in
                1) zram_size=256 ;;
                2) zram_size=512 ;;
                3) zram_size=1024 ;;
                4) zram_size=2048 ;;
                5) zram_size=4096 ;;
                6) zram_size=6144 ;;
                7) zram_size=8192 ;;
                8) zram_size=10240 ;;
                9) return ;;
                *)
                    echo "Opção inválida!"
                    return
                    ;;
            esac

            # Ativar ZRAM
            echo "Ativando ZRAM com ${zram_size}MB..."
            sudo modprobe zram
            echo lz4 | sudo tee /sys/block/zram0/comp_algorithm
            echo ${zram_size}M | sudo tee /sys/block/zram0/disksize
            sudo mkswap /dev/zram0
            sudo swapon -p 100 /dev/zram0
            echo "ZRAM ativado com sucesso!"

            # Criar serviço systemd para ativar ZRAM no boot
            echo "Criando o serviço systemd para ZRAM..."

            # Criar o script de inicialização /usr/local/bin/zram-init.sh
            sudo bash -c 'cat <<EOF > /usr/local/bin/zram-init.sh
#!/bin/bash

# Remover qualquer ZRAM existente
swapoff /dev/zram0 2>/dev/null || true
rmmod zram 2>/dev/null || true

# Aguardar um momento para garantir que o módulo foi removido
sleep 1

# Carregar módulo (caso ainda não esteja carregado)
modprobe zram

# Configuração de ZRAM
zram_size="'"$zram_size"'M"

# Aguardar a criação do dispositivo
while [ ! -e /dev/zram0 ]; do
    sleep 1
done

# Configurar ZRAM
echo lz4 > /sys/block/zram0/comp_algorithm
echo \$zram_size > /sys/block/zram0/disksize

# Criar e ativar swap
mkswap -L zram0 /dev/zram0
swapon -p 100 /dev/zram0

exit 0
EOF'

            # Tornar o script executável
            sudo chmod +x /usr/local/bin/zram-init.sh

            # Garantir que o módulo zram seja carregado no boot
            echo "zram" | sudo tee /etc/modules-load.d/zram.conf

            # Modificar o serviço systemd
            sudo bash -c 'cat <<EOF > /etc/systemd/system/zram-init.service
[Unit]
Description=Inicializa ZRAM
DefaultDependencies=no
Before=swap.target
After=local-fs.target
After=systemd-modules-load.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/modprobe zram
ExecStart=/usr/local/bin/zram-init.sh
ExecStop=/usr/bin/swapoff /dev/zram0
ExecStop=/usr/bin/rmmod zram

[Install]
WantedBy=swap.target
EOF'

            # Recarregar e reiniciar o serviço
            sudo systemctl daemon-reload
            sudo systemctl enable zram-init.service
            sudo systemctl start zram-init.service

            echo "ZRAM será iniciado automaticamente após o próximo reinício!"
            free -h
            ;;
        2)
            if grep -q "zram0" /proc/swaps; then
                echo "Desativando ZRAM..."
                sudo swapoff /dev/zram0
                sudo rmmod zram
                sudo systemctl disable zram-init.service
                sudo rm -f /etc/systemd/system/zram-init.service
                sudo rm -f /usr/local/bin/zram-init.sh
                sudo rm -f /etc/modules-load.d/zram.conf
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
