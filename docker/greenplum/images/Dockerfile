# Author: Andrey Shurenkov
#
# greenplum-db-6.25.3 + ubuntu22.04
##################################################

FROM ubuntu:22.04

# The list of packages was obtained from
# https://docs.vmware.com/en/VMware-Greenplum/6/greenplum-database/install_guide-platform-requirements-overview.html
# libevent-2.1-6 -> libevent-2.1-7
# libldap-2.4-2 -> libldap-2.5-0
# libreadline7 -> libreadline8
# + sudo, lsof, locales

RUN apt-get update && apt-get install -y \
    bash \
    bzip2 \
    iproute2 \
    iputils-ping \
    krb5-multidev \
    libapr1 \
    libaprutil1 \
    libcurl3-gnutls \
    libcurl4 \
    libevent-2.1-7 \ 
    libldap-2.5-0 \
    libreadline8 \
    libuuid1 \
    libxml2 \
    libyaml-0-2 \
    less \
    locales \
    lsof \
    locales \
    net-tools \
    openssh-client \
    openssh-server \
    openssl \
    perl \
    rsync \
    sed \
    sudo \
    tar \
    zip \
    zlib1g \
    && apt-get clean

# Copy the settings file and Greenplum archive from the local machine.
COPY /tmp/greenplum-db-6.25.3-ubuntu22.04-x86_64.tar.gz /tmp/
COPY /etc/security/limits.conf /etc/security/
COPY /etc/systemd/logind.conf /etc/systemd/
COPY /etc/sysctl.conf /etc/

# Create a Greenplum directory, extract the archive, remove the archive, and set up a symbolic link.
RUN mkdir -p /usr/local/greenplum-db-6.25.3 \
    && tar -xzf /tmp/greenplum-db-6.25.3-ubuntu22.04-x86_64.tar.gz -C /usr/local/greenplum-db-6.25.3 \
    && rm /tmp/greenplum-db-6.25.3-ubuntu22.04-x86_64.tar.gz \
    && ln -s /usr/local/greenplum-db-6.25.3 /usr/local/greenplum-db 

# Create group 'gpadmin'
RUN groupadd gpadmin

# Create user 'gpadmin', create a home directory for it, assign it to the 'gpadmin' group.
RUN useradd -r -m -g gpadmin gpadmin

# Set the password for the user 'gpadmin' to 'changeme'.
RUN echo 'gpadmin:changeme' | chpasswd

# Grant the user 'gpadmin' passwordless sudo access to all commands.
RUN echo "gpadmin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create SSH key.
USER gpadmin
RUN mkdir -p /home/gpadmin/.ssh && ssh-keygen -t rsa -b 4096 -f /home/gpadmin/.ssh/id_rsa -N ""

# Change the owner and group of all Greenplum-related files to gpadmin.
USER root
RUN sudo chown -R gpadmin:gpadmin /usr/local/greenplum*
RUN sudo chgrp -R gpadmin /usr/local/greenplum*

# Add the string to /etc/bash.bashrc.
RUN echo 'source /usr/local/greenplum-db/greenplum_path.sh' >> /etc/bash.bashrc

# Add the string to /etc/bash.bashrc.
# Values of parameters from file 'gpinitsystem_singlenode': MASTER_DIRECTORY + SEG_PREFIX + -1
RUN echo 'export MASTER_DATA_DIRECTORY=/usr/local/greenplum-db/master/gpsne-1' >> /etc/bash.bashrc

# Generate the en_US.UTF-8 locale and set it as the default system locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

# Set the system's locale to en_US.UTF-8 for all environment variables.
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Start the SSH service and set the command to run the SSH server when the container starts.
RUN service ssh start
CMD ["/usr/sbin/sshd","-D"]