# Changelog

## [1.1.1] - 2026-11-15

### 🇪🇸 Español (España)
- **Renombrado oficial a `PalaBuffGuard` (`/pbg` / `/palabuffguard`):** Compatible con CurseForge y WoW Forever (`16001`), manteniendo migración automática de preferencias previas.
- **Endurecimiento para CurseForge y WoW Forever (`16001`):** Protección completa frente a `issecretvalue` en combate en `UNIT_AURA`, `C_UnitAuras`, `C_Traits` y eventos de unidad (`RegisterUnitEvent`).
- **Validación de hechizos aprendidos (`C_SpellBook`):** El lanzamiento en 1 clic comprueba qué rangos y talentos conoce realmente tu Paladín a cada nivel y al cambiar de rama (`Aura de devoción` / `Bendición del poderío` a niveles bajos; reinicio automático de bufos exclusivos de rama al cambiar de talentos).
- **Integración con el Cajón de AddOns (Addon Compartment):** Añadido icono y tooltip interactivo en el minimapa de WoW Forever (`Clic izquierdo` para mover, `Clic derecho` para ver estado de rama) y metadatos completos de CurseForge en `PalaBuffGuard.toc`.

### 🇬🇧 English
- **Official rename to `PalaBuffGuard` (`/pbg` / `/palabuffguard`):** Ready for CurseForge and WoW Forever (`16001`) with automatic settings migration.
- **CurseForge & WoW Forever (`16001`) Hardening:** Full `issecretvalue` combat protection across `UNIT_AURA`, `C_UnitAuras`, `C_Traits`, and player-filtered unit events (`RegisterUnitEvent`).
- **Learned-Spell Validation (`C_SpellBook`):** 1-click casting verifies which spells and talent buffs your Paladin actually knows at your current level and automatically resets spec-exclusive buffs when switching talent trees.
- **Minimap Addon Compartment Support:** Added interactive WoW Forever Addon Compartment button and tooltip (`Left-click` to move, `Right-click` for spec status) plus complete CurseForge `.toc` metadata.

---

## [1.1.0] - 2026-11-15

### 🇪🇸 Español (España)
- **Soporte completo para las 3 ramas de talentos en WoW Forever (`1.60.1`):** Detección automática en tiempo real mediante `C_ClassTalents` y `C_Traits` (*Sagrado*, *Protección* y *Reprensión*).
- **Furia justa inteligente (`auto`):** Si no estás en talentos de **Protección**, el addon no te avisa de *Furia justa* (configurable con `/pbg rf [auto|on|off]`).
- **Bufos por defecto según tu rama:** El lanzamiento en 1 clic adapta el Aura y la Bendición sugeridas a tu especialización actual (*Sagrado*, *Protección* o *Reprensión*), recordando siempre el último hechizo que lances manualmente.
- **Soporte bilingüe completo (`esES` / `enUS`):** Textos de interfaz, mensajes de chat, `.toc` y documentación disponibles en español de España e inglés (`/pbg lang [es|en]`, `/pbg status`).

### 🇬🇧 English
- **Full 3-spec talent support for WoW Forever (`1.60.1`):** Real-time talent branch detection via `C_ClassTalents` and `C_Traits` (*Holy*, *Protection*, and *Retribution*).
- **Smart Righteous Fury (`auto`):** Automatically suppresses *Righteous Fury* alerts when not in **Protection** talents (configurable via `/pbg rf [auto|on|off]`).
- **Spec-aware default buffs:** 1-click casting adapts default primary/secondary Aura and Blessing to your active talent tree while remembering your last manually cast spell.
- **Full bilingual support (`enUS` / `esES`):** HUD labels, chat output, `.toc` metadata, and documentation in both English and Spanish (`/pbg lang [en|es]`, `/pbg status`).

---

## [1.0.0] - 2026-11-14
- Lanzamiento inicial / Initial release of **PalaBuffGuard** for WoW Forever (`Interface: 16001`).
