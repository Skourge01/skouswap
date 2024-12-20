# skouswap2.0

skouswap2.0 é a versão aprimorada de um script para gerenciar swapfiles no Linux. Ele foi desenvolvido para ser simples de usar e oferecer compatibilidade com uma ampla gama de distribuições Linux, como [Arch Linux](https://archlinux.org/) , [Debian](https://www.debian.org/index.pt.html), [Ubuntu](https://ubuntu.com/download), [Linux Mint](https://linuxmint.com/), entre outras. O script utiliza a ferramenta [Zenity](https://github.com/GNOME/zenity) para fornecer uma interface gráfica interativa, permitindo que o usuário configure a quantidade de swap de maneira intuitiva, sem precisar editar manualmente os arquivos de configuração ou executar comandos complexos.

O skouswap2.0 permite ao usuário:

  Instalar e verificar automaticamente a presença do Zenity, instalando-o de acordo com a distribuição do sistema (usando pacman em distros como Arch ou Manjaro, e apt em distros como Ubuntu, Debian e Linux Mint).
  - Criar um swapfile de forma automática, permitindo a escolha do tamanho desejado em GB através de uma interface gráfica fornecida pelo Zenity.
    Ativar o swapfile imediatamente após a criação, garantindo que o sistema comece a usar o novo espaço de swap sem a necessidade de reiniciar ou executar outros comandos.
- - - 
### O que mudou no skouswap2.0 em relação ao [skouswap1.0](https://github.com/Skourge01/skouswap1.0):

  - Suporte ampliado para distros: A versão 2.0 é mais compatível com diferentes distribuições, como Arch Linux, Ubuntu, Debian, Linux Mint, e outras populares, já que ela adapta o processo de instalação do Zenity de acordo com o sistema detectado.

   -  Interface gráfica (Zenity): Enquanto o skouswap1.0 pode ter dependido mais de comandos em terminal e interações manuais, o skouswap2.0 melhora a experiência do usuário oferecendo uma caixa de entrada interativa para o tamanho do swapfile. Isso elimina a necessidade de o usuário editar qualquer arquivo de configuração diretamente.
- - - 
  #### Automação na criação do swapfile
   O script agora cria e ativa automaticamente o swapfile após a escolha do tamanho pelo usuário, o que facilita o processo de configuração.

  -   Melhor detecção e instalação do Zenity: Na versão 2.0, o script verifica se o Zenity já está instalado e, se não, instala automaticamente utilizando o gerenciador de pacotes adequado para a distribuição. Isso melhora a portabilidade e a usabilidade do script em diferentes sistemas Linux.

   -  Simplicidade e clareza: A versão 2.0 foi desenvolvida com foco em simplicidade e clareza, tornando o processo de configuração do swapfile mais acessível para usuários menos experientes, sem perder a flexibilidade de funcionar em várias distribuições.
- - - 
### Instalação  
 - primeiro instale as dependencias
   arch linux: `sudo pacman -S git`
   mint, ubuntu, debian: `sudo apt install git`
### Conclusão:

O skouswap2.0 oferece uma maneira mais fácil e interativa de configurar swapfiles no Linux, aproveitando a interface gráfica do Zenity para tornar o processo mais amigável, e a detecção automática da distribuição para garantir compatibilidade com uma ampla gama de sistemas.





### Referencias 
[Reddit](https://www.reddit.com/user/Vast-Echo805/)
email: oditorrinco222@gmail.com
