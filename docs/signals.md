# Catalogo segnali

Bot Detection utilizza 26 segnali a punteggio organizzati in 7 categorie. Ogni segnale somma punti al totale; quando il totale supera la soglia (default 5), la variabile restituisce `'possible bot'`.

## Browser identity (4)

### `webdriver=true` (+5)
**Codice**: `_bdWebdriver`
**Cosa rileva**: `navigator.webdriver === true` esposto dal browser.
**Intercetta**: Selenium WebDriver, ChromeDriver, GeckoDriver, Edge WebDriver, Cypress (default), TestCafe, WebdriverIO, Nightwatch.js, Playwright base, Puppeteer base.

### User Agent sospetto (+4)
**Codice**: `_bdUA contains HeadlessChrome/Selenium/PhantomJS/webdriver`
**Cosa rileva**: Pattern noti di automazione nello User Agent.
**Intercetta**: Puppeteer default, Pyppeteer, Apify SDK, Browserless.io, PhantomJS, Splash (Scrapy), Cypress headless mal configurato.

### `plugins.length=0` (+2)
**Codice**: `_bdPluginsLen`
**Cosa rileva**: Plugin collection vuota.
**Intercetta**: Browser headless, tutti i client HTTP (curl, wget, python-requests, urllib, httpx, aiohttp, Scrapy, axios, Go, Java, Ruby), Tor Browser e browser privacy estremi (borderline).

### `window.chrome` assente (+3)
**Codice**: `_bdHasChromeObj`
**Cosa rileva**: Mancanza di `window.chrome` quando lo UA dichiara Chrome.
**Intercetta**: Bot che spoofano lo UA Chrome senza ricostruire l'oggetto chrome (curl-impersonate, fake-useragent, framework headless mal configurati).

---

## Display fingerprint (7)

### `deltaWidth < 0` (+3)
**Codice**: `_bdScreenWidth - _bdBrowserWidth`
**Cosa rileva**: Browser più largo dello schermo (fisicamente impossibile).
**Intercetta**: Bot che spoofano dimensioni inconsistenti, viewport mal configurate, emulatori.

### `deltaHeight ≤ 0` (+3)
**Codice**: `_bdScreenHeight - _bdBrowserHeight`
**Cosa rileva**: Schermo non più alto del viewport (no barre browser).
**Intercetta**: Headless browsers in modalità full-screen (config default di Puppeteer/Playwright/Cypress), Smart TV browsers e console gaming (borderline).

### `colorDepth<16` (+2)
**Codice**: `_bdColorDepth`
**Cosa rileva**: Profondità colore anomala.
**Intercetta**: Headless browsers su VM senza GPU, server senza display, emulatori.

### `dpr<1` (+2)
**Codice**: `_bdDpr`
**Cosa rileva**: Device Pixel Ratio anomalo.
**Intercetta**: Configurazioni anomale di automation tools, VM senza display.

### Apple device + DPR<2 (+3)
**Codice**: `iPhone/iPad in UA + _bdDpr < 2`
**Cosa rileva**: iPhone/iPad da 2014+ hanno sempre DPR ≥ 2.
**Intercetta**: Scraper con UA iPhone falso, emulatori iOS mal configurati.

### Mobile UA senza touch (+3)
**Codice**: `mobile UA + _bdMaxTouchPoints=0`
**Cosa rileva**: UA mobile ma maxTouchPoints=0.
**Intercetta**: Scraper headless con UA mobile senza simulazione touch.

### Desktop UA + touch + small viewport (+2)
**Codice**: `desktop UA + tp>0 + sW<500`
**Cosa rileva**: Inconsistenza tablet/desktop.
**Intercetta**: Bot che spoofano viewport mobile mantenendo UA desktop.

---

## GPU & Canvas fingerprint (5)

### `canvasEmpty` (+3)
**Codice**: `_bdCanvasScore=3`
**Cosa rileva**: `canvas.toDataURL().length < 200`.
**Intercetta**: Browser headless senza GPU, Tor Browser (canvas randomizzato — borderline), bot che bloccano canvas API.

### `canvasBlocked` (+1)
**Codice**: `_bdCanvasScore=1`
**Cosa rileva**: Eccezione su canvas API.
**Intercetta**: Browser ad alta privacy (Brave aggressive, Firefox strict, estensioni anti-fingerprinting).

### `softwareRenderer` (+3)
**Codice**: `_bdWebGLScore=3`
**Cosa rileva**: GPU software emulata: SwiftShader, llvmpipe, VirtualBox, VMware, Mesa.
**Intercetta**: Headless browsers su VM (Puppeteer/Playwright/Selenium su CI/CD), Docker containers, cloud automation (Browserless, ScrapingBee, Apify).

### `noWebGL` (+2)
**Codice**: `_bdWebGLScore=2`
**Cosa rileva**: WebGL context non disponibile.
**Intercetta**: Browser headless minimali, ambienti senza GPU virtuale.

### `webglError` (+1)
**Codice**: `_bdWebGLScore=1`
**Cosa rileva**: Eccezione su WebGL.
**Intercetta**: Ambienti di test, configurazioni anomale.

---

## Internazionalizzazione (2)

### `noLanguage` (+2)
**Codice**: `_bdLanguage`
**Cosa rileva**: `navigator.language` vuoto.
**Intercetta**: Tutti i client HTTP basici (curl, wget, requests, urllib, httpx, aiohttp, Scrapy, axios, Go, Java, Ruby, Guzzle), crawler legittimi (Googlebot, GPTBot, ClaudeBot).

### Lingua + Timezone UTC (+2)
**Codice**: `_bdLanguage + _bdTimezone=UTC`
**Cosa rileva**: Combinazione tipica di server/container.
**Intercetta**: Headless browsers su server senza TZ (Docker, AWS Lambda, GCP Cloud Run), bot in datacenter.

---

## Permessi (1)

### `notificationsDenied` (+1)
**Codice**: `_bdNotificationsDenied`
**Cosa rileva**: Permission notifications = denied via Permissions API.
**Intercetta**: Browser headless (denied di default). Segnale debole perché molti utenti reali negano notifiche.

---

## Comportamento (2)

### `noMouseMove` (+2)
**Codice**: `_bdMouseMoved=false`
**Cosa rileva**: Listener mousemove mai attivato.
**Intercetta**: Tutti i crawler HTTP, tutti i client HTTP, bot che non simulano interazione, bot stealth in reconnaissance.

### `noScroll` (+1)
**Codice**: `_bdScrolled=false`
**Cosa rileva**: Listener scroll mai attivato.
**Intercetta**: Bot scraper one-shot, crawler, client HTTP, bot che operano via DOM senza scrollare.

---

## Anti-tampering e avanzati (5)

### `tampering` (+5)
**Codice**: `_bdLiveCheckPassed=false`
**Cosa rileva**: `screen`, `navigator.webdriver`, `navigator.userAgent` modificati post-init.
**Intercetta**: Bot che usano `Object.defineProperty` per spoofare navigator dopo il caricamento, anti-detect browsers con tampering attivo (alcune configurazioni Kameleo, Multilogin, GoLogin), bot AI che cambiano fingerprint runtime.

### `syntheticMouse` (+4)
**Codice**: `_bdMouseUntrustedCount>0`
**Cosa rileva**: Eventi `mousemove` con `isTrusted=false` (creati da JavaScript).
**Intercetta**: Bot che chiamano `document.dispatchEvent(new MouseEvent('mousemove'))` per simulare interazione. È il bypass classico degli Stealth Level 9, di molti AI agents (BrowserUse, GPT-4V, configurazioni custom di Multi-on), e dei bot che cercano di superare `mouseMoved`.

### `syntheticScroll` (+3)
**Codice**: `_bdScrollUntrustedCount>0`
**Cosa rileva**: Eventi `scroll` con `isTrusted=false`.
**Intercetta**: Bot che iniettano scroll sintetico per superare `_bdScrolled`. Comune nei bot AI di alto livello, nei bot infinite-scroll, nei bot di interazione automatizzata.

### `lowMouseEntropy` (+2)
**Codice**: `_bdMouseEntropy<20 && _bdMouseTrustedCount>5`
**Cosa rileva**: Curvatura del percorso mouse + varianza dei timing bassa.
**Intercetta**: Bot AI che usano CDP per generare eventi trusted ma con pattern robotici (Adept ACT-1, Open Interpreter quando muove cursore via API), bot con movimento lineare invece di curve umane.

### `mouseTooFast` (+2)
**Codice**: `_bdFirstMouseDelay<50ms`
**Cosa rileva**: Tempo tra init DOM Helper e primo mouse trusted inferiore a 50ms.
**Intercetta**: Bot che iniettano eventi mouse immediatamente all'init, automation tools che eseguono mouseMove appena la pagina è caricata, framework di stealth che chiamano CDP.Input.dispatchMouseEvent in modo aggressivo.

---

## Firme distintive

Combinazioni tipiche che identificano specifiche tipologie di bot:

| Firma | Score | Bot identificati |
|---|---|---|
| `noPlugins + noLanguage + noMouseMove + noScroll` | 7 | Tutti i client HTTP (curl, requests, axios, Scrapy, ecc.) + tutti i crawler (Googlebot, GPTBot, ClaudeBot) |
| `webdriver + noPlugins + noMouseMove + noScroll` | 10-12 | Selenium ChromeDriver, WebdriverIO, Nightwatch, BrowserUse, LangChain browser tool |
| `deltaHeight + webdriver + suspUA + noPlugins + canvas + webgl + noM + noS` | 15-23 | Puppeteer default, Pyppeteer, Apify, Browserless, Cypress headless, CapMonster Cloud |
| `tampering + noMouseMove + noScroll` | 8-13 | Kameleo + tampering, GoLogin + screen tampering, Bright Data + tampering |
| `syntheticMouse + syntheticScroll + mouseTooFast` | 7-16 | Stealth bot con dispatchEvent, BrowserUse, GPT-4V, Multilogin con interazione finta |
