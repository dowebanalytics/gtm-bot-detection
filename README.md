# GTM Bot Detection

Sistema di rilevamento bot per **Google Tag Manager** basato su 26 segnali a punteggio multi-dimensionale: fingerprint del browser, ambiente di rendering, comportamento utente, anti-tampering attivo e rilevamento eventi sintetici.

Sviluppato da [DO Web Analytics](https://dowebanalytics.com) / [Tag Manager Italia](https://tagmanageritalia.it).

---

## Caratteristiche principali

| Caratteristica | Descrizione |
|---|---|
| **Closure namespace + `Object.defineProperty` read-only** | Bot non può sovrascrivere, eliminare o ridefinire i flag del sistema |
| **`event.isTrusted` filter** su mouse/scroll | Eventi sintetici (dispatchEvent) rilevati e contati come segnali |
| **Integrity check live** | Tampering post-init di `navigator.userAgent`, `screen.width`, ecc. rilevato (+5) |
| **Mouse entropy** | Movimenti robotici (linee dritte, timing uniforme) identificati (+2) |
| **First-mouse-delay** | Eventi mouse iniettati < 50ms dopo init rilevati (+2) |
| **Compatibilità sandbox GTM** | Permission read-only, niente regex, niente API native non supportate |
| **Zero falsi positivi** | Testato su 20+ scenari di utenti reali (browser mainstream, mobile, in-app WebView, device anomali) |

---

## Componenti

| File | Tipo GTM | Descrizione |
|---|---|---|
| `dom-helper/bot-detection-dom-helper.html` | Custom HTML Tag | Cattura ambiente, fingerprint, listener comportamentali con anti-tampering |
| `templates/variable-result/bot-detection-result.tpl` | Custom Template VARIABLE | Legge i flag `_bd*` e calcola lo score |

---

## Setup GTM

### 1. DOM Helper

**Tags → New → Custom HTML** → incolla il contenuto di `dom-helper/bot-detection-dom-helper.html` → trigger **Initialization** → priorità **100**.

> ⚠️ **Trigger consigliato: Initialization** (non DOM Ready). In questo modo i flag `_bd*` sono disponibili già al momento del Page View, e la variabile può essere usata su qualsiasi trigger — incluso `All Pages` — senza dover configurare Tag Sequencing su ogni tag.

Configurazione modificabile in cima al file:
```js
S.threshold = 5;     // 3=aggressiva | 5=default | 7=conservativa
S.debug     = false; // true = log [BotDetect] in console
```

### 2. Template Result

**Templates → New → Import** → seleziona `templates/variable-result/bot-detection-result.tpl` → Salva.

Al popup "Permission changes detected" clicca **Approve all**.

### 3. Variabile

**Variables → New → Bot Detection Result** (seleziona il template appena importato) → Salva.

### 4. Tag Sequencing su tag critici (opzionale)

Con il DOM Helper su **Initialization + priorità 100** la variabile è già disponibile per qualsiasi trigger, anche Page View. Il Tag Sequencing rimane comunque utile come **belt-and-suspenders** sui tag critici (conversion GA4, form submit checkout, payment, fraud check):

1. Apri il tag (es. GA4 Event "purchase")
2. **Advanced Settings → Tag Sequencing**
3. Spunta **Fire a tag before [Tag] fires**
4. Setup Tag: seleziona **Bot Detection DOM Helper**
5. Spunta **Don't fire [Tag] if [Setup Tag] fails or is paused**
6. Salva

La guard `_bdHelperLoaded` nel DOM Helper rende il setup idempotente: nessuna penalità di performance.

### 5. Pubblicazione

Submit & Publish il container. La variabile `{{Bot Detection Result}}` restituisce un oggetto con tre proprietà:

```js
// utente normale
{ status: "normal_user", score: 0, signals: "" }

// bot rilevato
{ status: "possible_bot", score: 18, signals: "tmp|wdt|dh0|np|nmm|ns" }
```

Le tre proprietà si leggono con variabili **Custom JavaScript** in GTM:

```js
// Bot Detection - Status
function() { return {{Bot Detection Result}}.status || 'normal_user'; }

// Bot Detection - Score
function() { return {{Bot Detection Result}}.score || 0; }

// Bot Detection - Signals
function() { return {{Bot Detection Result}}.signals || ''; }
```

Mappa ciascuna a una **Custom Dimension** in GA4 per filtrare e segmentare il traffico bot nei report.

---

## Quando valutare la variabile

| Trigger di valutazione | Quando usarlo |
|---|---|
| **Form Submit** | Lead gen, contatti, checkout |
| **Click CTA / Add to Cart** | E-commerce, landing page |
| **Scroll Depth ≥ 25%** | Blog, pagine editoriali |
| **Timer 5000ms** | Pagine senza interazioni |
| ❌ DOM Ready / Pageview | NON usare — i segnali comportamentali (mouseMoved, scrolled) non sarebbero ancora popolati |

---

## Strategia di esecuzione del DOM Helper

Con il DOM Helper su **Initialization + priorità 100**, i flag `_bd*` sono disponibili già al momento del Page View. Questa è la configurazione consigliata perché la variabile può essere usata su qualsiasi trigger GTM (Page View, All Pages, DOM Ready, eventi utente) senza dover configurare nulla sui singoli tag.

### Flusso eventi GTM

```
1. consent_initialization
2. initialization           ← DOM Helper fira qui (priority 100)
3. gtm.js / pageview        ← variabile già disponibile
4. gtm.dom / DOM Ready
5. gtm.load / Window Loaded
6. eventi utente (click, scroll, form submit, custom events)
```

### Quando aggiungere Tag Sequencing

| Scenario | Configurazione consigliata |
|---|---|
| Setup standard | DOM Helper su Initialization + priorità 100 — sufficiente |
| Tag critici (conversion GA4, form submit, checkout) | + Tag Sequencing come belt-and-suspenders |
| Container con bot filtering pervasivo | + Tag Sequencing su tutti i tag rilevanti |

Il Tag Sequencing rimane lo strumento giusto per garantire l'esecuzione del DOM Helper anche in scenari edge case. La guard idempotente rende il setup gratuito in termini di performance.

### Limite: segnali comportamentali su Page View

Su Page View i listener mouse/scroll non hanno ancora avuto tempo di catturare interazioni utente, quindi `noMouseMove (+2)` e `noScroll (+1)` saranno sempre attivi. Ogni utente parte con uno **score base +3**.

Con soglia default 5: un utente reale con fingerprint pulito = 3 (USER), un bot con anche solo noPlugins = 5 (BOT). Le metriche di detection rimangono valide — ma per scenari ad alta criticità considera di valutare la variabile anche su un evento utente successivo (Add to Cart, Click) per beneficiare dei segnali comportamentali pieni.

---

## Testing

### Test con Custom HTML in GTM Preview

Per verificare il funzionamento senza bot reali, crea un tag **Custom HTML** in GTM che simula i segnali più comuni:

**Tag: `[DEBUG] Bot Detection Injector`**

```html
<script>
  window._bdResultCache     = null;  // reset cache — forza ricalcolo
  window._bdInit            = true;  // abilita check mouse/scroll
  window._bdWebdriver       = true;  // +5
  window._bdLiveCheckPassed = false; // +5
  window._bdPluginsLen      = 0;     // +2
  window._bdMouseMoved      = false; // +2
  window._bdScrolled        = false; // +1
  window._bdScreenWidth     = 1920;
  window._bdScreenHeight    = 1080;
  window._bdBrowserWidth    = 1920;
  window._bdBrowserHeight   = 1080;  // deltaHeight<=0 → +3
  window._bdThreshold       = 5;
  window._bdDebug           = true;  // attiva log in console
</script>
```

| Campo GTM | Valore |
|---|---|
| Trigger | **Initialization** |
| Firing Priority | `999` |
| Nome | `[DEBUG] Bot Detection Injector` |

> ⚠️ **Rimuovi o disabilita questo tag prima di pubblicare** — altrimenti tutto il traffico reale risulterà bot.

**Verifica in GTM Preview:**
1. Attiva Preview → carica la pagina
2. Clicca sull'evento **Page View** nel Tag Assistant
3. Vai su **Variables** → cerca `Bot Detection Result`
4. Atteso: `{ status: "possible_bot", score: 18, signals: "tmp|wdt|dh0|np|nmm|ns" }`

**Verifica in console:**
```js
window._bdResultCache
// { status: "possible_bot", score: 18, signals: "tmp|wdt|dh0|np|nmm|ns" }
```

---

## I 26 segnali

### Browser identity (4)

| Segnale | Punti | Descrizione |
|---|---|---|
| `webdriver=true` | +5 | `navigator.webdriver` esposto |
| `headlessChrome / Selenium in UA` | +4 | Pattern nello User Agent |
| `plugins.length=0` | +2 | Plugin assenti |
| `window.chrome` assente su Chrome | +3 | Inconsistenza Chrome UA |

### Display fingerprint (7)

| Segnale | Punti | Descrizione |
|---|---|---|
| `deltaWidth < 0` | +3 | Browser più largo dello schermo |
| `deltaHeight ≤ 0` | +3 | Browser alto quanto lo schermo |
| `mobile UA + no touch` | +3 | UA dice mobile ma `maxTouchPoints=0` |
| `apple device + dpr < 2` | +3 | iPhone/iPad senza Retina DPR |
| `colorDepth<16` | +2 | Display non standard |
| `dpr<1` | +2 | Anomalia DPR |
| `desktop UA + touch + small screen` | +2 | Inconsistenza |

### GPU & Canvas (5)

| Segnale | Punti | Descrizione |
|---|---|---|
| `canvasEmpty` | +3 | Canvas fingerprint troppo corto |
| `canvasBlocked` | +1 | Canvas API non disponibile |
| `softwareRenderer` | +3 | SwiftShader, llvmpipe, Mesa, VirtualBox, VMware |
| `noWebGL` | +2 | WebGL non disponibile |
| `webglError` | +1 | Errore creazione WebGL |

### Internazionalizzazione (2)

| Segnale | Punti | Descrizione |
|---|---|---|
| `noLanguage` | +2 | `navigator.language` vuoto |
| `lang + tz=UTC` | +2 | Combinazione tipica di datacenter |

### Permessi (1)

| Segnale | Punti | Descrizione |
|---|---|---|
| `notificationsDenied` | +1 | Permission notifications denied di default |

### Comportamento (2)

| Segnale | Punti | Descrizione |
|---|---|---|
| `noMouseMove` | +2 | Nessun movimento mouse rilevato |
| `noScroll` | +1 | Nessun scroll rilevato |

### Anti-tampering e avanzati (5)

| Segnale | Punti | Descrizione |
|---|---|---|
| `tampering` | +5 | `screen/navigator.userAgent/webdriver` modificati post-init |
| `syntheticMouse` | +4 | Eventi `mousemove` con `isTrusted=false` (dispatchEvent) |
| `syntheticScroll` | +3 | Eventi `scroll` con `isTrusted=false` |
| `lowMouseEntropy` | +2 | Movimento mouse lineare con timing uniforme |
| `mouseTooFast` | +2 | Primo mouse < 50ms dopo init DOM Helper |

---

## Soglie consigliate

| Soglia | Profilo sito | Trade-off |
|---|---|---|
| **3** (aggressiva) | E-commerce sotto attacco, form spam | Massima protezione, alcuni FP su browser privacy |
| **5** (default) | Uso generale | Equilibrio ottimale |
| **6-7** (conservativa) | Pubblico tech/privacy, target Tor o Smart TV | Zero FP, perde alcuni adversarial |
| **10+** (diagnostico) | Solo metriche, no blocco | Solo bot evidenti |

---

## Risultati test

Il sistema è stato sottoposto a stress test su 130 scenari rappresentativi del panorama bot 2025:

| Categoria | Detection rate |
|---|---|
| HTTP scrapers (curl, requests, axios, ecc.) | 100% (16/16) |
| Crawler (Googlebot, GPTBot, ClaudeBot, ecc.) | 100% (8/8) |
| CAPTCHA solvers (2Captcha, AntiCaptcha, ecc.) | 100% (4/4) |
| Mobile farms (BrowserStack, Appium, ecc.) | 100% (10/10) |
| Bot con eventi sintetici | ~95% rilevati |
| Bot con tampering | 100% rilevati |
| **Utenti reali** | **0 falsi positivi (0/20)** |
| Resilienza tampering | 8/8 attacchi bloccati o rilevati |

Vedi `docs/test-results.md` per il report dettagliato.

---

## Limiti documentati

Tre scenari **non rilevabili** dal client-side:

1. **Bot stealth perfetto senza interazione** — score 3 (solo `noMouseMove` + `noScroll`), indistinguibile da utente reale che apre la pagina e non fa nulla
2. **Click farm umani reali** — non è automazione, è traffico umano malevolo
3. **Account hijack** — browser legittimo, utente illegittimo

Per coprire questi casi serve un layer **server-side**: IP reputation (Cloudflare, AWS WAF), rate limiting, fraud detection dedicato (Sift, DataDome, PerimeterX).

---

## Documentazione

- [`docs/setup-guide.md`](docs/setup-guide.md) — guida installazione GTM passo-passo
- [`docs/test-results.md`](docs/test-results.md) — risultati stress test su 130 scenari
- [`docs/signals.md`](docs/signals.md) — catalogo dettagliato dei 26 segnali con esempi

---

## License

MIT — usabile commercialmente, attribuzione apprezzata.

## Credits

DO Web Analytics / Tag Manager Italia
