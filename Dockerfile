FROM jenkins/jenkins:lts
MAINTAINER sistemas@emergya.com

ENV BUILD_TIMESTAMP 201906141200
ENV LOCALE en_US.UTF-8
USER root
ADD assets/etc/apt /assets/etc/apt
#
RUN /bin/bash -c 'ln -fs /assets/etc/apt/sources.list /etc/apt/sources.list' && /bin/bash -c 'ln -fs /assets/etc/apt/apt.conf.d/99recommends /etc/apt/apt.conf.d/99recommends'

RUN apt-get update -qq && apt-get install -y wget

# Let's start with some basic stuff.
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -qqy \
    apt-transport-https ca-certificates curl lxc iptables locales net-tools iputils-ping iproute2 sysstat iotop tcpdump tcpick bwm-ng tree strace screen rsync inotify-tools socat wget curl \
        openssh-server openssh-client build-essential automake make autoconf libpcre3-dev software-properties-common supervisor sudo git vim emacs python-minimal fontconfig ssmtp mailutils \
        bash-completion less zfsutils-linux apt-utils jq python3-pip python3-dev python3-setuptools python3-wheel

# Install Docker from Docker Inc. repositories.
RUN curl -sSL https://get.docker.com/ | sh

# Install the magic wrapper.
ADD assets/bin/wrapdocker /usr/local/bin/wrapdocker
RUN chmod +x /usr/local/bin/wrapdocker

# Configure locales
RUN locale-gen $LOCALE && /bin/bash -c 'ln -fs /assets/etc/default/locale /etc/default/locale'

# installl docker-compose
ENV DOCKER_COMPOSE_VERSION="1.13.0"
RUN curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# allow jenkins to talk to docker daemon and to perform privileged actions with sudo
RUN adduser jenkins docker && adduser jenkins sudo
# Fixes forced requiretty on ubuntu-16.04
RUN sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=sudo' /etc/sudoers && \
    sed -i -e 's/%sudo\s*ALL=(ALL:ALL) ALL/%sudo\tALL=(ALL) NOPASSWD:ALL/g' /etc/sudoers

# Increase jenkins executors
COPY assets/etc/jenkins/executors.groovy /usr/share/jenkins/ref/init.groovy.d/executors.groovy

# Preinstall our plugin list
COPY assets/etc/jenkins/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt
RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state

# Install pip requirements tools
COPY assets/etc/pip/requirements.txt /requirements.txt
RUN pip3 install -U pip
RUN pip3 install -r /requirements.txt

ADD assets/ /assets

WORKDIR $JENKINS_HOME
VOLUME ["/var/log/supervisor"]
ENTRYPOINT ["/assets/bin/entrypoint"]
