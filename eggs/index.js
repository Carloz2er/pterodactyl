const puppeteer = require("puppeteer");

const puppeteerArgs = process.env.PUPPETEER_ARGS 
                      ? process.env.PUPPETEER_ARGS.split(' ') 
                      : ['--no-sandbox', '--disable-setuid-sandbox'];

const executablePath = process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser';


(async () => {
    const browser = await puppeteer.launch({
        headless: "new",
        executablePath: executablePath,
        args: puppeteerArgs,
    });
    
    const page = await browser.newPage();
    await page.goto("https://google.com");
    console.log("Título da página:", await page.title());
    await browser.close();
})();
