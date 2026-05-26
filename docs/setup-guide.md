# Setup Guide — GTM Bot Detection

## Prerequisiti

- Google Tag Manager Web container
- Diritti di editing sul container (Editor o Publisher)
- Possibilità di pubblicare (Publisher)
- Per l'analisi dati: export GA4 → BigQuery attivo

---

## Panoramica del flusso di setup

```
Step 1 → Importa DOM Helper (Custom HTML Tag)
Step 2 → Importa Template Variable (.tpl)
Step 3 → Crea variabile Bot Detection Result
Step 4 → Crea variabili scalari (Status / Score / Signals)
Step 5 → Configura propagazione (GA4 Config + Blocking trigger)
Step 6 → (Opzionale) Configura server-side GTM
Step 7 → Verifica in Preview
Step 8 → Pubblica
Step 9 → (Opzionale) Analisi BigQuery
```

---

## Step 1 — DOM Helper (Custom HTML Tag)

1. **GTM → Tags → New**
2. Nome: `Bot Detection DOM Helper`
3. Tag type: **Custom HTML**
4. Incolla l'intero contenuto di `dom-helper/bot-detection-dom-helper.html`
5. Triggering: **Initialization**
6. **Advanced Settings → Tag firing priority: `100`**
7. Salva

### Perché Initialization con priority 100

GTM processa gli eventi in questo ordine:

```
1. consent_initialization   → CMP, Consent Mode
2. initialization           ← DOM Helper qui (priority 100)
3. gtm.js / pageview        ← variabile già disponibile
4. gtm.dom / DOM Ready
5. gtm.load / Window Loaded
6. eventi utente (click, scroll, form submit, custom events)
```

Con Initialization + priority 100 i flag `_bd*` sono scritti **prima** del primo Page View. La variabile `{{Bot Detection Result}}` è disponibile su qualsiasi trigger successivo senza dover configurare Tag Sequencing su ogni tag.

> ⚠️ Se il DOM Helper è su DOM Ready o Page View, i parametri `bot_status` / `bot_score` / `bot_signals` del tag GA4 Configuration risulteranno vuoti o `undefined` per il primo evento.

### Parametri configurabili

In cima al codice del DOM Helper:

```js
S.threshold = 5;     // 3=aggressiva | 5=default | 7=conservativa
S.debug     = false; // true = log [BotDetect v4] in console
```

Con `S.debug = true`, in console appare:
```
[BotDetect v4] score=3 threshold=5 | status=normal_user | signals=
[BotDetect v4] score=18 threshold=5 | status=possible_bot | signals=tmp|wdt|dh0|np|nmm|ns
```

---

## Step 2 — Template Variable

1. **GTM → Templates → New (Variable)**
2. Menu ⋮ → **Import**
3. Seleziona `templates/variable-result/bot-detection-result.tpl`
4. Al popup **"Permission changes detected"** clicca **Approve all**
5. Salva

> ⚠️ Se salvi senza cliccare "Approve all", le `readFromDataLayer` e `copyFromWindow` vengono negate. La variabile restituirà `undefined` o l'errore `Prohibited read on global variable: _bd*`.

---

## Step 3 — Variabile Bot Detection Result

1. **GTM → Variables → New**
2. Nome: `Bot Detection Result`
3. Variable type: **Custom Template** → seleziona `Bot Detection Result`
4. **Output**: scegli in base all'utilizzo

| Output | Tipo | Quando usarlo |
|---|---|---|
| `Full object { status, score, signals }` | Object | Solo per logica lato client JS, mai come parametro GA4 |
| `status` | String | Condizioni trigger, GA4 event parameter, sGTM |
| `score` | Number | Custom dimension numerica GA4, soglie custom |
| `signals` | String | Debug, dimensioni GA4, BigQuery |

5. Salva

> ⚠️ Non passare mai l'oggetto completo come parametro GA4 o server-side GTM: viene serializzato come `[object Object]`. Usa le variabili scalari separate (Step 4).

---

## Step 4 — Variabili scalari

Crea tre variabili separata con lo stesso template (output diverso), oppure usa le Custom JavaScript equivalenti.

### Opzione A — tre variabili Custom Template (consigliata)

Ripeti Step 3 tre volte con nomi e output diversi:

| Nome variabile | Output selezionato |
|---|---|
| `Bot Detection - Status` | `status` |
| `Bot Detection - Score` | `score` |
| `Bot Detection - Signals` | `signals` |

### Opzione B — Custom JavaScript (compatibilità universale)

```js
// Bot Detection - Status
function() {
  var r = {{Bot Detection Result}};
  return (r && r.status) ? r.status : 'normal_user';
}

// Bot Detection - Score
function() {
  var r = {{Bot Detection Result}};
  return (r && typeof r.score !== 'undefined') ? r.score : 0;
}

// Bot Detection - Signals
function() {
  var r = {{Bot Detection Result}};
  return (r && r.signals) ? r.signals : undefined;
}
```

> Con l'Opzione B, `{{Bot Detection Result}}` deve avere Output = `Full object`.

---

## Step 5 — Propagazione su tutti gli eventi

Il DOM Helper scrive i flag `_bd*` una volta sola (Initialization). La variabile è live e ricalcola ad ogni chiamata. Esistono tre strategie complementari.

### Strategia A — GA4 Configuration Parameters *(consigliata)*

I parametri sul tag GA4 Configuration vengono ereditati automaticamente da **tutti** i GA4 Event tag che referenziano quel config. Zero modifiche ai singoli tag evento.

**Tag GA4 Configuration → Configuration Parameters:**

| Nome parametro | Valore variabile |
|---|---|
| `bot_status` | `{{Bot Detection - Status}}` |
| `bot_score` | `{{Bot Detection - Score}}` |
| `bot_signals` | `{{Bot Detection - Signals}}` |

**GA4 → Admin → Custom Definitions → New Custom Dimension:**

| Dimension name | Scope | Event parameter |
|---|---|---|
| Bot Status | Event | `bot_status` |
| Bot Score | Event | `bot_score` |
| Bot Signals | Event | `bot_signals` |

> ℹ️ **User-scoped vs Event-scoped.** Se vuoi che `bot_status` persista all'intera sessione GA4 come proprietà utente, usa la sezione **User Properties** dello stesso tag GA4 Configuration invece di Configuration Parameters. Non cambia nulla in GTM.

### Strategia B — Blocking trigger universale

Crea un exception trigger che blocca i tag conversion quando viene rilevato un bot.

**GTM → Triggers → New:**

```
Nome:                [BD] Possible Bot - Block
Tipo:                Custom Event
Event name:          .*
Use regex matching:  ✓
Condizione:          {{Bot Detection - Status}}  equals  possible_bot
```

Aggiungi questo trigger come **eccezione** su ogni tag conversion:
- Google Ads Conversion
- Meta Pixel (PageView + eventi)
- Microsoft UET
- TikTok Pixel
- GA4 Event "purchase", "generate_lead", "sign_up", "form_submit"

### Strategia C — Tag Sequencing sui tag critici

Per tag dove un falso positivo ha costo elevato (conversion billing, fraud detection).

1. Apri il tag critico (es. GA4 Event "purchase")
2. **Advanced Settings → Tag Sequencing**
3. ✅ **Fire a tag before [Tag] fires**
4. Setup Tag: `Bot Detection DOM Helper`
5. ✅ **Don't fire [Tag] if [Setup Tag] fails or is paused**
6. Salva

La guard interna `_bdHelperLoaded` rende il re-firing idempotente: se il DOM Helper è già girato (scenario normale con Initialization), il secondo firing è un no-op. Zero penalità di performance.

### Matrice strategia per tipo di tag

| Tag | Strategia |
|---|---|
| GA4 Event generici (scroll, click, page_view, video) | **A** — eredita dal config |
| GA4 Event conversion (purchase, generate_lead, sign_up) | **A + B + C** |
| Google Ads Conversion | **B** |
| Meta Pixel (tutti gli eventi) | **B** |
| Microsoft UET / TikTok Pixel / LinkedIn Insight | **B** |
| Tag fraud detection, loyalty, personalizzazione | **B + C** |

### Schema completo

```
Initialization (priority 100)
  └─ Bot Detection DOM Helper
       └─ scrive _bd* flags (read-only via Object.defineProperty)
       └─ setta _bdHelperLoaded = true

gtm.js / Page View
  └─ GA4 Configuration
       ├─ bot_status  = {{Bot Detection - Status}}
       ├─ bot_score   = {{Bot Detection - Score}}
       └─ bot_signals = {{Bot Detection - Signals}}
            ↓ ereditato automaticamente da TUTTI i GA4 Event tag

Ogni evento (click / scroll / form / ecommerce / custom)
  ├─ GA4 Event tag          → porta bot_* (Strategia A)
  ├─ Google Ads Conversion  → bloccato se bot (Strategia B)
  ├─ Meta Pixel             → bloccato se bot (Strategia B)
  └─ GA4 "purchase"         → A + B + Tag Sequencing (Strategia C)
```

---

## Step 6 — Server-Side GTM (opzionale)

Se utilizzi un container server-side GTM, le variabili scalari arrivano come event parameter e sono immediatamente disponibili nei tag e nelle variabili del container server.

### Setup lato client (web container)

Assicurati che i tre parametri siano impostati nel tag GA4 Configuration come da Step 5A. Non inviare l'oggetto completo (`Full object`) — viene ricevuto come `[object Object]` lato server.

### Lettura lato server (sGTM)

Nel container server, crea tre **Event Data Variables**:

| Nome variabile sGTM | Chiave event data |
|---|---|
| `Bot Status` | `bot_status` |
| `Bot Score` | `bot_score` |
| `Bot Signals` | `bot_signals` |

### Utilizzi tipici in sGTM

**Blocco tag server:**  
Aggiungi una condizione di firing sul tag server:
```
bot_status  does not equal  possible_bot
```

**Arricchimento evento:**  
Usa `bot_status` in Custom Template per aggiungere header o metadata alla richiesta verso endpoint downstream.

**Trigger condition su conversion:**  
```
Event Name  equals       purchase
bot_status  equals       normal_user
bot_score   less than    5
```

---

## Step 7 — Verifica in Preview

### Checklist JavaScript console

Con `S.debug = true`, apri la console del browser e verifica:

```
[BotDetect v4] score=3 threshold=5 | status=normal_user | signals=
```

Verifica le variabili window:

```js
window._bdInit           // true
window._bdHelperLoaded   // true
window._bdLiveCheckPassed // true
window._bdThreshold      // 5
```

### Checklist GTM Preview → Variables

Al momento del Page View la variabile `Bot Detection Result` deve mostrare:
```json
{ "status": "normal_user", "score": 3, "signals": "" }
```

Score 3 su Page View è **atteso e corretto** (`nmm` +2, `ns` +1 — nessuna interazione ancora).

### Test con bot simulato

Crea un tag **Custom HTML** temporaneo:

```html
<script>
  window._bdInit            = true;
  window._bdWebdriver       = true;   // +5
  window._bdLiveCheckPassed = false;  // +5
  window._bdPluginsLen      = 0;      // +2
  window._bdMouseMoved      = false;  // +2
  window._bdScrolled        = false;  // +1
  window._bdScreenWidth     = 1920;
  window._bdScreenHeight    = 1080;
  window._bdBrowserWidth    = 1920;
  window._bdBrowserHeight   = 1080;   // deltaHeight <= 0 → +3
  window._bdThreshold       = 5;
  window._bdDebug           = true;
</script>
```

| Campo | Valore |
|---|---|
| Trigger | **Initialization** |
| Firing Priority | `999` (dopo il DOM Helper a 100) |
| Nome | `[DEBUG] Bot Detection Injector` |

**Risultato atteso:**
```json
{ "status": "possible_bot", "score": 18, "signals": "tmp|wdt|dh0|np|nmm|ns" }
```

> ⚠️ Rimuovi o disabilita questo tag prima di pubblicare in produzione.

---

## Step 8 — Pubblicazione

1. **Submit**
2. Compila la descrizione della versione (es. "Aggiunti tag Bot Detection")
3. **Publish**

---

## Step 9 — Analisi BigQuery (opzionale)

Dopo aver accumulato dati sufficienti (almeno 7 giorni), usa le query in [`docs/bigquery-analysis.sql`](bigquery-analysis.sql) per analizzare il traffico bot.

Modifica in ogni query:
- `your_project.your_dataset` → il tuo progetto e dataset BigQuery
- Le date `20250101` / `20251231` → il range desiderato
- Query 7: aggiungi/rimuovi gli `event_name` che hai come conversion

---

## Affidabilità dei segnali per tipo di trigger

| Trigger | Affidabilità | Note |
|---|---|---|
| Custom Event, Add to Cart, Click CTA | **Massima** | Tutti i 26 segnali disponibili |
| Form Submit | **Massima** | Interazione utente confermata |
| Scroll Depth ≥ 25% | **Alta** | Scroll attivo, mouse spesso attivo |
| Timer 5000ms | **Buona** | L'utente potrebbe aver interagito |
| Page View / All Pages | **Buona** | Fingerprint completo, ma `nmm` (+2) e `ns` (+1) sempre attivi |

### Score base +3 su Page View — perché è normale

Al momento del Page View i listener mouse/scroll non hanno ancora ricevuto input reali. `noMouseMove` e `noScroll` sono sempre attivi. Con soglia default 5:

- Utente reale, fingerprint pulito → score **3** → `normal_user` ✅
- Bot con un segnale aggiuntivo → score **5** → `possible_bot` ✅  
- Bot stealth con fingerprint identico a utente reale → score **3** → `normal_user` ⚠️ (limite fisiologico del client-side)

Per siti dove la detection su Page View è critica, valuta la variabile anche su un evento utente successivo (es. Add to Cart, Form Submit), dove i segnali comportamentali sono pieni.

---

## Troubleshooting

### "Prohibited read on global variable: _bd*"

Le permission del template non sono state approvate.

1. **Templates** → elimina il template `Bot Detection Result`
2. **Templates → New → Import** → reimporta il `.tpl`
3. Al popup permissions → **Approve all**
4. Riassocia la variabile `Bot Detection Result`

---

### "La variabile restituisce sempre `possible_bot`"

Attiva `S.debug = true` e controlla il campo `signals` nel log.

**Se `signals` contiene solo `nmm|ns`** (score ≤ 3):  
La soglia è troppo bassa. Alzala a 6.

**Se `signals` contiene segnali fingerprint (`np`, `cd16`, `nwgl`):**  
Potrebbe essere un browser privacy (Brave, Firefox Strict, Tor). Analizza il profilo device prima di alzare la soglia.

**Se `signals` contiene `dh0` su Smart TV / console gaming:**  
Aggiungi una condizione al blocking trigger per escludere questi device, oppure alza la soglia a 7.

---

### "La variabile restituisce sempre `normal_user` anche per bot evidenti"

Il DOM Helper non gira su Initialization.

1. Apri la console: `window._bdHelperLoaded` deve essere `true` **al Page View**
2. Se è `undefined` al Page View ma `true` successivamente → il DOM Helper è su DOM Ready
3. **Modifica il trigger a Initialization con priority 100**

---

### "bot_status non arriva in GA4 / DebugView"

Verifica in ordine:

1. Le variabili scalari `{{Bot Detection - Status}}` esistono e restituiscono un valore
2. Il tag GA4 Configuration ha i parametri in **Configuration Parameters** (non Event Parameters)
3. In DebugView vedi l'evento `page_view` → espandi → `bot_status` deve essere presente
4. In GA4 → Custom Definitions le dimensioni sono registrate come **Event-scoped**
5. Attendi 24–48h per la propagazione nei report standard

---

### "In server-side GTM ricevo `[object Object]`"

Stai passando la variabile con Output = `Full object` come parametro GA4.

**Soluzione:** usa le variabili scalari separate (una per `status`, una per `score`, una per `signals`) e mappale come tre parametri distinti nel tag GA4 Configuration.

---

### "Tag Sequencing non funziona"

- Il setup tag deve essere un **Custom HTML** (non un Custom Template)
- ✅ Spunta **Don't fire [Tag] if [Setup Tag] fails or is paused**
- Il setup tag eredita il trigger del tag principale, non il suo proprio
- In Preview → verifica la timeline: il Setup Tag deve comparire **prima** del Main Tag

---

### "Score diverso tra Page View e eventi successivi"

Comportamento **atteso**. `noMouseMove` e `noScroll` cambiano da `true` a `false` dopo la prima interazione. Lo score scende di 3 punti dopo il primo mouse move + scroll. Se stai usando la variabile su Page View per la detection, considera questo offset nel dimensionamento della soglia.
