# Sessionskollen

En panel bredvid chatten som visar alla dina Claude Code-sessioner på ett ställe.

Öppna den med `/sessioner`. Kommandot skriver alltid översikten som text i chatten, och öppnar
panelen där appen kan visa den (Claude-appen ritar inte panelen för alla sessioner). Den visar:

- **Läget just nu**: två–tre meningar på klarspråk om vad som väntar på dig och vad som pågår.
- **Väntar på dig**: sessioner som ställer en fråga, obesvarade `beslut` och `larm` märkta
  `fredrik-behovs` i veirai/hq, och frågor som blev hängande i arkiverade trådar
  de senaste 14 dagarna (dölj dem med "Klar, dölj").
- **Väntar på din merge**: PR:er i hq, web och landing som inte är utkast, med CI-läget
  (grön, röd, kör). Gröna räknas som att de väntar på dig; röda och pågående väntar på en
  agent eller på CI.
- **Möjligt dubbelarbete**: aktiva sessioner som verkar jobba med samma sak.
- **Sessionerna** grupperade som Jobbar nu, Klar att granska och Vilar, med modell, kostnad
  och hur fullt minnet (kontexten) är.
- **Förbrukning** senaste 7 dagarna per modell, och hur mycket rutinjobb som körde Opus.
- **Spartips** per session.

## Agera: svara med knappar

`/sessionskollen:agera` (skriv "agera" i kommandomenyn) gör om samma lista till frågekort med en rekommendation, som du trycker på:
vilka gröna PR:er som ska mergas, och svar på frågor från andra sessioner och på
`beslut`-ärenden. Claude gör sedan det du valde: mergar en PR i taget, skickar ditt svar
till sessionen som frågade, eller kommenterar beslutet och sätter `besvarad`.

## Widgeten ovanför skrivrutan

En rad som alltid syns ovanför skrivrutan: `● 3 väntar på dig · 1 att merga · 4 jobbar`, med
knappen **Visa** som öppnar panelen. Samma rad står i statusraden. Raden hämtar nytt högst var
tionde minut när panelen är stängd (sessioner på samma maskin delar bilden), och var 90:e
sekund när panelen är öppen. Den syns först efter första hämtningen.

## Vad den gör och inte gör

Den läser bara. Den startar, stoppar, arkiverar eller skriver aldrig till en session och
skapar inga signaler: beslut och larm bor kvar i HQ (signalhubben) och visas här.

Den hämtar ingenting medan panelen är stängd. Sessioner på samma maskin delar en bild
(högst 75 sekunder gammal), så två öppna paneler hämtar inte dubbelt. En kort fråga till
Haiku görs bara när läget har ändrats.

Kostnaderna är vad Claude rapporterar per session (`cost_usd`). På ett abonnemang är det ett
mått på hur mycket av kvoten sessionen använt, inte en faktura. "Rutin" eller "komplex" är
Haikus gissning utifrån titel och status.

## Källor

- `claude-code-remote` MCP: `list_sessions`, `get_session`
- `github` MCP: `list_issues` på veirai/hq (etiketterna `beslut`, `besvarad`, `larm`, `fredrik-behovs`),
  `list_pull_requests` och `pull_request_read` (`get_check_runs`) på veirai/hq, web och landing

## Installation

Installeras av `scripts/session-start-plugins.sh` vid varje sessionsstart. För hand:

```bash
claude plugin marketplace add veirai/claude-tooling
claude plugin install sessionskollen@veirai-tooling --scope user
```

## Utveckla

```bash
claude plugin validate plugins/sessionskollen
claude plugin test plugins/sessionskollen
```
