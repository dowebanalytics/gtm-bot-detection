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

> ⚠️ **Trigger obbligatorio: Initialization** (non DOM Ready). In questo modo i flag `_bd*` sono disponibili già al momento del Page View, e la variabile può essere usata su qualsiasi trigger — incluso `All Pages` — senza dover configurare Tag Sequencing su ogni tag.

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

### 4. Variabili CJS per leggere i singoli valori

Crea tre variabili **Custom JavaScript** in GTM:

```js
// Bot - Status
function() {
  var r = {{Bot Detection Result}};
  return (r && r.status) ? r.status : 'normal_user';
}

// Bot - Score
function() {
  var r = {{Bot Detection Result}};
  return (r && r.score !== undefined) ? r.score : 0;
}

// Bot - Signals
function() {
  var r = {{Bot Detection Result}};
  return (r && r.signals) ? r.signals : '';
}
```

---

## Strategie di propagazione su tutti gli eventi

Il DOM Helper scrive i flag `_bd*` al momento dell'Initialization. La variabile `{{Bot Detection Result}}` è live (nessuna cache) e può essere letta da qualsiasi evento successivo. Esistono tre strategie complementari, applicabili insieme.

### Strategia A — GA4 Configuration Parameters (event-scoped, consigliata)

I parametri impostati sul **tag GA4 Configuration** vengono ereditati da tutti i GA4 Event tag che referenziano quel config tag — senza modificare i singoli tag.

```
Tag: GA4 Configuration
→ Configuration Parameters:
   bot_status  =  {{Bot - Status}}
   bot_score   =  {{Bot - Score}}
   bot_signals =  {{Bot - Signals}}
```

Poiché `{{Bot Detection Result}}` ricalcola ad ogni chiamata, ogni evento porta il valore corrente al momento del suo firing — non uno snapshot del Page View.

In GA4 → Admin → Custom Definitions → **Event-scoped** → registra `bot_status`, `bot_score`, `bot_signals`.

> ℹ️ Se preferisci una dimensione **User-scoped** (persiste all'intera sessione invece che al singolo evento), usa invece la sezione **User Properties** dello stesso tag GA4 Configuration. La differenza è solo nel tipo di dimensione GA4, non nella configurazione GTM.

### Strategia B — Blocking trigger universale per conversion tag

Crea un **exception trigger** da applicare a tutti i tag che non devono sparare per i bot (Google Ads, Meta Pixel, Microsoft UET, TikTok, GA4 purchase/lead).

**Triggers → New:**

```
Nome:  [BD] Possible Bot - Block
Tipo:  Custom Event
Event name:  .*
Use regex matching:  ✓
Condizione:  {{Bot - Status}}  equals  possible_bot
```

Aggiungi questo trigger come **eccezione** (blocco) su ogni tag conversion.

### Strategia C — Tag Sequencing sui tag critici (belt-and-suspenders)

Per i tag dove un falso positivo ha costo elevato (conversion billing, fraud detection):

1. Apri il tag dipendente (es. GA4 Event "purchase")
2. **Advanced Settings → Tag Sequencing**
3. Spunta **Fire a tag before [Tag] fires**
4. Setup Tag: `Bot Detection DOM Helper`
5. Spunta **Don't fire [Tag] if [Setup Tag] fails or is paused**
6. Salva

La guard `_bdHelperLoaded` nel DOM Helper rende il setup idempotente: nessuna penalità di performance se il DOM Helper è già girato.

### Schema completo

```
Initialization (priority 100)
  └─ Bot Detection DOM Helper
       └─ setta _bd* flags + guard _bdHelperLoaded

gtm.js / Page View
  └─ GA4 Configuration
       └─ Configuration Parameter: bot_status = {{Bot - Status}}
       └─ Configuration Parameter: bot_score  = {{Bot - Score}}
            ↓ ereditato da TUTTI i GA4 Event tag

Ogni evento custom / click / scroll / form
  └─ Tag GA4 Event       → porta bot_status automaticamente (Strategia A)
  └─ Tag Ads Conversion  → bloccato da [BD] Possible Bot - Block (Strategia B)
  └─ Tag Meta Pixel      → bloccato da [BD] Possible Bot - Block (Strategia B)
  └─ Tag GA4 purchase    → Strategia A + B + C (belt-and-suspenders)
```

---

### 5. Pubblicazione

Submit & Publish il container.

---

## Quando valutare la variabile

| Trigger di valutazione | Affidabilità detection | Note |
|---|---|---|
| **Custom Event / Add to Cart / Click CTA** | **Massima** | Tutti i segnali popolati |
| **Form Submit** | **Massima** | L'utente ha interagito |
| **Scroll Depth ≥ 25%** | **Alta** | Scroll attivo, mouse spesso attivo |
| **Timer 5000ms** | **Buona** | L'utente potrebbe aver interagito |
| **Page View / All Pages** | **Buona** | Segnali fingerprint completi, ma `noMouseMove (+2)` e `noScroll (+1)` sempre attivi → score base **+3** |

> ⚠️ Su Page View ogni sessione parte con score **+3** (noMouseMove + noScroll). Con soglia default 5: un utente reale con fingerprint pulito = 3 → USER, un bot con un solo segnale aggiuntivo = 5 → BOT. Per scenari ad alta criticità valuta la variabile anche su un evento utente successivo per beneficiare dei segnali comportamentali pieni.

---

## Soglie consigliate

| Soglia | Profilo sito | Trade-off |
|---|---|---|
| **3** (aggressiva) | E-commerce sotto attacco, form spam | Massima protezione, alcuni FP su browser privacy |
| **5** (default) | Uso generale | Equilibrio ottimale |
| **6–7** (conservativa) | Pubblico tech/privacy, target Tor o Smart TV | Zero FP, perde alcuni adversarial |
| **10+** (diagnostico) | Solo metriche, no blocco | Solo bot evidenti |

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
| `noScroll` | +1 | Nessuno scroll rilevato |

### Anti-tampering e avanzati (5)

| Segnale | Punti | Descrizione |
|---|---|---|
| `tampering` | +5 | `screen/navigator.userAgent/webdriver` modificati post-init |
| `syntheticMouse` | +4 | Eventi `mousemove` con `isTrusted=false` (dispatchEvent) |
| `syntheticScroll` | +3 | Eventi `scroll` con `isTrusted=false` |
| `lowMouseEntropy` | +2 | Movimento mouse lineare con timing uniforme |
| `mouseTooFast` | +2 | Primo mouse < 50ms dopo init DOM Helper |

---

## Testing

### Test con Custom HTML in GTM Preview

**Tag: `[DEBUG] Bot Detection Injector`**

```html
<script>
  // I _bd* sono getter live definiti dal DOM Helper via Object.defineProperty.
  // Per un test affidabile usa priority 999 su Initialization (dopo il DOM Helper a 100).
  window._bdInit            = true;
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
  window._bdDebug           = true;
</script>
```

| Campo GTM | Valore |
|---|---|
| Trigger | **Initialization** |
| Firing Priority | `999` |
| Nome | `[DEBUG] Bot Detection Injector` |

> ⚠️ Rimuovi o disabilita questo tag prima di pubblicare.

**Atteso in Preview → Variables → Bot Detection Result:**
```json
{ "status": "possible_bot", "score": 18, "signals": "tmp|wdt|dh0|np|nmm|ns" }
```

---

## Risultati test

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
- [`docs/signals.md`](docs/signals.md) — catalogo dettagliato dei 26 segnali con esempi
- [`docs/test-results.md`](docs/test-results.md) — risultati stress test su 130 scenari

---

## License

MIT — usabile commercialmente, attribuzione apprezzata.

## Credits

DO Web Analytics / Tag Manager Italia
