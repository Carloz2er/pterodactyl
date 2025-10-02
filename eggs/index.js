const puppeteer = require('puppeteer');

async function startPuppeteer() {
    console.log('=================================================');
    console.log('🚀 INICIANDO TESTE DO PUPPETEER');
    console.log('📄 URL a visitar: https://www.google.com');
    console.log('🔧 Argumentos de segurança: --no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu');
    console.log('=================================================');
    
    try {
        const browser = await puppeteer.launch({
            executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu',
                '--single-process',
                '--no-zygote',
                '--headless'
            ],
            headless: 'new'
        });

        console.log('✅ Browser iniciado com sucesso!');
        
        const page = await browser.newPage();
        await page.goto('https://www.google.com', { waitUntil: 'networkidle2' });
        
        const title = await page.title();
        console.log('✅ Página carregada com sucesso!');
        console.log(`📄 Título da página: ${title}`);
        
        await browser.close();
        console.log('=================================================');
        console.log('✅ TESTE CONCLUÍDO COM SUCESSO!');
        console.log('=================================================');
        
    } catch (error) {
        console.error('❌ FALHA! Puppeteer NÃO FUNCIONAL.');
        console.error('❌ Erro:', error.message);
        console.log('=================================================');
        process.exit(1);
    }
}

// Verificar se o Chromium está disponível
const fs = require('fs');
const chromiumPaths = [
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium',
    '/usr/bin/chrome'
];

let chromiumFound = false;
for (const path of chromiumPaths) {
    if (fs.existsSync(path)) {
        console.log(`✅ Chromium encontrado em: ${path}`);
        chromiumFound = true;
        break;
    }
}

if (!chromiumFound) {
    console.log('❌ Chromium não encontrado nos caminhos esperados');
    process.exit(1);
}

startPuppeteer();
