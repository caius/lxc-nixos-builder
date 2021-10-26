FROM ubuntu:21.10

RUN apt update -y && apt install -y curl sudo xz-utils

SHELL ["/bin/bash", "-c"]

RUN useradd -ms /bin/bash nix
RUN echo "nix ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-nix

USER nix
WORKDIR /home/nix

RUN curl -L https://nixos.org/nix/install | bash
RUN source /home/nix/.nix-profile/etc/profile.d/nix.sh

ENV PATH /home/nix/.nix-profile/bin:$PATH
ENV NIX_PATH /home/nix/.nix-defexpr/channels/nixos-21.05

RUN nix-channel --add https://nixos.org/channels/nixos-21.05 nixos-21.05
RUN nix-channel --update

RUN nix-env -f https://github.com/nix-community/nixos-generators/archive/master.tar.gz -i

COPY ./configuration.nix /home/nix/configuration.nix
RUN cp $(nixos-generate -f lxc-metadata) /home/nix/lxc-nixos-metadata.tar.xz
RUN nixos-generate -f lxc -c /home/nix/configuration.nix
RUN tar -xvf lxc-nixos-metadata.tar.xz metadata.yaml && mv metadata.yaml lxc-nixos-metadata.yaml

COPY /home/nix/lxc-nixos-metadata.yaml .
COPY /home/nix/lxc-nixos-image.tar.xz .
