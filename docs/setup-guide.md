# Setup Guide — GTM Bot Detection v4

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
3. Variable type: **Custom Template** → seleziona `Bot Detection Result v4`
4. Salva

## Step 4 — Pubblicazione

1. **Submit**
2. Aggiungi descrizione versione
3. **Publish**

## Step 5 — Verifica

Apri il sito con Tag Assistant attivo. Nella console (con `_bdDebug = true`):

```
[BotDetect v4] score=3 threshold=5 | noM,noS | normal user
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

## Troubleshooting

### "Prohibited read on global variable: _bd*"
Le permission non sono state approvate al re-import. Soluzione:
1. Elimina il template variable
2. Re-importa il file `.tpl`
3. Al popup permissions, clicca **Approve all**
4. Riassocia la variabile

### "Variabile sempre 'possible bot'"
Verifica con `_bdDebug = true` quali segnali si attivano. Se è solo `noMouseMove,noScroll` significa che la variabile viene valutata troppo presto. Sposta il trigger su un evento utente (Form Submit, Click).

### Tag Assistant mostra errori
Pubblica il container — gli errori in modalità Preview possono dipendere da permission non ancora salvate.
