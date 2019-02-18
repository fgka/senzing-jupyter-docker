# The newest LTS version, at this time, is bionic (18.04 LTS).
# However, MySQL does not have a functioning repo for it.
# Therefore, xenial (16.04LTS) instead.
ARG BASE_CONTAINER=ubuntu:bionic
FROM ${BASE_CONTAINER}

LABEL maintainer="Michael Dockter <michael@senzing.com>"
ARG NB_USER="senzing"
ARG NB_UID="1000"
ARG NB_GID="100"
ARG NB_PORT="8888"

ENV REFRESHED_AT=2019-02-17

#############################################
## OS infrastructure 
#############################################

USER root

# Update OS
# MySQL repo requires https transport as an apt installation protocol
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get -y install apt-utils \
  apt-transport-https \
  ca-certificates \
 && apt-get -y upgrade \
 && apt-get -y autoremove 

# Some extra applications
RUN apt-get -y install \
  curl \
  libmysqlclient-dev \
  gnupg \
  jq \
  locales \
  lsb-base \
  lsb-release \
  net-tools \
  network-manager \
  python3-dev \
  python3-pip \
  python-pyodbc \
  sqlite \
  sudo \
  unixodbc \
  unixodbc-dev \
  wget 

# Add MySQL apt repo
ARG DEB_PACKAGE=mysql-apt-config_0.8.12-1_all.deb
ARG MYSQL_REPO_URL=https://repo.mysql.com/${DEB_PACKAGE}
RUN wget ${MYSQL_REPO_URL} \
 && dpkg --install ${DEB_PACKAGE} \
 && rm ${DEB_PACKAGE}

# MySQL repo has a defect on the repo's URLs, below is the fix
RUN sed -i -s "s#${DEB_PACKAGE}#apt#g" /etc/apt/sources.list.d/mysql.list 

# Install latest lib client
RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get install -y libmysqlclient21

# Last update since a new repo was added.
RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*

# Create MySQL connector.
# References:
#  - https://dev.mysql.com/downloads/connector/odbc/
#  - https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-installation-binary-unix-tarball.html

ARG MYSQL_ODBC_BASE_URL=https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0
ARG MYSQL_ODBC_NAME=mysql-connector-odbc-8.0.15-linux-debian9-x86-64bit
ARG MYSQL_ODBC_TGZ=${MYSQL_ODBC_NAME}.tar.gz
ARG MYSQL_ODBC_TGZ_URL=${MYSQL_ODBC_BASE_URL}/${MYSQL_ODBC_TGZ}
RUN wget ${MYSQL_ODBC_TGZ_URL} \
 && tar -xvf ${MYSQL_ODBC_TGZ} \
 && cp ${MYSQL_ODBC_NAME}/lib/* /usr/lib/x86_64-linux-gnu/odbc/ \
 && ${MYSQL_ODBC_NAME}/bin/myodbc-installer -d -a -n "MySQL"\
      -t "DRIVER=/usr/lib/x86_64-linux-gnu/odbc/libmyodbc8w.so;" \
 && rm ${MYSQL_ODBC_TGZ} \
 && rm -rf ${MYSQL_ODBC_NAME}

#############################################
## Python infrastructure 
#############################################

USER root

RUN python3 -m pip install --upgrade pip

# Python libraries for python 3
RUN python3 -m pip install \
      bokeh \
      ipykernel \
      ipython \
      ipywidgets \
      jupyter \
      networkx \
      numpy \
      pandas \
      plotly \
      psutil \
      pyodbc \
      qgrid \
      seaborn \
      sympy \
      version_information \
      widgetsnbextension

#############################################
## Prepare user home dir
#############################################

USER root

# Source: https://github.com/jupyter/docker-stacks/blob/master/base-notebook/Dockerfile
# Enforce UTF-8 and english
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
  && locale-gen

# Add NB_USER
RUN groupadd wheel -g 11 \
  && echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su  \
  && useradd -m -s /bin/bash -N -u ${NB_UID} ${NB_USER} \
  && chmod g+w /etc/passwd

# Bring loopback up (required for notebooks)
RUN service network-manager restart
# Enable users to connect, externally, to local port
EXPOSE ${NB_PORT}

ENV HOME=/home/$NB_USER \
  SHELL=/bin/bash \
  NB_USER=$NB_USER \
  NB_UID=$NB_UID \
  NB_GID=$NB_GID \
  LC_ALL=en_US.UTF-8 \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US.UTF-8
WORKDIR ${HOME}

#############################################
## User environment setting
#############################################

USER root

# Copy files from repository.
COPY ./senzing-example-notebooks /home/${NB_USER}/

# Fix permissions
RUN chown -R ${NB_UID}:${NB_GID} /home/${NB_USER}
RUN chmod -R ug+rw /home/${NB_USER}


# Setup user running the notebook process
USER ${NB_UID}

ENV SENZING_ROOT=/opt/senzing
ENV PYTHONPATH=${SENZING_ROOT}/g2/python
ENV LD_LIBRARY_PATH=${SENZING_ROOT}/g2/lib:${SENZING_ROOT}/g2/lib/debian

