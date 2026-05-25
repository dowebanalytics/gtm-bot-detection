# Setup Guide — GTM Bot Detection

## Prerequisiti

- Google Tag Manager Web container
- Diritti di editing sul container
- Possibilità di pubblicare (Publish)

---

## Step 1 — DOM Helper (Custom HTML Tag)

1. **GTM → Tags → New**
2. Nome: `Bot Detection DOM Helper`
3. Tag type: **Custom HTML**
4. Incolla l'intero contenuto di `dom-helper/bot-detection-dom-helper.html`
5. Triggering: **Initialization**
6. Advanced Settings → Tag firing priority: **100**
7. Salva

### Perché Initialization + priorità 100

Con questa configurazione i flag `_bd*` sono disponibili **prima** del Page View (`gtm.js`). La variabile `{{Bot Detection Result}}` può quindi essere usata su qualsiasi trigger GTM — `All Pages`, `Page View`, `DOM Ready`, custom events — senza configurare Tag Sequencing su ogni singolo tag.

### Flusso eventi GTM

```
1. consent_initialization
2. initialization           ← DOM Helper fira qui (priority 100)
3. gtm.js / pageview        ← variabile già disponibile
4. gtm.dom / DOM Ready
5. gtm.load / Window Loaded
6. eventi utente (click, scroll, form submit, custom events)
```

### Configurazione parametri

In cima al codice del DOM Helper:

```js
S.threshold = 5;     // 3=aggressiva | 5=default | 7=conservativa
S.debug     = false; // true = log [BotDetect] in console
```

---

## Step 2 — Template Variable

1. **GTM → Templates → New (Variable)**
2. Menu ⋮ → **Import**
3. Seleziona `templates/variable-result/bot-detection-result.tpl`
4. Al popup **"Permission changes detected"** clicca **Approve all**
5. Salva

> ⚠️ Se manca il passaggio "Approve all", la variabile darà errore `Prohibited read on global variable: _bd*`.

---

## Step 3 — Variabile Result

1. **GTM → Variables → New**
2. Nome: `Bot Detection Result`
3. Variable type: **Custom Template** → seleziona `Bot Detection Result`
4. Salva

---

## Step 4 — Variabili CJS helper

Crea tre variabili **Custom JavaScript**:

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

`{{Bot Detection Result}}` ricalcola ogni volta che viene chiamata (nessuna cache interna): ogni variabile CJS porta il valore aggiornato al momento del firing del tag che la legge.

---

## Step 5 — Propagazione su tutti gli eventi

### 5A — GA4 Configuration Parameters (event-scoped, consigliata)

I parametri impostati sul tag GA4 Configuration vengono ereditati automaticamente da tutti i GA4 Event tag che referenziano quel config. Nessuna modifica ai singoli tag.

**Tag GA4 Configuration → Configuration Parameters:**

| Parametro | Valore |
|---|---|
| `bot_status` | `{{Bot - Status}}` |
| `bot_score` | `{{Bot - Score}}` |
| `bot_signals` | `{{Bot - Signals}}` |

In GA4 → Admin → Custom Definitions → **Event-scoped** → registra `bot_status`, `bot_score`, `bot_signals`.

> ℹ️ **User-scoped vs Event-scoped.** Se preferisci che il bot status sia una proprietà utente (persiste all'intera sessione GA4 invece che al singolo evento), usa la sezione **User Properties** dello stesso tag GA4 Configuration invece di Configuration Parameters. La scelta dipende da come vuoi interrogare i dati in GA4 — non cambia nulla in GTM.

### 5B — Blocking trigger per conversion tag

Crea un exception trigger da applicare ai tag che non devono sparare se l'utente è un bot (Google Ads, Meta Pixel, Microsoft UET, TikTok, GA4 purchase/lead).

**Triggers → New → Custom Event:**

```
Nome:               [BD] Possible Bot - Block
Tipo:               Custom Event
Event name:         .*
Use regex:          ✓
Condizione:         {{Bot - Status}}  equals  possible_bot
```

Aggiungi questo trigger come **eccezione** (blocco) su ogni tag conversion.

### 5C — Tag Sequencing sui tag critici (belt-and-suspenders)

Per i tag dove un falso positivo ha costo elevato (conversion billing, fraud detection):

1. Apri il tag critico (es. GA4 Event "purchase")
2. **Advanced Settings → Tag Sequencing**
3. Spunta **Fire a tag before [Tag] fires**
4. Setup Tag: `Bot Detection DOM Helper`
5. Spunta **Don't fire [Tag] if [Setup Tag] fails or is paused**
6. Salva

La guard interna `_bdHelperLoaded` rende il re-firing idempotente: se il DOM Helper è già girato (scenario normale), l'esecuzione è un no-op. Nessuna penalità di performance.

### Matrice: quale strategia usare

| Tag | Strategia consigliata |
|---|---|
| GA4 Event generici (scroll, click, page_view) | **5A** — ereditano dal config tag |
| GA4 Event conversion (purchase, generate_lead, sign_up) | **5A + 5B + 5C** |
| Google Ads Conversion | **5B** |
| Meta Pixel (PageView + eventi) | **5B** |
| Microsoft UET / TikTok Pixel | **5B** |
| Tag fraud detection / anti-abuse | **5B + 5C** |

### Schema completo

```
Initialization (priority 100)
  └─ Bot Detection DOM Helper
       └─ setta _bd* flags (read-only) + guard _bdHelperLoaded

gtm.js / Page View
  └─ GA4 Configuration
       └─ Configuration Parameter: bot_status  = {{Bot - Status}}
       └─ Configuration Parameter: bot_score   = {{Bot - Score}}
       └─ Configuration Parameter: bot_signals = {{Bot - Signals}}
            ↓ ereditato da TUTTI i GA4 Event tag

Ogni evento (click / scroll / form / custom)
  └─ GA4 Event tag       → porta bot_* automaticamente (5A)
  └─ Tag Ads Conversion  → bloccato da [BD] Possible Bot - Block (5B)
  └─ Tag Meta Pixel      → bloccato da [BD] Possible Bot - Block (5B)
  └─ GA4 purchase        → 5A + 5B + Tag Sequencing (5C)
```

---

## Step 6 — Pubblicazione

1. **Submit**
2. Descrizione versione
3. **Publish**

---

## Step 7 — Verifica

Attiva Preview. Con `S.debug = true` in console:

```
[BotDetect v4] score=3 threshold=5 | status=normal_user | signals=
```

Verifica che **al momento del Page View** siano presenti:

- `window._bdInit === true`
- `window._bdHelperLoaded === true`
- `window._bdLiveCheckPassed === true`

Verifica in **Variables** → `Bot Detection Result`:
```json
{ "status": "normal_user", "score": 3, "signals": "" }
```

Score 3 su Page View è atteso e corretto (noMouseMove +2, noScroll +1).

---

## Affidabilità dei segnali per trigger

| Trigger | Affidabilità | Note |
|---|---|---|
| Custom Event / Add to Cart / Click CTA | **Massima** | Tutti i segnali popolati |
| Form Submit | **Massima** | L'utente ha interagito |
| Scroll Depth ≥ 25% | **Alta** | Scroll attivo, mouse spesso attivo |
| Timer 5000ms | **Buona** | L'utente potrebbe aver interagito |
| Page View / All Pages / Initialization | **Buona** | Fingerprint completo, ma `noMouseMove (+2)` e `noScroll (+1)` sempre attivi → score base **+3** |

### Score base +3 su Page View

Su Page View i listener mouse/scroll non hanno ancora avuto tempo di catturare interazioni, quindi `noMouseMove` e `noScroll` sono sempre attivi. Con soglia default 5:

- Utente reale con fingerprint pulito → score 3 → USER ✅
- Bot con un segnale aggiuntivo → score 5 → BOT ✅
- Bot stealth con fingerprint perfetto → score 3 → USER ⚠️ (limite teorico)

Per i siti dove la detection su Page View è critica, considera di valutare la variabile anche su un evento utente successivo (es. Add to Cart), dove i segnali comportamentali sono pieni.

---

## Troubleshooting

### "Prohibited read on global variable: _bd*"

Le permission non sono state approvate al momento dell'import del template.

1. Elimina il template variable
2. Re-importa il file `.tpl`
3. Al popup permissions, clicca **Approve all**
4. Riassocia la variabile `Bot Detection Result`

### "Variabile sempre possible_bot"

Attiva `S.debug = true` e controlla `signals` in console. Se contiene `nmm|ns` come unici segnali sopra soglia:

- Sposta la valutazione su un evento utente (Form Submit, Click)
- Oppure alza la soglia a 6 per ridurre i falsi positivi

### "Variabile sempre normal_user anche per bot evidenti"

Il DOM Helper potrebbe non essere su Initialization.

1. Console: `window._bdHelperLoaded` deve essere `true` al Page View
2. Se è `undefined` al Page View ma `true` successivamente, il DOM Helper è su DOM Ready
3. Sposta il trigger su **Initialization** con **priorità 100**

### "bot_status non arriva in GA4"

Verifica che:

1. Le variabili CJS `{{Bot - Status}}` ecc. siano create correttamente
2. Il tag GA4 Configuration abbia i parametri in **Configuration Parameters** (non in Event Parameters)
3. In GA4 → Custom Definitions le dimensioni siano registrate come **Event-scoped**
4. Attendi 24–48h dal primo hit per la disponibilità nei report

### Tag Sequencing non funziona

- Il setup tag deve essere un **Custom HTML** (non un Custom Template)
- Spunta sempre **Don't fire [Tag] if [Setup Tag] fails or is paused**
- Il setup tag eredita il trigger del tag principale, non quello configurato sul setup tag stesso
- In Preview verifica la timeline: il Setup Tag deve apparire **prima** del Main Tag
