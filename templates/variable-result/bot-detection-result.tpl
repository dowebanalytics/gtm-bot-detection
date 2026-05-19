___INFO___

{
  "displayName": "Bot Detection Result",
  "description": "Calcola bot score da 21 segnali e restituisce normal user o possible bot. Richiede DOM Helper e Init Tag. Bot Detection v3 DO Web Analytics.",
  "type": "VARIABLE",
  "containerContexts": ["WEB"]
}

___TEMPLATE_PARAMETERS___

[]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

var copyFromWindow  = require('copyFromWindow');
var makeInteger     = require('makeInteger');
var makeString      = require('makeString');
var makeNumber      = require('makeNumber');
var logToConsole    = require('logToConsole');

var botScore  = 0;
var details   = [];
var threshold = makeInteger(copyFromWindow('_bdThreshold')) || 5;
var debugMode = copyFromWindow('_bdDebug') || false;

// ── 1. SCREEN vs BROWSER DIMENSIONS (da DOM Helper) ──────────────────────────
var screenWidth   = makeInteger(copyFromWindow('_bdScreenWidth'))   || 0;
var screenHeight  = makeInteger(copyFromWindow('_bdScreenHeight'))  || 0;
var browserWidth  = makeInteger(copyFromWindow('_bdBrowserWidth'))  || 99999;
var browserHeight = makeInteger(copyFromWindow('_bdBrowserHeight')) || 99999;
var deltaWidth    = screenWidth  - browserWidth;
var deltaHeight   = screenHeight - browserHeight;

if (screenWidth  > 0 && deltaWidth  < 0)  { botScore += 3; details.push('deltaWidth<0');   }
if (screenHeight > 0 && deltaHeight <= 0) { botScore += 3; details.push('deltaHeight<=0'); }

// ── 2. WEBDRIVER (da DOM Helper) ──────────────────────────────────────────────
if (copyFromWindow('_bdWebdriver') === true) { botScore += 5; details.push('webdriver=true'); }

// ── 3. USER AGENT (da DOM Helper) ────────────────────────────────────────────
var ua = makeString(copyFromWindow('_bdUA')) || '';
var uaLower = ua.toLowerCase();
var isHeadless = uaLower.indexOf('headlesschrome') !== -1 ||
                 uaLower.indexOf('phantomjs')      !== -1 ||
                 uaLower.indexOf('selenium')       !== -1 ||
                 uaLower.indexOf('webdriver')      !== -1;
if (isHeadless) { botScore += 4; details.push('suspiciousUA'); }

// ── 4. PLUGINS (da DOM Helper) ────────────────────────────────────────────────
var pluginsLen = makeInteger(copyFromWindow('_bdPluginsLen'));
if (pluginsLen === 0) { botScore += 2; details.push('noPlugins'); }

// ── 5. COLOR DEPTH (da DOM Helper) ───────────────────────────────────────────
var colorDepth = makeInteger(copyFromWindow('_bdColorDepth')) || 0;
if (colorDepth > 0 && colorDepth < 16) { botScore += 2; details.push('colorDepth<16'); }

// ── 6. DEVICE PIXEL RATIO (da DOM Helper) ────────────────────────────────────
var dpr = makeNumber(copyFromWindow('_bdDpr')) || 1;
if (dpr < 1) { botScore += 2; details.push('dpr<1'); }
var isApple = ua.indexOf('iPhone') !== -1 || ua.indexOf('iPad') !== -1;
if (isApple && dpr < 2) { botScore += 3; details.push('appleDprAnomaly'); }

// ── 7. TOUCH vs USER AGENT (da DOM Helper) ───────────────────────────────────
var isMobile    = uaLower.indexOf('mobi')    !== -1 ||
                  uaLower.indexOf('android') !== -1 ||
                  ua.indexOf('iPhone')       !== -1 ||
                  ua.indexOf('iPad')         !== -1;
var touchPoints = makeInteger(copyFromWindow('_bdMaxTouchPoints')) || 0;
var hasTouch    = touchPoints > 0;
if (isMobile && !hasTouch)                       { botScore += 3; details.push('mobileUAnoTouch');         }
if (!isMobile && hasTouch && screenWidth < 500)  { botScore += 2; details.push('desktopUAmobileViewport'); }

// ── 8. CANVAS (da DOM Helper) ─────────────────────────────────────────────────
var canvasScore = makeInteger(copyFromWindow('_bdCanvasScore')) || 0;
if (canvasScore > 0) {
  botScore += canvasScore;
  details.push(canvasScore >= 3 ? 'canvasEmpty' : 'canvasBlocked');
}

// ── 9. WEBGL (da DOM Helper) ──────────────────────────────────────────────────
var webglScore = makeInteger(copyFromWindow('_bdWebGLScore')) || 0;
if (webglScore > 0) {
  botScore += webglScore;
  if      (webglScore === 2) { details.push('noWebGL');          }
  else if (webglScore === 3) { details.push('softwareRenderer'); }
  else                       { details.push('webglError');       }
}

// ── 10. WINDOW.CHROME (da DOM Helper) ────────────────────────────────────────
var isChrome     = ua.indexOf('Chrome')   !== -1 &&
                   ua.indexOf('Chromium') === -1 &&
                   ua.indexOf('Edge')     === -1 &&
                   ua.indexOf('Edg/')     === -1;
var hasChromeObj = copyFromWindow('_bdHasChromeObj');
if (isChrome && !hasChromeObj) { botScore += 3; details.push('chromeMissing'); }

// ── 11. LINGUA E TIMEZONE (da DOM Helper) ────────────────────────────────────
var lang = makeString(copyFromWindow('_bdLanguage')) || '';
var tz   = makeString(copyFromWindow('_bdTimezone')) || '';
if (!lang)                { botScore += 2; details.push('noLanguage');      }
if (lang && tz === 'UTC') { botScore += 2; details.push('langTimezoneUTC'); }

// ── 12. PERMISSIONS (da DOM Helper) ──────────────────────────────────────────
if (copyFromWindow('_bdNotificationsDenied') === true) { botScore += 1; details.push('notificationsDenied'); }

// ── 13. MOUSE E SCROLL (da DOM Helper) ───────────────────────────────────────
if (copyFromWindow('_bdInit') === true) {
  if (copyFromWindow('_bdMouseMoved') === false) { botScore += 2; details.push('noMouseMove'); }
  if (copyFromWindow('_bdScrolled')   === false) { botScore += 1; details.push('noScroll');    }
}

// ── RISULTATO ─────────────────────────────────────────────────────────────────
var result = (botScore >= threshold) ? 'possible bot' : 'normal user';

if (debugMode || copyFromWindow('location.hostname') === 'localhost') {
  logToConsole('[BotDetect] score=' + botScore +
               ' threshold=' + threshold +
               ' | ' + details.join(', ') +
               ' | ' + result);
}

return result;


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": { "publicId": "access_globals", "versionId": "1" },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdInit"},               {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdThreshold"},          {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdDebug"},              {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdScreenWidth"},        {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdScreenHeight"},       {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdBrowserWidth"},       {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdBrowserHeight"},      {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdWebdriver"},          {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdUA"},                 {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdPluginsLen"},         {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdColorDepth"},         {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdDpr"},                {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdMaxTouchPoints"},     {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdLanguage"},           {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdHasChromeObj"},       {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdTimezone"},           {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdCanvasScore"},        {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdWebGLScore"},         {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdNotificationsDenied"},{"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdMouseMoved"},         {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"_bdScrolled"},           {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] },
              { "type": 3, "mapKey": [{"type":1,"string":"key"},{"type":1,"string":"read"},{"type":1,"string":"write"},{"type":1,"string":"execute"}], "mapValue": [{"type":1,"string":"location.hostname"},     {"type":8,"boolean":true},{"type":8,"boolean":false},{"type":8,"boolean":false}] }
            ]
          }
        }
      ]
    },
    "clientAnnotations": { "isEditedByUser": true },
    "isRequired": true
  }
]


___NOTES___

Bot Detection Result — v3
DO Web Analytics / Tag Manager Italia

PREREQUISITI (ordine obbligatorio):
1. Custom HTML "Bot Detection DOM Helper" — DOM Ready, Priorità 20
2. Tag Template "Bot Detection Init"       — DOM Ready, Priorità 10
3. Questa variabile — valutata al momento dell'uso

USO:
  {{Bot Detection Result}} equals 'normal user'   → condizione trigger
  'bot_result': {{Bot Detection Result}}           → dataLayer push

SEGNALI: 21 totale
  Sincroni (calcolati dalla variabile): screen/browser, webdriver, UA,
  colorDepth, dpr, touch/UA, chrome, lingua, timezone
  Da DOM Helper (window._bd*): canvas, webgl, plugins, timezone,
  permissions, mouse, scroll
