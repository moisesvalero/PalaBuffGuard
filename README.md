# 🛡️ BuffGuard

**Recordatorio minimalista y lanzamiento en 1 clic de los bufos esenciales del Paladín para World of Warcraft Forever (`1.60.1`).**

![Vista previa de BuffGuard](docs/preview.png)

> **Cero ruido visual:** BuffGuard permanece completamente oculto mientras tengas tus bufos activos. Solo aparece cuando te falta **Furia justa**, **Aura** o **Bendición** (o cuando a tu bendición le quedan ≤ 30 segundos).

---

## ✨ Características principales

* **Solo para Paladines:** Si entras con cualquier otra clase, el addon se desactiva automáticamente sin consumir memoria ni eventos.
* **3 vigilantes clave:**
  1. **Furia (`FURIA`):** Detecta *Furia justa* / *Furia recta* (*Righteous Fury*).
  2. **Aura (`AURA`):** Detecta cualquier aura activa (*Devoción, Represalia, Concentración, Santidad, Resistencias*).
  3. **Bendición (`BENDICIÓN`):** Detecta *Poderío, Sabiduría, Reyes, Salvaguardia/Santuario, Luz, Salvación* y sus versiones superiores. Muestra una **cuenta atrás** cuando quedan 30 segundos o menos.
* **Lanzamiento en 1 clic (fuera de combate):**
  * **Clic izquierdo:** Lanza el último bufo usado (o el principal por defecto) a rango máximo sin perder tu objetivo actual (`[@player]`).
  * **Clic derecho:** Alterna al bufo secundario (por ejemplo, entre *Aura de represalia* y *Aura de devoción*, o entre *Bendición del poderío* y *Bendición de Sabiduría*).
* **100 % seguro en combate:** Usa `SecureHandlerStateTemplate` para ocultar los botones clicables automáticamente al entrar en combate (nunca bloquea el giro de cámara con el ratón), mientras cambia los bordes a **rojo urgente con animación de rebote**.
* **Multi-idioma automático:** Resuelve los nombres de hechizos por ID desde el cliente y cuenta con respaldo para `esES`, `esMX` y `enUS`.
* **Ocultación inteligente:** Se oculta automáticamente si estás muerto/fantasma, en ruta de vuelo o en vehículo.

---

## 📦 Instalación

1. Descarga la última versión desde [Releases](../../releases) o clona este repositorio.
2. Copia la carpeta **`BuffGuard`** dentro de tu directorio de AddOns:
   ```text
   World of Warcraft/_forever_/Interface/AddOns/BuffGuard/
   ```
3. Verifica que dentro de la carpeta estén directamente `BuffGuard.toc` y `BuffGuard.lua`.
4. Reinicia WoW (o escribe `/reload`) y asegúrate de tener **BuffGuard** activado en *Accesorios*.

---

## 🎮 Comandos en el juego

Puedes usar **`/bguard`** o **`/buffguard`** (también se mantienen `/furia` y `/fa` como alias):

| Comando | Acción |
| :--- | :--- |
| `/bguard` o `/bguard mover` | Activa/desactiva el modo mover para arrastrar los iconos donde quieras (clic derecho para bloquear). |
| `/bguard scale <0.4 - 2.0>` | Ajusta el tamaño del HUD (por defecto `0.85`). Ejemplo: `/bguard scale 1.0`. |
| `/bguard texto` | Muestra u oculta las etiquetas inferiores (`FURIA`, `AURA`, `BENDICIÓN`). |
| `/bguard rf` | Activa o desactiva el aviso de **Furia justa**. |
| `/bguard aura` | Activa o desactiva el aviso de **Aura**. |
| `/bguard bendicion` | Activa o desactiva el aviso de **Bendición**. |
| `/bguard combate` | Alterna entre avisar **siempre** o **solo en combate**. |
| `/bguard reset` | Restablece la posición y el tamaño por defecto. |

---

## 🛠️ Estructura del proyecto

```text
BuffGuard/
├── BuffGuard.toc      # Metadatos del addon (Interface 16001, SavedVariables)
├── BuffGuard.lua      # Lógica principal, escaneo de auras y botones seguros
├── docs/
│   └── preview.png     # Captura / vista previa del HUD
├── CHANGELOG.md        # Historial de versiones
├── LICENSE             # Licencia MIT
└── README.md           # Documentación
```

---

## 📄 Licencia

Distribuido bajo la licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.
