FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
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
    ca-certificates \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    xvfb \
    git \
    fonts-liberation \
    fonts-noto-color-emoji \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libu2f-udev \
    libvulkan1 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O /tmp/google-chrome-key.pub https://dl.google.com/linux/linux_signing_key.pub && \
    gpg --dearmor -o /etc/apt/trusted.gpg.d/google-chrome.gpg /tmp/google-chrome-key.pub && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/* /tmp/google-chrome-key.pub

RUN CHROME_VERSION=$(google-chrome --version | awk '{print $3}') && \
    CHROME_MAJOR_VERSION=$(echo $CHROME_VERSION | cut -d'.' -f1) && \
    echo "Chrome version: $CHROME_VERSION (major: $CHROME_MAJOR_VERSION)" && \
    CHROMEDRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_$CHROME_MAJOR_VERSION") && \
    echo "Downloading ChromeDriver version: $CHROMEDRIVER_VERSION" && \
    wget -q -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/$CHROMEDRIVER_VERSION/linux64/chromedriver-linux64.zip" || \
    wget -q -O /tmp/chromedriver.zip "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/$CHROMEDRIVER_VERSION/linux64/chromedriver-linux64.zip" && \
    unzip -j /tmp/chromedriver.zip "chromedriver-linux64/chromedriver" -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/chromedriver && \
    rm /tmp/chromedriver.zip && \
    chromedriver --version

RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir \
    selenium==4.15.0 \
    webdriver-manager==4.0.1 \
    requests \
    beautifulsoup4 \
    lxml \
    pyvirtualdisplay \
    python-dotenv

RUN mkdir -p $HOME && \
    chown -R $UID:$GID $HOME

WORKDIR $HOME

USER container

CMD ["/bin/bash"]
