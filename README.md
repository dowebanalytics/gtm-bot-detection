# GTM Bot Detection

Sistema di rilevamento bot per **Google Tag Manager** basato su 26 segnali a punteggio multi-dimensionale: fingerprint del browser, ambiente di rendering, comportamento utente, anti-tampering attivo e rilevamento eventi sintetici.

Sviluppato da [DO Web Analytics](https://dowebanalytics.com) / [Tag Manager Italia](https://tagmanageritalia.it).

---

## Caratteristiche principali

| Caratteristica | Descrizione |
|---|---|
| **Closure namespace + `Object.defineProperty` read-only** | I flag `_bd*` sono immutabili: bot non può sovrascriverli, eliminarli o ridefinirli |
| **`event.isTrusted` filter** su mouse/scroll | Eventi sintetici creati via `dispatchEvent` rilevati e contati come segnali |
| **Integrity check live** | Tampering post-init di `navigator.userAgent`, `screen.width`, `navigator.webdriver` rilevato (+5) |
| **Mouse entropy** | Movimenti robotici (linee dritte, timing uniforme) identificati (+2) |
| **First-mouse-delay** | Eventi mouse iniettati < 50ms dopo init rilevati (+2) |
| **Compatibilità sandbox GTM** | Nessun `try/catch`, nessuna API non-sandboxed, nessuna regex, permission dichiarate |
| **Output configurabile** | La variabile restituisce oggetto completo, `status`, `score` o `signals` a scelta |
| **Zero falsi positivi** | Testato su 20+ scenari di utenti reali (browser mainstream, mobile, in-app WebView, device anomali) |

---

## Struttura del repository

```
gtm-bot-detection/
├── dom-helper/
│   └── bot-detection-dom-helper.html       # Custom HTML Tag GTM
├── templates/
│   └── variable-result/
│       └── bot-detection-result.tpl        # Custom Template Variable GTM
└── docs/
    ├── setup-guide.md                       # Guida installazione GTM completa
    ├── signals.md                           # Catalogo 26 segnali con esempi
    ├── test-results.md                      # Stress test 130 scenari
    └── bigquery-analysis.sql               # 12 query BigQuery per analisi bot
```

---

## Componenti GTM

| File | Tipo GTM | Funzione |
|---|---|---|
| `dom-helper/bot-detection-dom-helper.html` | Custom HTML Tag | Cattura fingerprint, listener comportamentali, anti-tampering. Si esegue su **Initialization** (priority 100). |
| `templates/variable-result/bot-detection-result.tpl` | Custom Template Variable | Legge i flag `_bd*` e calcola score. Restituisce oggetto, status, score o signals in base al parametro **Output**. |

---

## Quick Start

### 1. DOM Helper

**Tags → New → Custom HTML** → incolla `dom-helper/bot-detection-dom-helper.html`  
Trigger: **Initialization** — Priority: **100** — Salva.

Parametri configurabili in cima al file:

```js
S.threshold = 5;     // 3=aggressiva | 5=default | 7=conservativa
S.debug     = false; // true = log [BotDetect v4] in console
```

> ⚠️ **Il trigger Initialization è obbligatorio.** Con DOM Ready o Page View i flag `_bd*` non sono disponibili al momento del primo evento GA4, causando una detection incompleta o assente.

### 2. Template Variable

**Templates → New → Import** → seleziona `bot-detection-result.tpl`  
Al popup **"Permission changes detected"** → **Approve all** → Salva.

### 3. Variabile Result

**Variables → New → Custom Template** → seleziona `Bot Detection Result` → Salva.

Scegli il campo **Output** in base all'utilizzo:

| Output | Tipo restituito | Quando usarlo |
|---|---|---|
| `Full object { status, score, signals }` | Object | Variabile unica lato client JS |
| `status` | String | Trigger condition, blocco tag, sGTM |
| `score` | Number | Custom dimension GA4, soglie custom |
| `signals` | String | Debug, dimensioni GA4, BigQuery |

> ⚠️ Per **server-side GTM** o **GA4 event parameters** usa sempre le variabili scalari (`status`, `score`, `signals`), non l'oggetto completo. Un oggetto JS passato come parametro GA4 viene serializzato come `[object Object]`.

### 4. Propagazione su tutti gli eventi

Il modo consigliato è impostare i tre parametri nel tag **GA4 Configuration**:

```
Configuration Parameters:
  bot_status  →  {{Bot Detection - Status}}
  bot_score   →  {{Bot Detection - Score}}
  bot_signals →  {{Bot Detection - Signals}}
```

Tutti i GA4 Event tag che referenziano questo config ereditano automaticamente i parametri. Nessuna modifica ai singoli tag evento.

→ Vedi [`docs/setup-guide.md`](docs/setup-guide.md) per la guida completa con tutti gli step e le strategie di propagazione.

---

## Output della variabile

### Oggetto completo (default)

```json
{ "status": "possible_bot", "score": 18, "signals": "tmp|wdt|dh0|np|nmm|ns" }
{ "status": "normal_user",  "score": 0,  "signals": "" }
```

Quando `status = normal_user`, `score` è sempre `0` e `signals` è stringa vuota (o `undefined` nelle variabili scalari).

### Valori scalari

| Campo | Tipo | Valori possibili |
|---|---|---|
| `status` | String | `"possible_bot"` / `"normal_user"` |
| `score` | Number | 0–66 (tipicamente 0–25) |
| `signals` | String | Codici pipe-separated (`"wdt\|np\|nmm"`) o `undefined` |

→ Vedi [`docs/signals.md`](docs/signals.md) per il dizionario completo delle abbreviazioni.

---

## Soglie consigliate

| Soglia | Profilo | Trade-off |
|---|---|---|
| **3** | E-commerce sotto attacco, form spam massivo | Massima protezione, possibili FP su browser privacy |
| **5** *(default)* | Uso generale | Equilibrio ottimale |
| **6–7** | Pubblico tech/privacy, Tor, Smart TV, console gaming | Zero FP, perde qualche adversarial sofisticato |
| **10+** | Solo diagnostica, no blocco | Solo bot evidenti (crawler HTTP, Selenium puro) |

---

## I 26 segnali

### Riepilogo per categoria

| Categoria | Segnali | Score max |
|---|---|---|
| Browser identity | `wdt`, `sua`, `np`, `cm` | +14 |
| Display fingerprint | `dw0`, `dh0`, `cd16`, `dpr1`, `ada`, `munt`, `dumv` | +18 |
| GPU & Canvas | `ce`, `cb`, `sr`, `nwgl`, `we` | +10 |
| Internazionalizzazione | `nl`, `ltu` | +4 |
| Permessi | `nd` | +1 |
| Comportamento | `nmm`, `ns` | +3 |
| Anti-tampering & avanzati | `tmp`, `smN`, `ss`, `lmeN`, `mtfN` | +16 |

**Score base su Page View: +3** (`nmm` + `ns`) — atteso su ogni utente, non indica bot da solo.  
**Score massimo teorico: +66** — in pratica raramente si supera 20–25.

→ Vedi [`docs/signals.md`](docs/signals.md) per la descrizione completa di ogni segnale.

---

## Analisi in BigQuery

Il file [`docs/bigquery-analysis.sql`](docs/bigquery-analysis.sql) contiene **12 query** per analizzare il traffico bot sui dati GA4 esportati in BigQuery.

| Query | Obiettivo |
|---|---|
| 1 — KPI Overview | Split totale eventi/utenti/sessioni: umano vs bot |
| 2 — Trend giornaliero | Andamento bot% nel tempo |
| 3 — Distribuzione score | Frequenza per fascia di score |
| 4 — Analisi segnali | Frequenza di ciascun segnale con descrizione |
| 5 — Combinazioni segnali | Top fingerprint bot (pattern più frequenti) |
| 6 — Pagine più colpite | URL con maggior concentrazione di bot |
| 7 — Conversion inquinate | Bot su purchase, lead, checkout, form |
| 8 — Profilo device/OS/browser | Caratteristiche tecniche dei bot |
| 9 — Geo analysis | Distribuzione geografica del traffico bot |
| 10 — Sessioni bot | Timeline completa di una sessione sospetta |
| 11 — Impatto revenue | Revenue e transazioni attribuite ai bot |
| 12 — Indice di rischio segnale | Quale segnale è baseline vs fingerprint specifico |

Custom dimensions richieste: `bot_status`, `bot_score`, `bot_signal`.

→ Vedi [`docs/bigquery-analysis.sql`](docs/bigquery-analysis.sql) per le query complete.

---

## Risultati test

| Categoria | Detection rate |
|---|---|
| HTTP scrapers (curl, requests, axios, ecc.) | **100%** (16/16) |
| Crawler (Googlebot, GPTBot, ClaudeBot, ecc.) | **100%** (8/8) |
| CAPTCHA solvers (2Captcha, AntiCaptcha, ecc.) | **100%** (4/4) |
| Mobile farms (BrowserStack, Appium, ecc.) | **100%** (10/10) |
| Bot con eventi sintetici | ~62% |
| Bot con tampering | **100%** |
| Stealth tools avanzati | ~50% |
| **Utenti reali** | **0 falsi positivi (0/20)** |
| Resilienza anti-tampering | 8/8 attacchi bloccati |

→ Vedi [`docs/test-results.md`](docs/test-results.md) per il report completo su 130 scenari.

---

## Limiti documentati

Tre scenari **non rilevabili** lato client:

1. **Bot stealth perfetto senza interazione** — score 3 (solo `nmm` + `ns`), indistinguibile da utente che apre la pagina senza interagire
2. **Click farm umani reali** — non è automazione
3. **Account hijack** — browser legittimo, utente illegittimo

Per coprire questi casi è necessario un layer **server-side**: IP reputation (Cloudflare WAF, AWS WAF), rate limiting, fraud detection dedicato (Sift, DataDome, PerimeterX).

---

## Documentazione

| File | Contenuto |
|---|---|
| [`docs/setup-guide.md`](docs/setup-guide.md) | Installazione GTM step-by-step, strategie propagazione, troubleshooting |
| [`docs/signals.md`](docs/signals.md) | Catalogo completo 26 segnali, edge case, firme distintive |
| [`docs/test-results.md`](docs/test-results.md) | Stress test 130 scenari, top 10 bot, resilienza anti-tampering |
| [`docs/bigquery-analysis.sql`](docs/bigquery-analysis.sql) | 12 query BigQuery per analisi bot su schema GA4 |

---

## License

MIT — usabile commercialmente, attribuzione apprezzata.

## Credits

DO Web Analytics / Tag Manager Italia
