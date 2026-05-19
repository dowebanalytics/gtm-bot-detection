# Bot Detection v3 vs v4 — Comparazione

## Sintesi

| Metrica | v3 | v4 | Δ |
|---|---|---|---|
| Vulnerabilità tampering | 5 critiche | 0 | -100% |
| Bypass Stealth L7-L9 | 3/3 | 0/3 | -100% |
| Falsi positivi (utenti reali) | 2 (Tor, Smart TV) | 2 | invariato |
| Segnali totali | 21 | 26 | +5 |
| Bot AI con interazione finta | bypass | rilevato | ✅ |

## Vulnerabilità di tampering chiuse

| Attacco | v3 | v4 |
|---|---|---|
| Override `_bdThreshold = 999` | 🟥 BYPASS riuscito | ✅ BLOCCATO |
| `delete window._bdInit` | 🟥 BYPASS riuscito | ✅ BLOCCATO |
| Reset `_bdHelperLoaded = false` | 🟥 BYPASS riuscito | ✅ BLOCCATO |
| `dispatchEvent` mousemove sintetico | 🟥 BYPASS riuscito | ✅ BLOCCATO + RILEVATO |
| `Object.defineProperty` hijack | 🟥 BYPASS riuscito | ✅ TypeError thrown |
| Live tampering `navigator.userAgent` | 🟥 NON RILEVATO | ✅ RILEVATO (+5) |

## Bot adversarial ora catturati

| Scenario | v3 | v4 |
|---|---|---|
| Stealth L8: scroll iniettato | 2/5 USER 🟥 | **6/5 BOT** ✅ |
| Stealth L9: mouse+scroll iniettati | 0/5 USER 🟥 | **10/5 BOT** ✅ |
| undetected-chromedriver + mouse fake | 0/5 USER 🟥 | **10/5 BOT** ✅ |
| Bot AI con tampering navigator | 0/5 USER 🟥 | **5/5 BOT** ✅ |
| Bot POLYGLOT (tutto sintetico) | 0/5 USER 🟥 | **14/5 BOT** ✅ |

## I 4 miglioramenti introdotti

### 1. Closure namespace + Object.defineProperty
Lo stato del DOM Helper è racchiuso in una IIFE. I valori sono esposti su window solo tramite getter `configurable: false`. Il bot non può sovrascrivere, eliminare o ridefinire alcuna variabile.

### 2. event.isTrusted filter
I listener di mouse/scroll filtrano gli eventi sintetici. `event.isTrusted` è true solo per eventi generati dall'hardware (OS-level), false per eventi dispatchati da JavaScript.

### 3. Mouse entropy + first-mouse-delay
Cattura dei primi 10 movimenti del mouse e calcolo della curvatura del percorso + varianza temporale. Movimenti perfettamente lineari (bot) o eventi mouse iniettati troppo velocemente dopo l'init vengono segnalati.

### 4. Integrity check live
Al momento dell'init vengono catturati i valori nativi di `screen`, `navigator`. Al momento della valutazione, vengono confrontati con i valori live: differenza = tampering post-init.

## Compatibilità

v4 è drop-in replacement di v3:
- Stessi nomi `window._bd*`
- Stesso output `'possible bot'` / `'normal user'`
- Stessi trigger GTM (DOM Ready, priorità 20)
- Stessa configurazione (threshold modificabile in DOM Helper)

Unico passaggio operativo: re-import del template variable con **Approve all** sulle 7 nuove permission.
