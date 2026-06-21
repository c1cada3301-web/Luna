FROM alpine:3.20

ARG TARGETARCH

RUN apk add --no-cache \
    xorriso \
    squashfs-tools \
    bash \
    mkinitfs \
    alpine-sdk \
    abuild

# x86_64: syslinux (BIOS boot). aarch64: GRUB UEFI + FAT tools.
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        apk add --no-cache syslinux; \
    else \
        apk add --no-cache grub-efi dosfstools mtools; \
    fi

WORKDIR /luna
