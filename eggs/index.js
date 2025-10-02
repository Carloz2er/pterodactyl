const puppeteer = require('puppeteer');

const PUPPETEER_ARGS = [
    '--no-sandbox', 
    '--disable-setuid-sandbox', 
    '--disable-dev-shm-usage',
    '--disable-gpu'
];

async function runPuppeteerTest() {
    let browser;
    let result = '';
    
    const url = 'https://www.google.com';
    console.log(`\n=================================================`);
    console.log(`⚙️ INICIANDO TESTE DO PUPPETEER`);
    console.log(`URL a visitar: ${url}`);
    console.log(`Argumentos de segurança: ${PUPPETEER_ARGS.join(' ')}`);
    console.log(`=================================================`);

    try {
        
        browser = await puppeteer.launch({
            headless: 'new', 
            args: PUPPETEER_ARGS,
        });

        const page = await browser.newPage();
        await page.setDefaultTimeout(15000); 
        console.log(`... Navegando para ${url}...`);
        await page.goto(url, { waitUntil: 'networkidle0' });
        const title = await page.title();
        result = `\n✅ SUCESSO! Puppeteer e Chrome FUNCIONAIS.\n\nResultado do Puppeteer:\n- Página visitada: ${url}\n- Título obtido: "${title}"\n- Binário usado: Puppeteer Cache.`;

    } catch (error) {
        console.error(`\n❌ FALHA! Puppeteer NÃO FUNCIONAL.`);
        result = `\n❌ FALHA! Puppeteer NÃO FUNCIONAL.\n\nErro: ${error.message}\n\nVerifique as dependências e o script de inicialização.`;
        throw error; 
    } finally {
        if (browser) {
            await browser.close();
        }
        console.log(result);
        console.log(`=================================================\n`);
    }
}
runPuppeteerTest().catch(error => {
    process.exit(1); 
});
