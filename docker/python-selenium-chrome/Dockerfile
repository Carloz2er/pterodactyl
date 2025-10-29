FROM ubuntu:22.04

ENV DEBIAN_FONTEND=noninteractive
ENV TZ=UTC

ENV USER=container
ENV UID=1000
ENV GID=1000
ENV HOME=/home/container

RUN groupadd -g $GID container && \
    useradd -u $UID -g $GID -d $HOME -s /bin/bash container

RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    xvfb \
    git \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libgbm1 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

RUN CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d'.' -f1) \
    && CHROMEDRIVER_VERSION=$(wget -q -O - "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROME_VERSION") \
    && wget -q -O /tmp/chromedriver.zip "https://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip" \
    && unzip /tmp/chromedriver.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/chromedriver \
    && rm /tmp/chromedriver.zip

RUN pip3 install --upgrade pip && \
    pip3 install \
    selenium==4.15.0 \
    webdriver-manager==4.0.1 \
    requests \
    beautifulsoup4 \
    lxml \
    pyvirtualdisplay

RUN mkdir -p $HOME && \
    chown -R $UID:$GID $HOME

RUN cat > /entrypoint.sh << 'EOF'
cd /home/container

export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &

if [ -n "${STARTUP}" ]; then
    MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
    echo -e "\033[1;33mcontainer@localhost~ \033[0m${MODIFIED_STARTUP}"
    eval ${MODIFIED_STARTUP}
else
    echo -e "\033[1;33mcontainer@localhost~ \033[0mNo STARTUP command detected, running default Python shell"
    python3
fi
EOF

RUN chmod +x /entrypoint.sh

WORKDIR $HOME
USER container

CMD ["/bin/bash", "/entrypoint.sh"]
