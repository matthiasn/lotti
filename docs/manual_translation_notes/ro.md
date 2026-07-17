# Note de revizuire pentru localizarea în română

Acest document păstrează observații apărute în timpul revizuirii localizării
aplicației în română. Nu stabilește automat formulări de produs: elementele de
mai jos au nevoie de o verificare ulterioară de către un vorbitor nativ care
cunoaște contextul funcției.

## Aspecte de verificat ulterior

| Suprafață | Text / termeni actuali | De ce merită revizuit |
| --- | --- | --- |
| Agenți | `suflet`, `feedback`, `1-la-1`, `trezire` | „Suflet” este o metaforă intenționată pentru persona agentului, dar combinația cu împrumuturile tehnice poate părea mai puțin firească în fluxurile dense de configurare. Ar trebui verificată ca set terminologic, nu cheie cu cheie. |
| Inferență AI | `AI`, `IA`, `raționament`, `reprezentări vectoriale` | Interfața folosește în principal marca `AI`, dar unele texte românești folosesc `IA`. Un redactor nativ ar trebui să aleagă convenția de produs și să verifice dacă „reprezentări vectoriale” este termenul potrivit pentru embeddings în publicul Lotti. |
| Sincronizare Matrix | `configurare`, `cod de configurare`, `coadă de ieșire`, `recuperare` | Importul securizat, recuperarea lacunelor și coada de mesaje sunt funcții tehnice. Formulările actuale sunt explicite, însă merită validate într-un parcurs real de asociere a două dispozitive. |
| Daily OS | `Daily OS`, `check-in`, `wake` | `Daily OS` este un nume de produs, iar ceilalți doi termeni apar în contexte conversaționale și tehnice. Este nevoie de o alegere editorială coerentă: păstrarea împrumuturilor sau folosirea echivalentelor românești. |
| Ghidul aplicației | `Ghid` în bara laterală, față de „manual” în conversație | „Ghid” este mai natural într-o aplicație, dar trebuie confirmat împotriva numelui public al documentației și a materialelor de lansare. |
| Etichete de platformă | `Backend`, `Frontend`, `Design`, `Chat`, `Desktop` | Acestea sunt termeni larg folosiți de echipele tehnice românești. Păstrarea lor este plauzibilă, însă mostrele din Design System ar trebui verificate vizual de un nativ înainte de o lansare localizată. |

Observațiile de mai sus nu semnalează chei lipsă. Ele marchează numai
decizii de ton sau de terminologie care necesită context de produs și o
revizuire umană în română.
