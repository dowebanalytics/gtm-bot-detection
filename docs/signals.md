# Catalogo segnali — GTM Bot Detection

Bot Detection utilizza 26 segnali a punteggio organizzati in 7 categorie. Ogni segnale somma punti al totale; quando il totale supera la soglia (default 5), la variabile restituisce `{ status: 'possible_bot', score: N, signals: '...' }`.

---

## Tabella abbreviazioni segnali

La proprietà `signals` dell'oggetto restituito usa abbreviazioni per contenere la stringa entro i 100 caratteri accettati da GA4.

| Segnale originale | Abbreviazione | Descrizione | Score |
|---|---|---|---|
| `tampering` | `tmp` | Proprietà del browser manomesse post-init | +5 |
| `webdriver=true` | `wdt` | `navigator.webdriver === true` | +5 |
| `suspiciousUA` | `sua` | UA contiene keyword headless/bot | +4 |
| `syntheticMouse=N` | `smN` | N eventi mouse con `isTrusted=false` | +4 |
| `deltaWidth<0` | `dw0` | Larghezza finestra > schermo | +3 |
| `deltaHeight<=0` | `dh0` | Nessuna barra UI browser — headless | +3 |
| `appleDprAnomaly` | `ada` | Dispositivo Apple con DPR < 2 | +3 |
| `mobileUAnoTouch` | `munt` | UA mobile ma nessun touch point | +3 |
| `canvasEmpty` | `ce` | Canvas fingerprint completamente vuoto | +3 |
| `softwareRenderer` | `sr` | WebGL usa renderer software (SwiftShader, llvmpipe) | +3 |
| `chromeMissing` | `cm` | UA dichiara Chrome ma `window.chrome` è assente | +3 |
| `syntheticScroll` | `ss` | Scroll con `isTrusted=false` | +3 |
| `noPlugins` | `np` | `navigator.plugins.length === 0` | +2 |
| `colorDepth<16` | `cd16` | Profondità colore < 16 bit | +2 |
| `dpr<1` | `dpr1` | Device pixel ratio < 1 — impossibile | +2 |
| `desktopUAmobileViewport` | `dumv` | UA desktop ma viewport < 500px con touch | +2 |
| `noWebGL` | `nwgl` | WebGL non disponibile | +2 |
| `noLanguage` | `nl` | `navigator.language` vuoto | +2 |
| `langTimezoneUTC` | `ltu` | Lingua impostata ma timezone UTC | +2 |
| `noMouseMove` | `nmm` | Nessun movimento mouse registrato | +2 |
| `lowMouseEntropy=N` | `lmeN` | Entropia movimento mouse < 20 | +2 |
| `mouseTooFast=Nms` | `mtfN` | Primo evento mouse entro N ms dal caricamento | +2 |
| `noScroll` | `ns` | Nessuno scroll registrato | +1 |
| `canvasBlocked` | `cb` | Canvas API bloccata o nulla | +1 |
| `webglError` | `we` | WebGL restituisce errore generico | +1 |
| `notificationsDenied` | `nd` | Permessi notifiche negati automaticamente | +1 |

**Score massimo teorico:** +66. In scenari reali raramente si supera 20–25 poiché molti segnali si escludono a vicenda.

**Esempio output:**
```json
{ "status": "possible_bot", "score": 18, "signals": "tmp|wdt|dh0|np|nmm|ns" }
```

---

## Browser identity (4)

### `wdt` — webdriver=true (+5)

**Flag interno**: `_bdWebdriver`  
**Rileva**: `navigator.webdriver === true` esposto dal browser.  
**Intercetta**: Selenium WebDriver, ChromeDriver, GeckoDriver, Edge WebDriver, Cypress (default), TestCafe, WebdriverIO, Nightwatch.js, Playwright base, Puppeteer base.

### `sua` — User Agent sospetto (+4)

**Flag interno**: `_bdUA`  
**Rileva**: Pattern `HeadlessChrome`, `Selenium`, `PhantomJS`, `webdriver` nello User Agent.  
**Intercetta**: Puppeteer default, Pyppeteer, Apify SDK, Browserless.io, PhantomJS, Splash (Scrapy), Cypress headless mal configurato.

### `np` — plugins.length=0 (+2)

**Flag interno**: `_bdPluginsLen`  
**Rileva**: Plugin collection vuota.  
**Intercetta**: Browser headless, tutti i client HTTP (curl, wget, python-requests, urllib, httpx, aiohttp, Scrapy, axios, Go, Java, Ruby), Tor Browser e browser privacy estremi (borderline).

### `cm` — window.chrome assente (+3)

**Flag interno**: `_bdHasChromeObj`  
**Rileva**: Mancanza di `window.chrome` quando lo UA dichiara Chrome.  
**Intercetta**: Bot che spoofano lo UA Chrome senza ricostruire l'oggetto chrome (curl-impersonate, fake-useragent, framework headless mal configurati).

---

## Display fingerprint (7)

### `dw0` — deltaWidth < 0 (+3)

**Calcolo**: `_bdScreenWidth - _bdBrowserWidth`  
**Rileva**: Browser più largo dello schermo (fisicamente impossibile).  
**Intercetta**: Bot che spoofano dimensioni inconsistenti, viewport mal configurate, emulatori.

### `dh0` — deltaHeight ≤ 0 (+3)

**Calcolo**: `_bdScreenHeight - _bdBrowserHeight`  
**Rileva**: Viewport alto quanto (o più di) lo schermo — nessuna barra browser.  
**Intercetta**: Headless browsers in modalità full-screen (config default di Puppeteer/Playwright/Cypress), Smart TV browsers e console gaming (borderline).

### `cd16` — colorDepth<16 (+2)

**Flag interno**: `_bdColorDepth`  
**Rileva**: Profondità colore anomala.  
**Intercetta**: Headless browsers su VM senza GPU, server senza display, emulatori.

### `dpr1` — dpr<1 (+2)

**Flag interno**: `_bdDpr`  
**Rileva**: Device Pixel Ratio < 1 — fisicamente impossibile su qualsiasi display.  
**Intercetta**: Configurazioni anomale di automation tools, VM senza display.

### `ada` — Apple device + DPR<2 (+3)

**Logica**: `iPhone/iPad in UA + _bdDpr < 2`  
**Rileva**: Tutti gli iPhone e iPad da 2014+ hanno DPR ≥ 2.  
**Intercetta**: Scraper con UA iPhone falso, emulatori iOS mal configurati.

### `munt` — Mobile UA senza touch (+3)

**Logica**: `mobile UA + _bdMaxTouchPoints=0`  
**Rileva**: UA mobile ma maxTouchPoints=0 — impossibile su dispositivo reale.  
**Intercetta**: Scraper headless con UA mobile senza simulazione touch.

### `dumv` — Desktop UA + touch + small viewport (+2)

**Logica**: `desktop UA + tp>0 + sW<500`  
**Rileva**: Inconsistenza viewport/UA.  
**Intercetta**: Bot che spoofano viewport mobile mantenendo UA desktop.

---

## GPU & Canvas fingerprint (5)

### `ce` — canvasEmpty (+3)

**Flag interno**: `_bdCanvasScore=3`  
**Rileva**: `canvas.toDataURL().length < 200`.  
**Intercetta**: Browser headless senza GPU, Tor Browser con canvas randomizzato (borderline), bot che bloccano canvas API.

### `cb` — canvasBlocked (+1)

**Flag interno**: `_bdCanvasScore=1`  
**Rileva**: Eccezione su canvas API.  
**Intercetta**: Browser ad alta privacy (Brave aggressive, Firefox strict, estensioni anti-fingerprinting).

### `sr` — softwareRenderer (+3)

**Flag interno**: `_bdWebGLScore=3`  
**Rileva**: GPU software emulata: SwiftShader, llvmpipe, VirtualBox, VMware, Mesa.  
**Intercetta**: Headless browsers su VM (Puppeteer/Playwright/Selenium su CI/CD), Docker containers, cloud automation (Browserless, ScrapingBee, Apify).

### `nwgl` — noWebGL (+2)

**Flag interno**: `_bdWebGLScore=2`  
**Rileva**: WebGL context non disponibile.  
**Intercetta**: Browser headless minimali, ambienti senza GPU virtuale.

### `we` — webglError (+1)

**Flag interno**: `_bdWebGLScore=1`  
**Rileva**: Eccezione su WebGL.  
**Intercetta**: Ambienti di test, configurazioni anomale.

---

## Internazionalizzazione (2)

### `nl` — noLanguage (+2)

**Flag interno**: `_bdLanguage`  
**Rileva**: `navigator.language` vuoto o assente.  
**Intercetta**: Client HTTP basici (curl, wget, requests, urllib, httpx, aiohttp, Scrapy, axios, Go, Java, Ruby, Guzzle), crawler legittimi (Googlebot, GPTBot, ClaudeBot).

### `ltu` — Lingua + Timezone UTC (+2)

**Logica**: `_bdLanguage non vuoto + _bdTimezone=UTC`  
**Rileva**: Combinazione tipica di server/container con TZ non impostata.  
**Intercetta**: Headless browsers su server senza TZ (Docker, AWS Lambda, GCP Cloud Run), bot in datacenter.

---

## Permessi (1)

### `nd` — notificationsDenied (+1)

**Flag interno**: `_bdNotificationsDenied`  
**Rileva**: Permission notifications = denied via Permissions API.  
**Intercetta**: Browser headless (denied di default). Segnale debole: molti utenti reali negano le notifiche.

---

## Comportamento (2)

### `nmm` — noMouseMove (+2)

**Flag interno**: `_bdMouseMoved=false`  
**Rileva**: Listener mousemove mai attivato.  
**Nota**: Sempre attivo su Page View (l'utente non ha ancora mosso il mouse) — contribuisce allo score base +3.  
**Intercetta**: Tutti i crawler HTTP, client HTTP, bot che non simulano interazione.

### `ns` — noScroll (+1)

**Flag interno**: `_bdScrolled=false`  
**Rileva**: Listener scroll mai attivato.  
**Nota**: Sempre attivo su Page View — contribuisce allo score base +3.  
**Intercetta**: Bot scraper one-shot, crawler, client HTTP.

---

## Anti-tampering e avanzati (5)

### `tmp` — tampering (+5)

**Flag interno**: `_bdLiveCheckPassed=false`  
**Rileva**: `screen`, `navigator.webdriver`, `navigator.userAgent` modificati post-init tramite `Object.defineProperty` o assegnazione diretta.  
**Intercetta**: Anti-detect browsers (Kameleo, GoLogin, Multilogin), bot che spoofano navigator dopo il caricamento.

### `smN` — syntheticMouse (+4)

**Flag interno**: `_bdMouseUntrustedCount>0`  
**Rileva**: N eventi `mousemove` con `isTrusted=false` (creati tramite JavaScript, non da hardware reale).  
**Intercetta**: Bot che chiamano `document.dispatchEvent(new MouseEvent('mousemove'))`, AI agents, bot stealth avanzati che cercano di bypassare `nmm`.

### `ss` — syntheticScroll (+3)

**Flag interno**: `_bdScrollUntrustedCount>0`  
**Rileva**: Eventi `scroll` con `isTrusted=false`.  
**Intercetta**: Bot che iniettano scroll sintetico per bypassare `ns`.

### `lmeN` — lowMouseEntropy (+2)

**Logica**: `_bdMouseEntropy<20 && _bdMouseTrustedCount>5`  
**Rileva**: Entropia del percorso mouse bassa — movimenti lineari o con timing troppo regolare. N = valore entropia (0–19).  
**Intercetta**: Bot AI che generano eventi `isTrusted=true` ma con pattern robotici (linee dritte, velocità costante).

### `mtfN` — mouseTooFast (+2)

**Flag interno**: `_bdFirstMouseDelay<50ms`  
**Rileva**: Primo evento mouse entro N ms dall'init del DOM Helper — reazione non umana.  
**Intercetta**: Automation tools che eseguono `mouseMove` immediatamente dopo il caricamento della pagina.

---

## Firme distintive

| Firma | Score | Bot identificati |
|---|---|---|
| `np\|nl\|nmm\|ns` | 7 | Client HTTP (curl, requests, axios) + crawler (Googlebot, GPTBot) |
| `wdt\|np\|nmm\|ns` | 10–12 | Selenium ChromeDriver, WebdriverIO, Nightwatch |
| `dh0\|wdt\|sua\|np\|ce\|sr\|nmm\|ns` | 15–23 | Puppeteer default, Apify, Browserless, Cypress headless |
| `tmp\|nmm\|ns` | 8–13 | Anti-detect browsers con tampering (Kameleo, GoLogin) |
| `sm3\|ss\|mtf8` | 7–16 | Bot con dispatchEvent, AI agents, Multilogin con interazione finta |

---

## Note su segnali borderline

Alcuni segnali possono attivarsi su utenti reali in edge case:

| Segnale | Edge case utenti reali | Impatto |
|---|---|---|
| `np` | Tor Browser, Firefox Strict | +2 — basso da solo |
| `cb` | Brave aggressive, Firefox strict + CanvasBlocker | +1 — basso |
| `nd` | Utenti che negano manualmente le notifiche | +1 — trascurabile |
| `dh0` | Smart TV, console gaming (PS5, Xbox) | +3 — considerare soglia 6–7 |
| `ltu` | Utenti con VPN in USA/UK senza TZ localizzata | +2 — basso da solo |
| `nmm\|ns` | Page View (score base) | +3 — attesi, non indicano bot da soli |

Con soglia default **5**, la combinazione di segnali borderline da sola non supera la soglia senza almeno un segnale hardware/fingerprint aggiuntivo.
