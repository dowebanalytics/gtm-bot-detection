# GTM Bot Detection v4

Sistema di rilevamento bot per **Google Tag Manager** basato su score multi-segnale (26 segnali) con anti-tampering, integrity check e filtro eventi sintetici.

Sviluppato da [DO Web Analytics](https://dowebanalytics.com) / [Tag Manager Italia](https://tagmanageritalia.it).

---

## Cosa cambia in v4 rispetto a v3

| Miglioramento | Beneficio |
|---|---|
| **Closure namespace + `Object.defineProperty` read-only** | Bot non può sovrascrivere o eliminare i flag `_bd*` |
| **`event.isTrusted` filter** su mouse/scroll | Eventi sintetici (dispatchEvent) rilevati e contati |
| **Integrity check live** su screen/navigator | Tampering post-init di `navigator.userAgent`, `screen.width`, ecc. rilevato (+5) |
| **Mouse entropy** | Movimenti robotici (linee dritte, timing uniforme) rilevati (+2) |
| **First-mouse-delay** | Eventi mouse iniettati < 50ms dopo init rilevati (+2) |

**5 vulnerabilità tampering chiuse**, **stealth L7-L9 ora rilevati**, **0 nuovi falsi positivi** rispetto a v3.

---

## Componenti

| File | Tipo GTM | Descrizione |
|---|---|---|
| `dom-helper/bot-detection-dom-helper.html` | Custom HTML Tag | Cattura ambiente, fingerprint, listener comportamentali con anti-tampering |
| `templates/variable-result/bot-detection-result.tpl` | Custom Template VARIABLE | Legge i flag `_bd*` e calcola lo score |

Il template `tag-init` di v3 è stato **deprecato** in v4: la configurazione (threshold, debug) vive ora dentro il DOM Helper.

---

## Setup GTM

### 1. DOM Helper

**Tags → New → Custom HTML** → incolla il contenuto di `dom-helper/bot-detection-dom-helper.html` → trigger **DOM Ready** → priorità **20**.

Configurazione modificabile in cima al file:
```js
S.threshold = 5;     // 3=aggressiva | 5=default | 7=conservativa
S.debug     = false; // true = log [BotDetect] in console
```

### 2. Template Result

**Templates → New → Import** → seleziona `templates/variable-result/bot-detection-result.tpl` → Salva.

Al popup "Permission changes detected" clicca **Approve all**.

### 3. Variabile

**Variables → New → Bot Detection Result v4** (selezionare il template appena importato) → Salva.

### 4. Pubblicazione

Submit & Publish il container. La variabile `{{Bot Detection Result}}` restituisce `'possible bot'` o `'normal user'`.

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

## I 26 segnali

### Segnali base (21, ereditati da v3)

| Segnale | Punti | Descrizione |
|---|---|---|
| `webdriver=true` | +5 | `navigator.webdriver` esposto |
| `headlessChrome / Selenium in UA` | +4 | Pattern stringa nello User Agent |
| `deltaWidth < 0` | +3 | Browser più largo dello schermo |
| `deltaHeight ≤ 0` | +3 | Browser alto quanto lo schermo |
| `mobile UA + no touch` | +3 | UA dice mobile ma `maxTouchPoints=0` |
| `apple device + dpr < 2` | +3 | Anomalia Apple |
| `canvasEmpty` | +3 | Canvas fingerprint troppo corto |
| `softwareRenderer` | +3 | SwiftShader, llvmpipe, Mesa |
| `window.chrome` assente su Chrome | +3 | Chrome dovrebbe esporlo |
| `plugins.length=0` | +2 | Browser headless o privacy estremo |
| `colorDepth<16` | +2 | Display non standard |
| `dpr<1` | +2 | Anomalia DPR |
| `desktop UA + touch + small screen` | +2 | Inconsistenza |
| `noLanguage` | +2 | navigator.language vuoto |
| `lang + tz=UTC` | +2 | Combinazione sospetta |
| `notificationsDenied` | +1 | Permessi negati di default |
| `noMouseMove` | +2 | Nessun movimento mouse |
| `noScroll` | +1 | Nessun scroll |
| Canvas blocked | +1 | Canvas error |
| WebGL no | +2 | WebGL non disponibile |
| WebGL error | +1 | Errore creazione WebGL |

### Segnali nuovi v4 (5)

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
| **6-7** (conservativa) | Pubblico tech/privacy, target Tor o Smart TV | Zero FP, perde alcuni adversarial L6 |
| **10+** (diagnostico) | Solo metriche, no blocco | Solo bot evidenti |

---

## Test eseguiti

Il sistema è stato sottoposto a stress test su `demo-stape.myshopify.com`:

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

Vedi `docs/` per i report DOCX dettagliati.

---

## Limiti documentati

Tre scenari **non rilevabili** dal client-side anche con v4:

1. **Bot stealth perfetto senza interazione** — score 3 (solo noMouse + noScroll), indistinguibile da utente reale che apre la pagina e non fa nulla
2. **Click farm umani reali** — non è automazione, è traffico umano malevolo
3. **Account hijack** — browser legittimo, utente illegittimo

Per coprire questi casi serve un layer **server-side**: IP reputation (Cloudflare, AWS WAF), rate limiting, fraud detection dedicato (Sift, DataDome, PerimeterX).

---

## Compatibilità

v4 è **drop-in replacement** di v3:
- Stessi nomi variabili `window._bd*`
- Stesso output `'possible bot'` / `'normal user'`
- Stessi trigger GTM
- Stessa configurazione (threshold modificabile in DOM Helper)

L'unico cambiamento operativo è il **re-import del template variable** con approvazione delle 7 nuove permission.

---

## License

MIT — usabile commercialmente, attribuzione apprezzata.

## Credits

DO Web Analytics / Tag Manager Italia — 2025
