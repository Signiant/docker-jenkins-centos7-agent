#!/bin/bash
FROM signiant/docker-jenkins-centos-base:centos7-java8
MAINTAINER devops@signiant.com

ENV BUILD_USER bldmgr
ENV BUILD_USER_GROUP users

# Set the timezone
RUN unlink /etc/localtime
RUN ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

# Install maven
ENV MAVEN_VERSION 3.2.1
RUN curl -fsSL http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar xzf - -C /usr/share \
  && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
ENV MAVEN_HOME /usr/share/maven


# Install yum packages required for build node
COPY yum-packages.list /tmp/yum.packages.list
RUN chmod +r /tmp/yum.packages.list
RUN yum install -y -q --skip-broken `cat /tmp/yum.packages.list`

RUN yum install -y centos-release-scl-rh && \
    yum install -y devtoolset-6 

# Install yum development tools
RUN yum groupinstall -y -q "Development Tools"

# Install newer cmake 
RUN cd /tmp && \
    yum erase cmake && \
    wget "https://cmake.org/files/v3.9/cmake-3.9.1.tar.gz" && \
    tar -xzvf cmake-3.9.1.tar.gz && \
    cd cmake-3.9.1 && \
    ./bootstrap && \
    make -j8 && \
    make install
    
# Install newer git
RUN cd /tmp && \
    wget https://github.com/git/git/archive/v2.7.0.tar.gz && \
    tar xvfz ./v2.7.0.tar.gz && \
    cd git-2.7.0 && \
    make configure && \
    ./configure --prefix=/usr --without-tcltk && \
    make -j8 && \
    make install

# Install jboss
RUN wget http://sourceforge.net/projects/jboss/files/JBoss/JBoss-5.1.0.GA/jboss-5.1.0.GA.zip/download -O /tmp/jboss-5.1.0.GA.zip
RUN unzip -q /tmp/jboss-5.1.0.GA.zip -d /usr/local
RUN rm -f /tmp/jboss-5.1.0.GA.zip

# Install Compass
RUN gem install json_pure
#RUN gem update --system

# install phantomjs
RUN npm install -g phantomjs-prebuilt

# Install Python 2.7.X for Umpire
RUN cd /tmp && \
    wget https://www.python.org/ftp/python/2.7.11/Python-2.7.11.tgz && \
    tar xvfz Python-2.7.11.tgz && \
    cd Python-2.7.11 && \
    ./configure --prefix=/usr/local && \
    make -j8 && \
    make altinstall

# Install pip
RUN easy_install -q pip && \
    pip install --upgrade pip

ENV UMPIRE_VERSION 0.5.4
# Install umpire
RUN pip2.7 install umpire==${UMPIRE_VERSION}

# update paths for gcc
RUN set -ex && \
    cd /etc/ld.so.conf.d && \
    echo '/usr/local/lib64' > local-lib64.conf && \
    ldconfig -v
ENV CC /opt/rh/devtoolset-6/root/usr/bin/gcc
ENV CXX /opt/rh/devtoolset-6/root/usr/bin/g++
RUN rm /usr/bin/g++ && ln -s /opt/rh/devtoolset-6/root/usr/bin/g++ /usr/bin/g++
RUN rm /usr/bin/gcc && ln -s /opt/rh/devtoolset-6/root/usr/bin/gcc /usr/bin/gcc
RUN rm /usr/bin/c++ && ln -s /opt/rh/devtoolset-6/root/usr/bin/c++ /usr/bin/c++

# Make sure anything/everything we put in the build user's home dir is owned correctly
RUN chown -R $BUILD_USER:$BUILD_USER_GROUP /home/$BUILD_USER

EXPOSE 22

# This entry will either run this container as a jenkins slave or just start SSHD
# If we're using the slave-on-demand, we start with SSH (the default)

# Default Jenkins Slave Name
ENV SLAVE_ID JAVA_NODE
ENV SLAVE_OS Linux

ADD start.sh /
RUN chmod 777 /start.sh

CMD ["sh", "/start.sh"]
