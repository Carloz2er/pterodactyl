#!/bin/bash
cd /home/container

export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &

if [ -n "${STARTUP}" ]; then
    MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
    echo -e "\033[1;33mcontainer@localhost~ \033[0m${MODIFIED_STARTUP}"
    eval ${MODIFIED_STARTUP}
else
    echo -e "\033[1;33mcontainer@localhost~ \033[0mNenhum comando de INICIALIZAÇÃO detectado! executando o Python padrão"
    python3
fi
