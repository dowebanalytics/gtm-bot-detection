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
5. Triggering: **DOM Ready** (built-in trigger)
6. Advanced Settings → Tag firing priority: **20**
7. Salva

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
3. Variable type: **Custom Template** → seleziona `Bot Detection Result`
4. Salva

## Step 4 — Tag Sequencing sui tag critici

Per i tag dove sbagliare è costoso, configura il DOM Helper come setup tag esplicito.

### Quando usare Tag Sequencing

| Caso d'uso | Serve Tag Sequencing? |
|---|---|
| Tag su Form Submit, Click, Scroll Depth, Timer | ❌ No — priorità 20 basta |
| Tag su DOM Ready (altri tag) | ❌ No — priorità 20 basta |
| Tag su **Page View / All Pages / Initialization** | ✅ **Obbligatoria** |
| Conversion GA4 (purchase, sign_up, generate_lead) | ✅ Raccomandata |
| Form Submit lead generation | ✅ Raccomandata |
| Checkout / payment tag | ✅ Raccomandata |
| Fraud detection / anti-abuse | ✅ Raccomandata |

### Procedura

1. Apri il tag dipendente (es. GA4 Event "purchase")
2. **Advanced Settings → Tag Sequencing**
3. Spunta **Fire a tag before [Tag Name] fires**
4. **Setup Tag**: seleziona `Bot Detection DOM Helper`
5. Spunta **Don't fire [Tag Name] if [Bot Detection DOM Helper] fails or is paused**
6. Salva

In questo modo GTM garantisce che il DOM Helper esegua sempre prima del tag, indipendentemente dal trigger configurato. La guard interna `_bdHelperLoaded` rende il setup idempotente: anche se invocato più volte (una per tag), si inizializza solo al primo passaggio.

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
    └── Trigger condition: {{Bot Detection Result}} EQUALS "normal user"
```

## Step 5 — Pubblicazione

1. **Submit**
2. Aggiungi descrizione versione
3. **Publish**

## Step 6 — Verifica

Apri il sito con Tag Assistant attivo. Nella console (con `_bdDebug = true`):

```
[BotDetect] score=3 threshold=5 | noM,noS | normal user
```

Verifica che siano presenti in `window`:
- `_bdInit = true`
- `_bdHelperLoaded = true`
- `_bdLiveCheckPassed = true`
- `_bdThreshold = 5`
- Tutti i `_bd*` flag

## Uso della variabile

Usa `{{Bot Detection Result}}` come condizione di trigger su tag che vuoi bloccare per i bot:

```
Trigger condition: {{Bot Detection Result}} EQUALS "normal user"
```

Oppure come custom dimension GA4 per analizzare il traffico bot:

```js
gtag('event', 'page_view', {
  bot_detection: {{Bot Detection Result}}
});
```

## Quando valutare la variabile

| Trigger | Quando usarlo |
|---|---|
| Form Submit | Lead gen, contatti, checkout |
| Click CTA / Add to Cart | E-commerce, landing page |
| Scroll Depth ≥ 25% | Blog, pagine editoriali |
| Timer 5000ms | Pagine senza interazioni |
| ❌ DOM Ready / Pageview | NON usare — segnali comportamentali non popolati |

Se devi valutare la variabile su Pageview, usa Tag Sequencing (Step 4) per garantire l'esecuzione del DOM Helper prima.

## Priorità vs Tag Sequencing — quando usare quale

| Tecnica | Cosa fa | Garanzia |
|---|---|---|
| **Priorità** (tag firing priority) | Ordina i tag con lo stesso trigger | Hint asincrono, best-effort |
| **Tag Sequencing** | Dipendenza esplicita setup → main tag | Garantita |

### Approccio raccomandato

- **Default**: priorità 20 sul DOM Helper. Sufficiente nel 95% dei casi.
- **Tag critici** (conversion, form submit, checkout): aggiungi Tag Sequencing come ulteriore garanzia.
- **Tag su Page View / Initialization**: Tag Sequencing obbligatoria.

La guard `_bdHelperLoaded` nel DOM Helper rende il setup idempotente: anche se viene invocato come setup tag su 10 tag diversi, l'inizializzazione completa avviene solo al primo passaggio. Non c'è penalità di performance nel usare Tag Sequencing su molti tag.

## Troubleshooting

### "Prohibited read on global variable: _bd*"
Le permission non sono state approvate al re-import. Soluzione:
1. Elimina il template variable
2. Re-importa il file `.tpl`
3. Al popup permissions, clicca **Approve all**
4. Riassocia la variabile

### "Variabile sempre 'possible bot'"
Verifica con `_bdDebug = true` quali segnali si attivano. Se è solo `noMouseMove,noScroll` significa che la variabile viene valutata troppo presto. Soluzioni:
1. Sposta il trigger su un evento utente (Form Submit, Click)
2. Oppure aggiungi Tag Sequencing con il DOM Helper come setup

### "La variabile restituisce sempre 'normal user' anche per bot evidenti"
Il DOM Helper potrebbe non aver eseguito prima della valutazione. Verifica:
1. Console: `window._bdHelperLoaded` deve essere `true`
2. Se è `undefined`, il DOM Helper non è stato eseguito → configura Tag Sequencing
3. Se è `true` ma lo score è basso, il bot è uno di quelli che bypassa il client-side (vedi limiti documentati)

### Tag Assistant mostra errori
Pubblica il container — gli errori in modalità Preview possono dipendere da permission non ancora salvate.

### Tag Sequencing non funziona
Verifica:
1. Il setup tag deve essere un **Custom HTML** (non un template) per essere usabile come setup
2. Spunta sempre **Don't fire [Tag] if [Setup Tag] fails or is paused** — altrimenti il tag fira comunque
3. Il setup tag eredita il trigger del tag principale, non quello configurato sul setup tag stesso
