# Catalogo segnali

Bot Detection utilizza 26 segnali a punteggio organizzati in 7 categorie. Ogni segnale somma punti al totale; quando il totale supera la soglia (default 5), la variabile restituisce `{ status: 'possible_bot', score: N, signals: '...' }`.

---

## Tabella abbreviazioni segnali

La proprietà `signals` dell'oggetto restituito usa abbreviazioni per contenere la stringa entro i 100 caratteri accettati da GA4.

| Segnale originale | Abbreviazione | Descrizione | Valori possibili | Score |
|---|---|---|---|---|
| `tampering` | `tmp` | Proprietà del browser manomesse post-init | fisso | +5 |
| `webdriver=true` | `wdt` | `navigator.webdriver === true` | fisso | +5 |
| `deltaWidth<0` | `dw0` | Larghezza finestra maggiore dello schermo | fisso | +3 |
| `deltaHeight<=0` | `dh0` | Nessuna barra UI browser — headless | fisso | +3 |
| `suspiciousUA` | `sua` | UA contiene keyword headless/bot | fisso | +4 |
| `noPlugins` | `np` | `navigator.plugins.length === 0` | fisso | +2 |
| `colorDepth<16` | `cd16` | Profondità colore < 16 bit | fisso | +2 |
| `dpr<1` | `dpr1` | Device pixel ratio < 1 — impossibile | fisso | +2 |
| `appleDprAnomaly` | `ada` | Dispositivo Apple con DPR < 2 | fisso | +3 |
| `mobileUAnoTouch` | `munt` | UA mobile ma nessun touch point | fisso | +3 |
| `desktopUAmobileViewport` | `dumv` | UA desktop ma viewport < 500px con touch | fisso | +2 |
| `canvasEmpty` | `ce` | Canvas fingerprint completamente vuoto | fisso | +3 |
| `canvasBlocked` | `cb` | Canvas API bloccata o nulla | fisso | +1 |
| `noWebGL` | `nwgl` | WebGL non disponibile | fisso | +2 |
| `softwareRenderer` | `sr` | WebGL usa renderer software (SwiftShader, llvmpipe) | fisso | +3 |
| `webglError` | `we` | WebGL restituisce errore generico | fisso | +1 |
| `chromeMissing` | `cm` | UA dichiara Chrome ma `window.chrome` è assente | fisso | +3 |
| `noLanguage` | `nl` | `navigator.language` vuoto | fisso | +2 |
| `langTimezoneUTC` | `ltu` | Lingua impostata ma timezone UTC | fisso | +2 |
| `notificationsDenied` | `nd` | Permessi notifiche negati automaticamente | fisso | +1 |
| `noMouseMove` | `nmm` | Nessun movimento mouse registrato | fisso | +2 |
| `noScroll` | `ns` | Nessuno scroll registrato | fisso | +1 |
| `syntheticMouse=N` | `smN` | N eventi mouse con `isTrusted=false` | intero ≥ 1 | +4 |
| `syntheticScroll` | `ss` | Scroll con `isTrusted=false` | fisso | +3 |
| `lowMouseEntropy=N` | `lmeN` | Entropia movimento mouse < 20 | intero 0–19 | +2 |
| `mouseTooFast=Nms` | `mtfN` | Primo evento mouse entro N ms dal caricamento | intero 1–49 | +2 |

**Score massimo teorico:** +66. In scenari reali raramente si supera 20–25 poiché molti segnali si escludono a vicenda.

**Esempio output:**
```
{ status: "possible_bot", score: 18, signals: "tmp|wdt|dh0|np|nmm|ns" }
```

---

## Browser identity (4)

### `wdt` — webdriver=true (+5)
**Codice**: `_bdWebdriver`
**Cosa rileva**: `navigator.webdriver === true` esposto dal browser.
**Intercetta**: Selenium WebDriver, ChromeDriver, GeckoDriver, Edge WebDriver, Cypress (default), TestCafe, WebdriverIO, Nightwatch.js, Playwright base, Puppeteer base.

### `sua` — User Agent sospetto (+4)
**Codice**: `_bdUA contains HeadlessChrome/Selenium/PhantomJS/webdriver`
**Cosa rileva**: Pattern noti di automazione nello User Agent.
**Intercetta**: Puppeteer default, Pyppeteer, Apify SDK, Browserless.io, PhantomJS, Splash (Scrapy), Cypress headless mal configurato.

### `np` — plugins.length=0 (+2)
**Codice**: `_bdPluginsLen`
**Cosa rileva**: Plugin collection vuota.
**Intercetta**: Browser headless, tutti i client HTTP (curl, wget, python-requests, urllib, httpx, aiohttp, Scrapy, axios, Go, Java, Ruby), Tor Browser e browser privacy estremi (borderline).

### `cm` — window.chrome assente (+3)
**Codice**: `_bdHasChromeObj`
**Cosa rileva**: Mancanza di `window.chrome` quando lo UA dichiara Chrome.
**Intercetta**: Bot che spoofano lo UA Chrome senza ricostruire l'oggetto chrome (curl-impersonate, fake-useragent, framework headless mal configurati).

---

## Display fingerprint (7)

### `dw0` — deltaWidth < 0 (+3)
**Codice**: `_bdScreenWidth - _bdBrowserWidth`
**Cosa rileva**: Browser più largo dello schermo (fisicamente impossibile).
**Intercetta**: Bot che spoofano dimensioni inconsistenti, viewport mal configurate, emulatori.

### `dh0` — deltaHeight ≤ 0 (+3)
**Codice**: `_bdScreenHeight - _bdBrowserHeight`
**Cosa rileva**: Schermo non più alto del viewport (no barre browser).
**Intercetta**: Headless browsers in modalità full-screen (config default di Puppeteer/Playwright/Cypress), Smart TV browsers e console gaming (borderline).

### `cd16` — colorDepth<16 (+2)
**Codice**: `_bdColorDepth`
**Cosa rileva**: Profondità colore anomala.
**Intercetta**: Headless browsers su VM senza GPU, server senza display, emulatori.

### `dpr1` — dpr<1 (+2)
**Codice**: `_bdDpr`
**Cosa rileva**: Device Pixel Ratio anomalo.
**Intercetta**: Configurazioni anomale di automation tools, VM senza display.

### `ada` — Apple device + DPR<2 (+3)
**Codice**: `iPhone/iPad in UA + _bdDpr < 2`
**Cosa rileva**: iPhone/iPad da 2014+ hanno sempre DPR ≥ 2.
**Intercetta**: Scraper con UA iPhone falso, emulatori iOS mal configurati.

### `munt` — Mobile UA senza touch (+3)
**Codice**: `mobile UA + _bdMaxTouchPoints=0`
**Cosa rileva**: UA mobile ma maxTouchPoints=0.
**Intercetta**: Scraper headless con UA mobile senza simulazione touch.

### `dumv` — Desktop UA + touch + small viewport (+2)
**Codice**: `desktop UA + tp>0 + sW<500`
**Cosa rileva**: Inconsistenza tablet/desktop.
**Intercetta**: Bot che spoofano viewport mobile mantenendo UA desktop.

---

## GPU & Canvas fingerprint (5)

### `ce` — canvasEmpty (+3)
**Codice**: `_bdCanvasScore=3`
**Cosa rileva**: `canvas.toDataURL().length < 200`.
**Intercetta**: Browser headless senza GPU, Tor Browser (canvas randomizzato — borderline), bot che bloccano canvas API.

### `cb` — canvasBlocked (+1)
**Codice**: `_bdCanvasScore=1`
**Cosa rileva**: Eccezione su canvas API.
**Intercetta**: Browser ad alta privacy (Brave aggressive, Firefox strict, estensioni anti-fingerprinting).

### `sr` — softwareRenderer (+3)
**Codice**: `_bdWebGLScore=3`
**Cosa rileva**: GPU software emulata: SwiftShader, llvmpipe, VirtualBox, VMware, Mesa.
**Intercetta**: Headless browsers su VM (Puppeteer/Playwright/Selenium su CI/CD), Docker containers, cloud automation (Browserless, ScrapingBee, Apify).

### `nwgl` — noWebGL (+2)
**Codice**: `_bdWebGLScore=2`
**Cosa rileva**: WebGL context non disponibile.
**Intercetta**: Browser headless minimali, ambienti senza GPU virtuale.

### `we` — webglError (+1)
**Codice**: `_bdWebGLScore=1`
**Cosa rileva**: Eccezione su WebGL.
**Intercetta**: Ambienti di test, configurazioni anomale.

---

## Internazionalizzazione (2)

### `nl` — noLanguage (+2)
**Codice**: `_bdLanguage`
**Cosa rileva**: `navigator.language` vuoto.
**Intercetta**: Tutti i client HTTP basici (curl, wget, requests, urllib, httpx, aiohttp, Scrapy, axios, Go, Java, Ruby, Guzzle), crawler legittimi (Googlebot, GPTBot, ClaudeBot).

### `ltu` — Lingua + Timezone UTC (+2)
**Codice**: `_bdLanguage + _bdTimezone=UTC`
**Cosa rileva**: Combinazione tipica di server/container.
**Intercetta**: Headless browsers su server senza TZ (Docker, AWS Lambda, GCP Cloud Run), bot in datacenter.

---

## Permessi (1)

### `nd` — notificationsDenied (+1)
**Codice**: `_bdNotificationsDenied`
**Cosa rileva**: Permission notifications = denied via Permissions API.
**Intercetta**: Browser headless (denied di default). Segnale debole perché molti utenti reali negano notifiche.

---

## Comportamento (2)

### `nmm` — noMouseMove (+2)
**Codice**: `_bdMouseMoved=false`
**Cosa rileva**: Listener mousemove mai attivato.
**Intercetta**: Tutti i crawler HTTP, tutti i client HTTP, bot che non simulano interazione.

### `ns` — noScroll (+1)
**Codice**: `_bdScrolled=false`
**Cosa rileva**: Listener scroll mai attivato.
**Intercetta**: Bot scraper one-shot, crawler, client HTTP.

---

## Anti-tampering e avanzati (5)

### `tmp` — tampering (+5)
**Codice**: `_bdLiveCheckPassed=false`
**Cosa rileva**: `screen`, `navigator.webdriver`, `navigator.userAgent` modificati post-init.
**Intercetta**: Bot che usano `Object.defineProperty` per spoofare navigator dopo il caricamento, anti-detect browsers con tampering attivo.

### `smN` — syntheticMouse (+4)
**Codice**: `_bdMouseUntrustedCount>0`
**Cosa rileva**: N eventi `mousemove` con `isTrusted=false` (creati da JavaScript).
**Intercetta**: Bot che chiamano `document.dispatchEvent(new MouseEvent('mousemove'))`, AI agents, bot stealth avanzati.

### `ss` — syntheticScroll (+3)
**Codice**: `_bdScrollUntrustedCount>0`
**Cosa rileva**: Eventi `scroll` con `isTrusted=false`.
**Intercetta**: Bot che iniettano scroll sintetico per superare `_bdScrolled`.

### `lmeN` — lowMouseEntropy (+2)
**Codice**: `_bdMouseEntropy<20 && _bdMouseTrustedCount>5`
**Cosa rileva**: Entropia del percorso mouse bassa — movimenti troppo lineari o regolari. N = valore entropia (0–19).
**Intercetta**: Bot AI che generano eventi trusted ma con pattern robotici.

### `mtfN` — mouseTooFast (+2)
**Codice**: `_bdFirstMouseDelay<50ms`
**Cosa rileva**: Primo evento mouse entro N ms dall'init — reazione non umana.
**Intercetta**: Automation tools che eseguono mouseMove appena la pagina è caricata.

---

## Firme distintive

| Firma | Score | Bot identificati |
|---|---|---|
| `np\|nl\|nmm\|ns` | 7 | Client HTTP (curl, requests, axios, Scrapy) + crawler (Googlebot, GPTBot) |
| `wdt\|np\|nmm\|ns` | 10–12 | Selenium ChromeDriver, WebdriverIO, Nightwatch |
| `dh0\|wdt\|sua\|np\|ce\|sr\|nmm\|ns` | 15–23 | Puppeteer default, Apify, Browserless, Cypress headless |
| `tmp\|nmm\|ns` | 8–13 | Anti-detect browsers con tampering (Kameleo, GoLogin) |
| `sm3\|ss\|mtf8` | 7–16 | Bot con dispatchEvent, AI agents, Multilogin con interazione finta |
