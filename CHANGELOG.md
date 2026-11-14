# Changelog

## [1.0.0] - 2026-11-14
### Añadido
- Renombrado oficial del proyecto a **LightCheck** (antes `ForeverFuryAlert`).
- Recordatorio minimalista para **Paladín** en *WoW Forever* (`Interface: 16001`): **Furia justa/recta**, **Aura** y **Bendición**.
- **Click-casting fuera de combate** mediante `SecureActionButtonTemplate` (clic izquierdo: último usado / principal; clic derecho: secundario; `[@player]` para no perder el objetivo).
- Ocultación automática de botones seguros en combate (`RegisterStateDriver`) para no bloquear el giro de cámara.
- Aviso anticipado con cuenta atrás cuando a la bendición le quedan `<= 30s`.
- Detección dinámica de nombres de hechizos por ID + soporte bilingüe (`esES`, `esMX`, `enUS`).
- Comandos `/lightcheck`, `/lc` (y alias `/furia`, `/fa`).
