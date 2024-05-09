FROM ubuntu:22.04

WORKDIR /home

#Required since Debian Buster
ENV FORCE_UNSAFE_CONFIGURE=1

#Which version should we build
ARG RUTOS_VERSION=00.07.07.1
ARG RUTOS_SHORT_VER=7.7.1

#Based on https://wiki.teltonika-networks.com/view/RUTOS_Software_Development_Kit_instructions
RUN \
	apt-get update &&\
	apt-get install -y sqlite3 vim sudo curl build-essential ccache ecj fastjar file flex g++ gawk gettext git java-propose-classpath java-wrappers jq libelf-dev libffi-dev libncurses5-dev libncursesw5-dev libssl-dev libtool python2.7-dev python3 python3-dev python3-distutils python3-setuptools rsync subversion swig time u-boot-tools unzip wget xsltproc zlib1g-dev bison

#Building with root permissions will fail miserably
#See: https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user

#Set user, group and setup sudo
ARG USERNAME=rutx
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME
RUN useradd --uid $USER_GID --gid $USERNAME -m $USERNAME
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME
RUN chmod 0440 /etc/sudoers.d/$USERNAME

#Switch to user
USER $USER_UID:$USER_GID

#Install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install 19 && \
    nvm use 19 && \
    npm install -g yarn 
RUN sudo ln -f -s $HOME/.nvm/versions/node/v19.9.0/bin/node /usr/bin/node
RUN sudo ln -f -s $HOME/.nvm/versions/node/v19.9.0/bin/npm /usr/bin/npm

RUN node --version
RUN npm --version

#Download/Unpack
RUN \
    cd ~ && \
    export RUTOS_FILE=RUTX_R_GPL_${RUTOS_VERSION}.tar.gz && \
    wget https://firmware.teltonika-networks.com/${RUTOS_SHORT_VER}/RUTX/${RUTOS_FILE} && \
    tar -xf ${RUTOS_FILE} && \
    rm ${RUTOS_FILE}

#Build, remove dlna (somehow causes problems) and add netem and sched (for use with tc)
RUN \
    cd ~ && \
    cd rutos-ipq40xx-rutx-sdk && \
    ./scripts/feeds update -a && \
    echo "CONFIG_PACKAGE_kmod-netem=y" >> .config && \
    echo "CONFIG_PACKAGE_kmod-sched=y" >> .config && \
    sed -e '/dlna/ s/^#*/#/' -i .config && \
    make -j $(nproc) V=s