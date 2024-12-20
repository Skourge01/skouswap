#!/bin/bash
# Script para configurar Swapfile, compatível com várias distribuições

# Verifica se o zenity está instalado
if command -v zenity &> /dev/null
then
  echo "zenity já está instalado."
else
  echo "zenity não está instalado. Instalando..."
  
  # Detecta o sistema e instala o zenity
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "arch" || "$ID" == "manjaro" ]]; then
      sudo pacman -S zenity --noconfirm
    elif [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID" == "linuxmint" ]]; then
      sudo apt install zenity -y
    else
      echo "Sistema não suportado para instalação automática de zenity."
    fi
  fi
fi

# Função para criar swapfile
criar_swapfile() {
  tamanho=$1
  sudo dd if=/dev/zero of=/swapfile bs=1M count=$((tamanho * 1024)) status=progress
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo "Swapfile de $tamanho GB criado e ativado."
}

# Caixa de entrada para o usuário digitar a quantidade de swapfile
tamanho_swapfile=$(zenity --entry \
  --title="Quantidade de Swapfile" \
  --text="Digite a quantidade de Swapfile (em GB):")

# Verifica se o valor foi digitado e é um número válido
if [[ "$tamanho_swapfile" =~ ^[0-9]+$ ]]; then
  criar_swapfile $tamanho_swapfile
else
  zenity --error --text="Entrada inválida. Por favor, insira um número válido de GB para o swapfile."
fi
