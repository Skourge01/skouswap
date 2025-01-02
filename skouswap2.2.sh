#!/bin/bash

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "Este script precisa ser executado como root"
    exit 1
fi

zram_file() {
    clear
    echo "=== Configuração de ZRAM ou Swapfile ==="
    echo "1. Ativar ZRAM"
    echo "2. Ativar Swapfile"
    echo "3. Desativar ZRAM"
    echo "4. Voltar"
    
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

            echo "=== Selecione o tamanho do ZRAM ==="
            echo "1. 2GB"
            echo "2. 4GB"
            echo "3. 6GB"
            echo "4. 8GB"
            echo "5. 10GB"
            echo "6. 12GB"
            echo "7. 14GB"
            echo "8. 16GB"
            echo "9. Voltar"
            
            read -p "Escolha o tamanho: " size_option
            
            case $size_option in
                1) zram_size=2G ;;
                2) zram_size=4G ;;
                3) zram_size=6G ;;
                4) zram_size=8G ;;
                5) zram_size=10G ;;
                6) zram_size=12G ;;
                7) zram_size=14G ;;
                8) zram_size=16G ;;
                9) return ;;
                *)
                    echo "Opção inválida!"
                    return
                    ;;
            esac

            # Ativar ZRAM
            echo "Ativando ZRAM com ${zram_size}..."
            sudo modprobe zram
            echo lz4 | sudo tee /sys/block/zram0/comp_algorithm
            echo $zram_size | sudo tee /sys/block/zram0/disksize
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
zram_size="'"$zram_size"'"

# Converter tamanho de GB para bytes
size_num=\${zram_size//[!0-9]/}
size_bytes=\$((size_num * 1024 * 1024 * 1024))

# Aguardar a criação do dispositivo
while [ ! -e /dev/zram0 ]; do
    sleep 1
done

# Configurar ZRAM
echo lz4 > /sys/block/zram0/comp_algorithm
echo \$size_bytes > /sys/block/zram0/disksize

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
            clear
            echo "Ativando Swapfile..."
            # Definir o tamanho do swapfile
            read -p "Escolha o tamanho do swapfile (exemplo: 4G): " swap_size
            
            # Criar o arquivo de swap
            sudo fallocate -l $swap_size /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile

            # Adicionar swapfile no fstab
            sudo bash -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'

            echo "Swapfile de $swap_size ativado com sucesso!"
            free -h
            ;;
        3)
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
        4)
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
 ____  _                                      ____    ____  
/ ___|| | _____  _   _ _____      ____ _ _ __|___ \  |___ \ 
\___ \| |/ / _ \| | | / __\ \ /\ / / _` | '_ \ __) |   __) |
 ___) |   < (_) | |_| \__ \\ V  V / (_| | |_) / __/ _ / __/ 
|____/|_|\_\___/ \__,_|___/ \_/\_/ \__,_| .__/_____(_)_____|
                                        |_|                  
EOF
    echo "=== Menu Principal ==="
    echo "1. ZRAM ou Swapfile"
    echo "2. Sair"
    read -p "Escolha uma opção: " opcao
    
    case $opcao in
        1) zram_file ;;
        2) exit 0 ;;
        *) echo "Opção inválida!" ;;
    esac
    
    read -p "Pressione ENTER para continuar..."
done
