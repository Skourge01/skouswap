## skouswap

skouswap é um script projetado para facilitar a criação e gerenciamento de swapfiles no Linux, utilizando uma interface gráfica simples e intuitiva. O objetivo do script é proporcionar uma maneira fácil de configurar o swap em sistemas Linux, com suporte a múltiplas distribuições e a possibilidade de otimizar o uso de memória.

## Instalação:
- ultilizar a versão estavel na release mais nova: https://github.com/Skourge01/skouswap/releases/tag/2.6
- ultilizar a versão testing via commit: https://github.com/Skourge01/skouswap/commits/main/

### Tutorial
- ao instalar o script ele deve ser iniciado via linha de comando CLI use seu terminal preferido
- vá para a pasta onde baixou o script com
```
cd name_folder/skouswap
```
- defina como chmod o script dentro de skouswap/
```
chmod +x skouswap(version).sh
```
- execute o script
```
./skouswap 
```
### Debian problems 
- no debian tem alguns problemas de permisão de usuario
- ultilize:
```
su 
```
- ensira a sua senha
- execute o script
## Como usar o script 
- depois de instalar as dependencias do script
- ira aparecer uma interface em fzf dizendo;
zram
swapfile
## ATENÇÃO
- apos a execução do script reinicie o sistema para que as alterações sejam feitas automaticamente
```
sudo reboot
```
## Zram 
- O ZRAM é uma tecnologia que cria um disco virtual na RAM e usa compressão para armazenar dados. Ele é útil para sistemas com pouca memória, pois permite que mais dados sejam armazenados na RAM comprimida, reduzindo o uso de swap no disco e melhorando o desempenho
### Vantagens:
- Mais rápido que a swap tradicional, pois a RAM é mais rápida que um SSD/HD.
- Reduz escrita no disco, aumentando a vida útil de SSDs.
- Pode melhorar o desempenho de sistemas com pouca RAM.

### Desvantagens:
- Consome parte da RAM.
- Pode aumentar o uso da CPU devido à compressão/descompressão.
## Swapfile
O Swapfile é um arquivo dentro do sistema de arquivos que age como memória virtual, funcionando da mesma forma que uma partição swap tradicional.

## Vantagens:
- Mais flexível que uma partição swap (pode ser redimensionado facilmente).
- Não precisa de uma partição dedicada.

## Desvantagens:
- Mais lento que o ZRAM, pois usa o disco.
- Pode degradar a performance se o sistema estiver constantemente usando swap.

## Quando usar?
- ZRAM → Melhor para desempenho em sistemas com pouca RAM.
- Swapfile → Melhor para estabilidade em sistemas com mais RAM, mas sem swap suficiente.

Contato:
Reddit: [Skourge01](https://www.reddit.com/user/Skourge01/)
Email: oditorrinco222@gmail.com
