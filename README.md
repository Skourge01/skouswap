## skouswap

skouswap is a script designed to facilitate the creation and management of swapfiles on Linux, using a simple and intuitive graphical interface. The goal of the script is to provide an easy way to configure swap on Linux systems, with support for multiple distributions and the possibility of optimizing memory usage.

## Installation:
- use the **stable** version in the latest release: https://github.com/Skourge01/skouswap/releases/tag/2.6
- use the **testing** version via commit: https://github.com/Skourge01/skouswap/commits/main/

### Tutorial
- when installing the script it must be started via CLI command line use your preferred terminal
- go to the folder where you downloaded the script with
```
cd name_folder/skouswap
```
- set as chmod the script inside skouswap/
```
chmod +x skouswap(version).sh
```
- run the script
```
./skouswap
```
### Debian problems
- in Debian there are some user permission problems
- use:
```
su
```
- enter your password
- run the script
## How to use the script
- after installing the script dependencies
- an interface in fzf will appear saying;
zram
swapfile
## Recommend setup 
It is recommended that you use this script with these memories: 
2gb: 175% zram 
4gb: 175% zram 
6gb: 150% zram 
8gb: 100% zram 
12gb: 8gb swapfile 
16gb+: dont use or 100% swapfile 
## ATTENTION
- after running the script, restart the system so that the changes are made automatically
```
sudo reboot
```
## Zram
- ZRAM is a technology that creates a virtual disk in RAM and uses compression to store data. It is useful for systems with little memory, as it allows more data to be stored in compressed RAM, reducing the use of swap on the disk and improving performance
### Advantages:
- Faster than traditional swap, as RAM is faster than an SSD/HD.
- Reduces writing to the disk, increasing the lifespan of SSDs.
- Can improve the performance of systems with little RAM.

### Disadvantages:
- Consumes part of the RAM. - May increase CPU usage due to compression/decompression.
## Swapfile
A Swapfile is a file within the file system that acts as virtual memory, working in the same way as a traditional swap partition.

## Advantages:
- More flexible than a swap partition (can be easily resized).
- Does not require a dedicated partition.

## Disadvantages:
- Slower than ZRAM, as it uses disk space.
- May degrade performance if the system is constantly using swap.

## When to use?
- ZRAM → Best for performance on systems with little RAM.
- Swapfile → Best for stability on systems with more RAM but not enough swap.

Contact:
Reddit: [Skourge01](https://www.reddit.com/user/Skourge01/)
Email: oditorrinco222@gmail.com
Enviar feedback
Resultados de tradução disponíveis
