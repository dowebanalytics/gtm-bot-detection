# Setup Guide — GTM Bot Detection

## Prerequisiti
- Google Tag Manager Web container
- Diritti di editing sul container
- Possibilità di pubblicare (Publish)

## Step 1 — DOM Helper (Custom HTML Tag)

1. **GTM → Tags → New**
2. Nome: `Bot Detection DOM Helper`
3. Tag type: **Custom HTML**
4. Incolla l'intero contenuto di `dom-helper/bot-detection-dom-helper.html` nel campo HTML
5. Triggering: **Initialization** ⚠️
6. Advanced Settings → Tag firing priority: **100**
7. Salva

### Perché Initialization e non DOM Ready

Con DOM Helper su `Initialization + priorità 100`:
- I flag `_bd*` sono disponibili **prima** del Page View (gtm.js)
- La variabile `{{Bot Detection Result}}` può essere usata su qualsiasi trigger GTM
- Non serve configurare Tag Sequencing su ogni tag
- Compatibile con tag che firano su `All Pages` / `Page View` / `Initialization`

### Configurazione

In cima al codice del DOM Helper, modificabile:

```js
S.threshold = 5;     // 3=aggressiva | 5=default | 7=conservativa
S.debug     = false; // true = log [BotDetect] in console
```

## Step 2 — Template Variable

1. **GTM → Templates → New (Variable)**
2. Menu ⋮ → **Import**
3. Seleziona `templates/variable-result/bot-detection-result.tpl`
4. Al popup **"Permission changes detected"** clicca **Approve all**
5. Salva

⚠️ Importante: se manca il passaggio "Approve all", lo script darà errore `Prohibited read on global variable: _bd*` durante l'esecuzione.

## Step 3 — Variabile

1. **GTM → Variables → New**
2. Nome: `Bot Detection Result`
3. Variable type: **Custom Template** → seleziona `BOT Detection result`
4. Salva

## Step 4 — Tag Sequencing sui tag critici (opzionale)

Con il DOM Helper su `Initialization + priorità 100`, la variabile è già disponibile per qualsiasi tag. Il Tag Sequencing è opzionale ma raccomandato come belt-and-suspenders sui tag critici.

### Quando aggiungere Tag Sequencing

| Caso d'uso | Serve Tag Sequencing? |
|---|---|
| Tag standard (Page View, Click, Form Submit, Scroll, Timer) | ❌ No — Initialization + priorità 100 sufficiente |
| Conversion GA4 (purchase, sign_up, generate_lead) | ✅ Raccomandata (belt-and-suspenders) |
| Form Submit lead generation B2B/enterprise | ✅ Raccomandata |
| Checkout / payment tag | ✅ Raccomandata |
| Fraud detection / anti-abuse | ✅ Raccomandata |

### Procedura

1. Apri il tag dipendente (es. GA4 Event "purchase")
2. **Advanced Settings → Tag Sequencing**
3. Spunta **Fire a tag before [Tag Name] fires**
4. **Setup Tag**: seleziona `Bot Detection DOM Helper`
5. Spunta **Don't fire [Tag Name] if [Bot Detection DOM Helper] fails or is paused**
6. Salva il tag

La guard interna `_bdHelperLoaded` rende il setup idempotente: anche se invocato più volte, l'inizializzazione completa avviene solo al primo passaggio. Nessuna penalità di performance.

### Esempio: GA4 Purchase con bot filtering

```
Tag: GA4 Event - Purchase
├── Trigger: Custom Event "purchase"
├── Event Parameters: ...
└── Advanced Settings
    ├── Tag firing priority: (vuoto, default)
    ├── Tag Sequencing
    │   └── Fire a tag before this tag fires:
    │       └── Setup Tag: Bot Detection DOM Helper
    │           └── ☑ Don't fire if setup tag fails
    └── Trigger condition: {{Bot - Status}} EQUALS "normal_user"
```

## Step 5 — Pubblicazione

1. **Submit**
2. Aggiungi descrizione versione
3. **Publish**

## Step 6 — Verifica

Apri il sito con Tag Assistant attivo. Nella console (con `_bdDebug = true`):

```
[BotDetect v4] score=3 threshold=5 | status=normal_user | signals=
```

Verifica che siano presenti in `window` **già al momento del Page View**:
- `_bdInit = true`
- `_bdHelperLoaded = true`
- `_bdLiveCheckPassed = true`
- `_bdThreshold = 5`
- Tutti i `_bd*` flag

## Uso della variabile

La variabile restituisce un oggetto con tre proprietà:

```js
// utente normale
{ status: "normal_user", score: 0, signals: "" }

// bot rilevato
{ status: "possible_bot", score: 12, signals: "tmp|wdt|dh0|np|nmm|ns" }
```

### Variabili CJS per estrarre i singoli valori

Crea tre variabili **Custom JavaScript** in GTM:

```js
// Bot - Status
function() {
  var r = {{Bot Detection Result}};
  return r ? r.status : 'normal_user';
}

// Bot - Score
function() {
  var r = {{Bot Detection Result}};
  return r ? r.score : 0;
}

// Bot - Signals
function() {
  var r = {{Bot Detection Result}};
  return r ? r.signals : '';
}
```

### Custom Dimensions GA4

Nella Event Settings variable mappa:

| Parametro GA4 | Variabile GTM |
|---|---|
| `bot_status` | `{{Bot - Status}}` |
| `bot_score` | `{{Bot - Score}}` |
| `bot_signals` | `{{Bot - Signals}}` |

### Trigger condition

Per bloccare i bot su tag critici usa `{{Bot - Status}}`:

```
Trigger condition: {{Bot - Status}} EQUALS "normal_user"
```

## Trigger e affidabilità dei segnali

| Trigger | Affidabilità detection |
|---|---|
| Custom Event / Add to Cart / Click CTA | **Massima** — tutti i segnali popolati incluso quelli comportamentali |
| Form Submit | **Massima** — utente ha interagito |
| Scroll Depth ≥ 25% | **Alta** — scroll attivo, mouse spesso attivo |
| Timer 5000ms | **Buona** — l'utente potrebbe aver interagito |
| Page View / All Pages / Initialization | **Buona** — segnali fingerprint completi ma `noMouseMove (+2)` e `noScroll (+1)` sempre attivi |

### Limite su Page View

Su Page View i segnali comportamentali sono inattivi (l'utente non ha ancora avuto tempo di interagire), quindi ogni utente parte con **+3 di base**. Con soglia default 5:
- Utente reale con fingerprint pulito → score 3 → USER ✅
- Bot con un solo segnale aggiuntivo → score 5 → BOT ✅
- Bot stealth con fingerprint perfetto → score 3 → USER ⚠️ (limite teorico)

Per detection più aggressiva su Page View, valuta:
- Abbassare la soglia a 4 (più falsi positivi possibili)
- Oppure valutare la variabile **anche** su un evento utente successivo (es. Add to Cart)

## Troubleshooting

### "Prohibited read on global variable: _bd*"
Le permission non sono state approvate al re-import. Soluzione:
1. Elimina il template variable
2. Re-importa il file `.tpl`
3. Al popup permissions, clicca **Approve all**
4. Riassocia la variabile

### "Variabile sempre possible_bot"
Verifica con `_bdDebug = true` quali segnali si attivano. Se `signals` contiene `nmm|ns` + altri sopra soglia, considera:
- Spostare il trigger di valutazione su un evento utente (Form Submit, Click)
- Oppure alzare la soglia a 6

### "Variabile sempre normal_user anche per bot evidenti"
Il DOM Helper potrebbe non essere su Initialization. Verifica:
1. Console: `window._bdHelperLoaded` deve essere `true` già al Page View
2. Se è `undefined` al Page View ma `true` dopo, il DOM Helper è su DOM Ready
3. Sposta il trigger del DOM Helper su **Initialization** con **priorità 100**

### Tag Assistant mostra errori
Pubblica il container — gli errori in modalità Preview possono dipendere da permission non ancora salvate.

### Tag Sequencing non funziona
Verifica:
- Il setup tag deve essere un Custom HTML (non un template) per essere usabile come setup
- Spunta sempre **Don't fire [Tag] if [Setup Tag] fails or is paused**
- Il setup tag eredita il trigger del tag principale, non quello configurato sul setup tag stesso
- In Preview mode controlla la timeline: il Setup Tag deve apparire prima del Main Tag
