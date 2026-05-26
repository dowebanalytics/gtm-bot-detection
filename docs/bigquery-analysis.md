# BigQuery Analysis — GTM Bot Detection

Guida all'utilizzo del set di query SQL per analizzare il traffico bot sui dati GA4 esportati in BigQuery.

---

## Prerequisiti

- Export GA4 → BigQuery attivo ([guida Google](https://support.google.com/analytics/answer/9823238))
- Custom dimensions GA4 registrate come **Event-scoped**:
  - `bot_status`
  - `bot_score`
  - `bot_signal`
- Dati disponibili in BigQuery (tipicamente 24–48h di latenza)

---

## Configurazione rapida

Ogni query richiede due sostituzioni:

```sql
-- 1. Sostituisci con il tuo progetto e dataset
`your_project.your_dataset.events_*`

-- 2. Sostituisci con il range di date desiderato
_TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
```

---

## Le 12 query

### Query 1 — KPI Overview

**Obiettivo:** vista d'insieme del traffico, split umano vs bot.

**Output:** totale eventi, utenti unici, sessioni, % per status.

**Quando usarla:** prima analisi, report periodici, monitoraggio salute dati.

```
bot_status    | total_events | unique_users | unique_sessions | pct_events
normal_user   | 145.230      | 12.450       | 18.920          | 87.3%
possible_bot  | 21.100       | 3.200        | 4.100           | 12.7%
```

---

### Query 2 — Trend giornaliero

**Obiettivo:** andamento temporale del traffico bot.

**Output:** per ogni giorno, eventi bot, eventi umani, utenti bot, utenti umani, `bot_pct`.

**Quando usarla:** identificare picchi improvvisi, correlare con campagne, monitorare after-fix.

**Alert consigliato:** imposta una notifica se `bot_pct > 15%` su base giornaliera.

---

### Query 3 — Distribuzione score

**Obiettivo:** capire come si distribuisce la confidenza della detection.

**Output:** per ogni valore di score, conteggio eventi e status.

**Quando usarla:** calibrare la soglia. Se vedi molti eventi a score 5 con `possible_bot`, considera se alzare a 6 riduce i borderline senza perdere bot evidenti.

**Lettura tipo:**
```
score=3  normal_user  → utenti reali (score base Page View)
score=5  possible_bot → borderline (1 segnale sopra la soglia)
score=8+ possible_bot → bot con fingerprint evidenti
```

---

### Query 4 — Analisi segnali

**Obiettivo:** frequenza di ciascuno dei 26 segnali nel campione.

**Output:** codice segnale, descrizione leggibile, occorrenze, % sul totale dei segnali.

**Quando usarla:** capire quali segnali dominano il traffico bot nel tuo sito. Segnali con >80% di presenza sono "baseline" (quasi tutti i bot li attivano); segnali con <15% sono fingerprint specifici.

**Mappatura segnali → descrizione:** inclusa nella query come `CASE` statement.

---

### Query 5 — Combinazioni segnali (fingerprint)

**Obiettivo:** identificare i pattern di segnali più frequenti.

**Output:** stringa `bot_signal` completa, conteggio, score medio/massimo.

**Quando usarla:** capire quali tool specifici stai ricevendo. Ogni combinazione corrisponde tipicamente a un singolo automation tool o configurazione.

**Esempi di lettura:**
```
np|nmm|ns       → scraper HTTP, crawler
wdt|np|nmm|ns   → Selenium/ChromeDriver base
tmp|nd|nmm      → anti-detect browser con tampering
dw0|nd|nmm|ns   → headless Chrome senza configurazione viewport
```

---

### Query 6 — Pagine più colpite

**Obiettivo:** quali URL ricevono la maggior concentrazione di traffico bot.

**Output:** URL (senza query string), pageview bot, pageview umane, `bot_pct`.

**Quando usarla:** identificare endpoint sotto attacco (es. pagine login, checkout, form), prioritizzare protezioni server-side mirate.

**Filtro:** `HAVING bot_pageviews > 5` — rimuovi per vedere anche URL con un solo evento bot.

---

### Query 7 — Conversion inquinate

**Obiettivo:** quantificare quante conversion sono attribuibili a bot.

**Output:** per ogni evento conversion, conteggio bot vs umani, bot%, score medio bot.

**Quando usarla:** valutare l'impatto sulla qualità dei dati di conversione, correggere ROAS / CPA nelle campagne paid.

**Event name configurabili:** modifica la lista `IN (...)` con gli eventi conversion del tuo sito:
```sql
AND event_name IN (
  'purchase', 'generate_lead', 'begin_checkout',
  'add_to_cart', 'sign_up', 'form_submit', 'contact'
)
```

---

### Query 8 — Profilo device / OS / browser

**Obiettivo:** caratteristiche tecniche del traffico bot.

**Output:** device_category, OS, browser, eventi bot, eventi umani, bot%.

**Quando usarla:** identificare configurazioni tecniche anomale (es. Linux headless Chrome, Windows + no-plugins), verificare la compatibilità della detection con browser reali edge case.

---

### Query 9 — Geo analysis

**Obiettivo:** distribuzione geografica del traffico bot.

**Output:** paese, città, eventi bot, eventi umani, bot%.

**Quando usarla:** identificare origini geografiche sospette (datacenter in paesi anomali), supportare decisioni di geo-blocking server-side.

---

### Query 10 — Timeline sessione bot

**Obiettivo:** analisi dettagliata di singole sessioni sospette.

**Output:** per ogni evento di sessioni classificate `possible_bot`, tutti i campi diagnostici (timestamp, URL, segnali, browser, geo).

**Quando usarla:** debug della detection, validazione falsi positivi, reverse engineering del comportamento bot.

**Come usarla:** filtra per un singolo `user_pseudo_id` o `session_id` se vuoi analizzare una sessione specifica. Aggiungi `WHERE b.bot_score > 10` per concentrarti sui bot ad alta confidenza.

---

### Query 11 — Impatto revenue

**Obiettivo:** stimare il valore delle transazioni attribuite a bot.

**Output:** per status, conteggio transazioni, revenue totale, AOV, % sul totale revenue.

**Quando usarla:** comunicare l'impatto economico della bot detection agli stakeholder, giustificare l'investimento in protezioni aggiuntive.

> ⚠️ Revenue `possible_bot` non indica necessariamente frode: può essere traffico di test interno, transazioni di staging, ordini staff. Verifica manualmente prima di comunicare il numero.

---

### Query 12 — Indice di rischio segnale

**Obiettivo:** capire il ruolo di ciascun segnale nell'ecosistema bot rilevato.

**Output:** segnale, occorrenze tra i bot, score medio totale dei bot con quel segnale, % sul totale eventi bot, classificazione ruolo.

**Classificazione:**
- **baseline (>80%)** — quasi tutti i bot lo hanno; poco discriminante da solo
- **comune (40–80%)** — presente in molti bot
- **moderato (15–40%)** — segnale con buon potere discriminante
- **specifico (<15%)** — fingerprint preciso di un sottogruppo bot specifico

**Quando usarla:** decidere se ricalibrate i pesi dei segnali o aggiungere nuovi segnali custom.

---

## CTE base riutilizzabile

Incolla questa CTE in cima a qualsiasi query custom per estrarre le tre dimensioni bot senza riscrivere il codice UNNEST:

```sql
WITH base AS (
  SELECT
    event_date,
    event_name,
    user_pseudo_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location')    AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id')       AS session_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status')       AS bot_status,
    COALESCE(
      (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
      (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
    )                                                                                     AS bot_score,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_signal')       AS bot_signal,
    device.category        AS device_category,
    device.operating_system AS os,
    device.browser         AS browser,
    geo.country            AS country,
    geo.city               AS city
  FROM `your_project.your_dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
)
```

---

## Ottimizzazione costi BigQuery

Ogni query scansiona l'intera tabella `events_*` per il range di date selezionato. Per ridurre i costi:

**1. Restringi il range di date** — usa `_TABLE_SUFFIX BETWEEN` il più stretto possibile.

**2. Proiezione colonne** — evita `SELECT *`; seleziona solo i campi necessari.

**3. Usa le partitioned tables** — se il dataset GA4 è partizionato, BigQuery usa automaticamente il filtro `_TABLE_SUFFIX` come partition pruning.

**4. Crea una tabella materializzata** — per analisi ricorrenti, crea una tabella derivata con solo le colonne bot:

```sql
CREATE OR REPLACE TABLE `your_project.your_dataset.bot_events` AS
SELECT
  event_date,
  event_name,
  user_pseudo_id,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id')  AS session_id,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status')  AS bot_status,
  COALESCE(
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'bot_score'),
    (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
  )                                                                                AS bot_score,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_signal')  AS bot_signal,
  device.category        AS device_category,
  device.operating_system AS os,
  device.browser         AS browser,
  geo.country            AS country
FROM `your_project.your_dataset.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231'
  AND (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'bot_status') IS NOT NULL;
```

---

## Note sul tipo del campo `bot_score`

GA4 può ricevere il parametro `bot_score` come `int` o `string` a seconda di come è configurata la variabile in GTM. Per questo le query usano un `COALESCE`:

```sql
COALESCE(
  (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'bot_score'),
  (SELECT CAST(value.string_value AS INT64) FROM UNNEST(event_params) WHERE key = 'bot_score')
)
```

Se la tua variabile GTM ha Output = `score` (tipo Number), il `value.int_value` sarà sempre popolato e il fallback non sarà mai usato.
