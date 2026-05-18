# GTM Bot Detection v3

Sistema di rilevamento bot per **Google Tag Manager** basato su score multi-segnale (21 segnali).

Sviluppato da [DO Web Analytics](https://dowebanalytics.com) / [Tag Manager Italia](https://tagmanageritalia.it).

---

## Componenti

| File | Tipo | Descrizione |
|---|---|---|
| `dom-helper/bot-detection-dom-helper.html` | Custom HTML Tag | Accesso DOM completo: canvas, WebGL, permissions, mouse/scroll |
| `templates/tag-init/bot-detection-init.tpl` | Custom Template TAG | Salva configurazione (threshold, debug) su `window` |
| `templates/variable-result/bot-detection-result.tpl` | Custom Template VARIABLE | Calcola score e restituisce `'normal user'` / `'possible bot'` |

---

## Setup GTM (ordine obbligatorio)

| Ordine | Componente | Tipo GTM | Trigger | Priorità |
|---|---|---|---|---|
| 1 | DOM Helper | Custom HTML | DOM Ready | 20 |
| 2 | Bot Detection Init | Template TAG | DOM Ready | 10 |
| 3 | Bot Detection Result | Template VARIABLE | — (valutata al momento dell'uso) | — |

### Importare i template

**Templates → New → Import** → seleziona il file `.tpl` → Salva.

Per il DOM Helper: **Tags → New → Custom HTML** → incolla il contenuto di `bot-detection-dom-helper.html`.

---

## Segnali rilevati (21 totale)

| Segnale | Punti |
|---|---|
| `navigator.webdriver = true` | +5 |
| HeadlessChrome / Selenium in User Agent | +4 |
| `deltaWidth < 0` (browser più largo dello schermo) | +3 |
| `deltaHeight ≤ 0` (browser alto quanto lo schermo) | +3 |
| UA mobile + no touch (`maxTouchPoints = 0`) | +3 |
| Apple device con `devicePixelRatio < 2` | +3 |
| Canvas vuoto (`dataURL.length < 200`) | +3 |
| WebGL software renderer (SwiftShader, llvmpipe, Mesa) | +3 |
| `window.chrome` assente su Chrome | +3 |
| `plugins.length = 0` | +2 |
| `colorDepth < 16` | +2 |
| `devicePixelRatio < 1` | +2 |
| UA desktop + touch + viewport < 500px | +2 |
| `navigator.language` assente | +2 |
| Timezone UTC con lingua impostata | +2 |
| WebGL assente | +2 |
| Nessun movimento mouse (dalla 2ª chiamata) | +2 |
| Canvas bloccato | +1 |
| WebGL error | +1 |
| Notifications permission `denied` | +1 |
| Nessuno scroll (dalla 2ª chiamata) | +1 |

**Soglia default: 5** — configurabile dal template Init senza modificare il codice.

---

## Output

La variabile `Bot Detection Result` restituisce una stringa:

- `'normal user'` — botScore < soglia
- `'possible bot'` — botScore ≥ soglia oppure errore

### Uso tipico

```javascript
// Come condizione trigger GA4 / Google Ads:
{{Bot Detection Result}} equals 'normal user'

// Come dataLayer push:
dataLayer.push({
  'event': 'bot_detection',
  'bot_result': {{Bot Detection Result}}
});
```

---

## Parametri configurabili (template Init)

| Parametro | Default | Descrizione |
|---|---|---|
| Soglia bot score | `5` | Punteggio minimo per `possible bot` |
| Debug mode | `false` | Scrive score e segnali in console |

---

## Reset su SPA

Aggiungere un Custom HTML tag sul trigger **History Change**:

```html
<script>
  window._bdInit              = undefined;
  window._bdHelperLoaded      = undefined;
  window._bdMouseMoved        = false;
  window._bdScrolled          = false;
  window._bdNotificationsDenied = false;
</script>
```

---

## Namespace `window._bd*`

| Variabile | Tipo | Impostata da | Descrizione |
|---|---|---|---|
| `_bdInit` | boolean | Init Template | Flag di inizializzazione |
| `_bdThreshold` | integer | Init Template | Soglia configurata |
| `_bdDebug` | boolean | Init Template | Debug mode |
| `_bdHelperLoaded` | boolean | DOM Helper | Evita doppia init |
| `_bdMouseMoved` | boolean | DOM Helper | Evento mousemove ricevuto |
| `_bdScrolled` | boolean | DOM Helper | Evento scroll ricevuto |
| `_bdTimezone` | string | DOM Helper | Timezone rilevato |
| `_bdPluginsLen` | integer | DOM Helper | `navigator.plugins.length` |
| `_bdCanvasScore` | integer | DOM Helper | Score canvas (0/1/3) |
| `_bdWebGLScore` | integer | DOM Helper | Score WebGL (0/1/2/3) |
| `_bdNotificationsDenied` | boolean | DOM Helper | Permissions API result |

---

## Versione

- **v3** — Maggio 2025
- Richiede GTM container web standard
- Compatibile IE11 (DOM Helper usa `removeEventListener` invece di `{ once: true }`)

