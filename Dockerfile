FROM ubuntu:xenial

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_ARG0=/sbin/entrypoint.sh \
    VNC_GEOMETRY=800x600 \
    VNC_PASSWD=MAX8char \
    USER_PASSWD='' \
    DEBIAN_FRONTEND=noninteractive

# 首先加用户，防止 uid/gid 不稳定
RUN groupadd user && useradd -m -g user user

RUN apt-get update && \
    apt-get install -y --allow-unauthenticated \
        python git \
        ca-certificates wget curl locales \
        sudo nginx \
        xorg openbox \
        software-properties-common apt-transport-https \
        cabextract unzip python-numpy \
        language-pack-zh-hans tzdata ttf-wqy-microhei && \
    # 安装 novnc
    curl -L -o /tmp/s6-overlay-amd64.tar.gz https://github.com/just-containers/s6-overlay/releases/download/v1.18.1.5/s6-overlay-amd64.tar.gz && \
    curl -L -o /tmp/tigervnc.deb https://bintray.com/artifact/download/tigervnc/stable/ubuntu-16.04LTS/amd64/tigervncserver_1.7.1-1ubuntu1_amd64.deb && \
    # workaround for https://github.com/just-containers/s6-overlay/issues/158
    ln -s /init /init.entrypoint && \
    # tigervnc
    (dpkg -i /tmp/tigervnc.deb || apt-get -f -y install) && \
    locale-gen en_US.UTF-8 && \
    # novnc
    mkdir -p /app/src && \
    git clone --depth=1 https://github.com/novnc/noVNC.git /app/src/novnc && \
    git clone --depth=1 https://github.com/novnc/websockify.git /app/src/websockify && \
    rm -fr /app/src/novnc/.git /app/src/websockify/.git && \
    # 安装 wine
    wget -nc https://dl.winehq.org/wine-builds/Release.key -O /tmp/wine.key && \
    apt-key add /tmp/wine.key && \
    apt-add-repository -y https://dl.winehq.org/wine-builds/ubuntu && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --allow-unauthenticated --install-recommends winehq-devel && \
    wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod 755 /usr/local/bin/winetricks && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists /tmp/*

COPY winhttp_2ksp4.verb /tmp/winhttp_2ksp4.verb
COPY coolq.reg /tmp/coolq.reg
COPY luna.msstyles /tmp/luna.msstyles

RUN sudo -Hu user WINEARCH=win32 /usr/bin/wine wineboot && \
    sudo -Hu user mkdir -p /home/user/.wine/drive_c/windows/Resources/Themes/luna/ && \
    sudo -Hu user cp /tmp/luna.msstyles /home/user/.wine/drive_c/windows/Resources/Themes/luna/luna.msstyles && \
    sudo -Hu user /usr/bin/wine regedit.exe /s /tmp/coolq.reg && \
    sudo -Hu user wineboot && \
    echo 'quiet=on' > /etc/wgetrc && \
    sudo -Hu user /usr/local/bin/winetricks -q win7 && \
    sudo -Hu user /usr/local/bin/winetricks -q /tmp/winhttp_2ksp4.verb && \
    sudo -Hu user /usr/local/bin/winetricks -q msscript && \
    sudo -Hu user /usr/local/bin/winetricks -q fontsmooth=rgb && \
    wget https://dlsec.cqp.me/docker-simsun -O /tmp/simsun.zip && \
    rm /etc/wgetrc && \
    mkdir -p /home/user/.wine/drive_c/windows/Fonts && \
    unzip /tmp/simsun.zip -d /home/user/.wine/drive_c/windows/Fonts && \
    rm -f /tmp/simsun.zip && \
    mkdir /home/user/coolq && \
    chsh -s /bin/bash user && \
    rm -rf /home/user/.cache/winetricks

ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    TZ=Asia/Shanghai \
    COOLQ_URL=http://dlsec.cqp.me/cqa-tuling

COPY ./docker-root /

VOLUME ["/home/user/coolq"]

EXPOSE 9000

ENTRYPOINT ["/init.entrypoint"]
CMD ["start"]
