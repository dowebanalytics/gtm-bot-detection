# Test Results — Stress Test 130 Scenari

Stress test eseguito su un sito di produzione Shopify con container GTM dedicato.

## Risultati globali

| Metrica | Valore |
|---|---|
| Scenari testati | 130 |
| Categorie | 11 |
| Bot rilevati | 73 (56%) |
| Utenti reali corretti | 20/20 (100%) |
| Falsi positivi | 0 |
| Resilienza tampering | 8/8 attacchi bloccati |

## Detection rate per categoria

| Categoria | Totale | Rilevati | % |
|---|---|---|---|
| Network/HTTP scrapers (curl, requests, axios, Scrapy, urllib, httpx, aiohttp, wget, Guzzle, Go, Java, Ruby, curl-impersonate, HTTP/3, TLS forge) | 16 | 16 | **100%** |
| Crawler legittimi (Googlebot, Bingbot, GPTBot, ClaudeBot, PerplexityBot, Wayback, AhrefsBot, SemrushBot) | 8 | 8 | **100%** |
| CAPTCHA solvers (2Captcha, AntiCaptcha, CapMonster, DeathByCaptcha) | 4 | 4 | **100%** |
| Mobile farms (BrowserStack, SauceLabs, LambdaTest, TestingBot, Bitbar, HeadSpin, pCloudy, Kobiton, Appium) | 10 | 10 | **100%** |
| Shopify e-commerce attacks | 16 | 11 | 69% |
| AI agents 2025 (BrowserUse, AutoGPT, LangChain, Multi-on, Adept, Anthropic, GPT-4V, Skyvern, TaskWeaver) | 13 | 8 | 62% |
| Stealth tools 2025 (Camoufox, NoDriver, SeleniumBase UC, Botright, Patchright, Hero, ZenRows, ScrapingAnt, Oxylabs) | 16 | 8 | 50% |
| Anti-detect commerciali (Kameleo, Multilogin, GoLogin, AdsPower, Octo, Incogniton, BrowserScan, Hidemyacc) | 11 | 3 | 27% |
| Proxy networks (Bright Data, Smartproxy, Soax, NetNut, IPRoyal, Tor, VPN) | 8 | 2 | 25% |
| Polyglot combinations | 8 | 3 | 37% |
| **Utenti reali** | **20** | **0** | **0% (corretto)** |

## Segnali anti-tampering e avanzati in azione

| Segnale | Punti | Scenari catturati |
|---|---|---|
| `tampering` | +5 | Botright + tampering, Kameleo + tampering, GoLogin + tampering, Bright Data + tampering, Ticketmaster + tampering, AI + Stealth + tampering, MEGA POLYGLOT |
| `syntheticMouse` | +4 | Camoufox + sintetici, NoDriver + sintetici, SeleniumBase UC + sintetici, Patchright + sintetici, Multilogin + interazione finta, Newsletter abuse, BrowserUse + AI sintetici, GPT-4V web browsing |
| `syntheticScroll` | +3 | NoDriver + sintetici, Multilogin + interazione finta, Anti-detect + 2Captcha + sintetici |
| `mouseTooFast` | +2 | SeleniumBase UC + sintetici, BrowserUse + AI sintetici, GPT-4V web browsing, Limited drop + synth, Newsletter abuse + synth |
| `lowMouseEntropy` | +2 | MEGA POLYGLOT (in combinazione) |

## Resilienza anti-tampering

| Attacco | Risultato |
|---|---|
| `window._bdThreshold = 999` | ✅ BLOCCATO — valore rimane 5 |
| `delete window._bdInit` | ✅ BLOCCATO — delete=false |
| `window._bdHelperLoaded = false` | ✅ BLOCCATO — valore rimane true |
| `window._bdMouseMoved = true` | ✅ BLOCCATO — silently ignored |
| `Object.defineProperty` hijack | ✅ BLOCCATO — TypeError cannot redefine |
| `delete window._bdMouseMoved` | ✅ BLOCCATO — non eliminabile |
| Tampering `screen.width` | ✅ RILEVATO (+5 tampering) |
| Tampering `navigator.webdriver` | ✅ RILEVATO (+5 tampering) |

## Top 10 bot rilevati

| Bot | Score | Segnali |
|---|---|---|
| CapMonster Cloud | 21/5 | dH + wd + noPl + cvE + wgS + noLg + noM + noS |
| MEGA POLYGLOT | 16/5 | tampering + synthM + synthS + lowEnt + tooFast |
| Discount code brute force | 15/5 | dH + wd + noPl + noLg + noM + noS |
| Bitbar / Kobiton / Appium farm | 15/5 | dH + wd + noPl + noLg + noM + noS |
| Account creation mass signup | 13/5 | dH + wd + noPl + noM + noS |
| 2Captcha worker | 13/5 | dH + wd + noPl + noM + noS |
| AntiCaptcha bot | 13/5 | dH + wd + noPl + noM + noS |
| Open Interpreter / TaskWeaver | 12/5 | wd + noPl + noLg + noM + noS |
| Gift card balance checker | 12/5 | wd + noPl + noLg + noM + noS |
| NoDriver + sintetici | 10/5 | noM + noS + synthM + synthS |

## Limite teorico — bypass residui

| Scenario | Motivo |
|---|---|
| Botright CDP stealth puro | Browser reale, fingerprint perfetto, nessun evento sintetico |
| Multi-on / Adept ACT-1 | Browser reale guidato da AI con pattern umani |
| Anthropic computer use | Browser reale (analogo a Claude in Chrome) |
| Ticketmaster scalper stealth | Anti-detect perfetto + comportamento umano simulato |
| PS5 / Pokemon scalpers | Bot scalper di alto livello |
| Bot mimica utente IT | Fingerprint identico a Mac italiano reale |
| Anti-detect commerciali puri | Kameleo, Multilogin senza tampering/sintetici |
| Proxy networks puri | Bright Data, Soax sembrano utenti reali |

Per coprire questi scenari serve un layer **server-side**: IP reputation, rate limiting, fraud detection dedicato.
