# Changelog

## [v4.0] — 2025-05

### Aggiunto
- Anti-tampering: closure namespace + `Object.defineProperty(configurable: false)` su tutti i flag `_bd*`
- `event.isTrusted` filter su listener mouse/scroll
- Nuovi flag esposti: `_bdMouseUntrustedCount`, `_bdScrollUntrustedCount`, `_bdMouseEntropy`, `_bdMouseTrustedCount`, `_bdFirstMouseDelay`, `_bdLiveCheckPassed`, `_bdIntegrityHash`, `_bdInitTime`
- Calcolo entropia movimento mouse (curvatura + varianza temporale)
- Hash integrity djb2 dello stato iniziale
- Live check tampering su `screen.width/height`, `navigator.webdriver`, `navigator.userAgent`
- 5 nuovi segnali nel template Result: `tampering` (+5), `syntheticMouse` (+4), `syntheticScroll` (+3), `lowMouseEntropy` (+2), `mouseTooFast` (+2)

### Risolto
- 5 vulnerabilità di tampering del namespace `_bd*`
- Bypass critici Stealth L8-L9 (bot che simulava mouse/scroll via dispatchEvent)
- Bot AI che manipolavano `navigator.userAgent` post-init

### Rimosso
- Permission `location.hostname` (debug ora solo via parametro `_bdDebug` esplicito)
- Template `tag-init` (configurazione spostata direttamente nel DOM Helper)

### Stats v4
- 26 segnali (era 21 in v3)
- 27 permission read-only nel template Result
- 0 nuovi falsi positivi introdotti
- 100% compatibilità API con v3

---

## [v3.0] — 2025-04

### Aggiunto
- Sistema multi-segnale con 21 segnali a punteggio
- Canvas + WebGL fingerprint nel DOM Helper
- Permissions API check (notifications denied)
- Listener mouse/scroll con removeEventListener dopo prima rilevazione
- Template GTM ufficiali per Custom Template TAG e VARIABLE
- Configurazione soglia modificabile (default 5)

### Risolto
- Errori GTM sandbox restrictions (regex, brand INFO, permission predefinite)
- Refactoring: tutti i segnali catturati dal DOM Helper, Result template legge solo `_bd*`
