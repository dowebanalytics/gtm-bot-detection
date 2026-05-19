___INFO___

{
  "displayName": "Bot Detection Init",
  "description": "Scrive threshold e debug su window bd. DOM Ready Priorita 10 dopo DOM Helper Priorita 20. Bot Detection v3 DO Web Analytics.",
  "type": "TAG",
  "containerContexts": ["WEB"]
}

___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "threshold",
    "displayName": "Soglia bot score",
    "simpleValueType": true,
    "defaultValue": 5,
    "valueValidators": [
      {
        "type": "POSITIVE_NUMBER"
      }
    ],
    "help": "Punteggio minimo per classificare la sessione come 'possible bot'. Default: 5. Aumentare (es. 7) per ridurre i falsi positivi in ambienti con utenti privacy-consapevoli (Brave, Firefox Strict)."
  },
  {
    "type": "CHECKBOX",
    "name": "debugMode",
    "displayName": "Debug mode",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Se attivo, scrive score e segnali attivati in console. Il log su localhost è sempre attivo indipendentemente da questa impostazione."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

var setInWindow     = require('setInWindow');
var makeInteger     = require('makeInteger');

var queryPermission = require('queryPermission');

var threshold = makeInteger(data.threshold) || 5;
var debugMode = data.debugMode ? true : false;

if (queryPermission('access_globals', 'write', '_bdThreshold')) {
  setInWindow('_bdThreshold', threshold, true);
}
if (queryPermission('access_globals', 'write', '_bdDebug')) {
  setInWindow('_bdDebug', debugMode, true);
}
if (queryPermission('access_globals', 'write', '_bdInit')) {
  setInWindow('_bdInit', true, true);
}

data.gtmOnSuccess();


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "_bdInit"},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "_bdThreshold"},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "_bdDebug"},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___NOTES___

Bot Detection Init — v3
DO Web Analytics / Tag Manager Italia

PREREQUISITI:
1. Custom HTML "Bot Detection DOM Helper" — DOM Ready, Priorità 20
2. Questo tag — DOM Ready, Priorità 10

DOPO:
3. Variabile "Bot Detection Result" — valutata al momento dell'uso

RESET SPA — Custom HTML su History Change:
<script>
  window._bdInit             = undefined;
  window._bdHelperLoaded     = undefined;
  window._bdMouseMoved       = false;
  window._bdScrolled         = false;
  window._bdNotificationsDenied = false;
</script>
