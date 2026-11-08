# Flipper Blackhat OS
A WiFi and security testing OS built on Linux for penetration testing and network analysis. Designed to run on the [Flipper Blackhat](https://github.com/o7-machinehum/flipper-blackhat).

There are two possible builds in this repository, find releases [here](https://github.com/o7-machinehum/flipper-blackhat-os/releases), or instructions to build below.


## Armbian
Armbian is the suggested operating system when using the Flipper Blackhat with the Flipper Zero and the Blackpants.

``` bash
./bhos_build_kali.sh
```
Images are found in `armbian/output/images/`

## Buildroot
Buildroot is deprecated for the blackhat but made available for people that want something that boots extremely fast.

``` bash
git submodule update --init
cd buildroot
make BR2_EXTERNAL=$PWD/../ flipper_blackhat_a33_defconfig
make
```

## Build bhtui
The armbian build steps above will do this, but if you don't want to build the entire OS, you can build `bhtui` with docker.

```bash
# Only needs to be done once per boot.
sudo systemctl start docker
docker info

# Enable ARM emulation
docker run --privileged --rm tonistiigi/binfmt --install arm

# Update subs
git submodule update --init --recursive package/bhtui/third-party/TermOx

# Build the binary
./scripts/build-bhtui.sh

# Files here
# package/bhtui/build/
```


