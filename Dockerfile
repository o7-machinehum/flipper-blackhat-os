# Use an official Ubuntu runtime as a parent image
FROM ubuntu:latest
ARG HOST_USERNAME
ARG HOST_UID
ARG HOST_GID

ENV HOST_USERNAME=$HOST_USERNAME

RUN apt-get update && \
    apt-get install -y build-essential git libncurses-dev bc python3 wget unzip file rsync cpio

RUN useradd -ms /bin/bash -u $HOST_UID -g $HOST_GID $HOST_USERNAME
USER $HOST_USERNAME
WORKDIR /home/$HOST_USERNAME/buildroot
COPY . /home/$HOST_USERNAME/buildroot

# RUN locale-gen en_US.utf8
# ENV O=/buildroot_output
# VOLUME /root/buildroot/dl
# VOLUME /buildroot_output

# Set the default command to run when the container starts
CMD ["bash"]
