# Gamepad (Xbox 360 / PS4 DualShock) — nativní joystick

AeroWars používá **nativní podporu joysticku v Luanti** (přes SDL2) — žádný
externí mapovač (AntiMicroX apod.) není potřeba. Funguje s Xbox 360 (drát)
i PS4 DualShock (Bluetooth) na macOS.

## Zapnutí

Už je nastaveno v `~/Library/Application Support/minetest/minetest.conf`:

```
enable_joysticks = true
joystick_type = auto      # auto-detekce; případně "xbox" nebo "ps5"
joystick_deadzone = 2600
joystick_frustum_sensitivity = 150.0   # rychlost otáčení pravou páčkou
```

⚠️ `enable_joysticks` se projeví **až po restartu Luanti**. Ovladač připoj
**před** spuštěním (Xbox drátem, DualShock spáruj přes Bluetooth).

## Ovládání

| Vstup | Akce |
|---|---|
| **Pravá páčka** | míření / let (letadlo se dotáčí za zaměřovačem) |
| **Levá páčka nahoru/dolů** | plyn / brzda (analogově dle výchylky) |
| **Levá páčka doleva/doprava** | zatáčení (yaw) |
| tlačítko → `jump` | nos nahoru; podržet ≥0,8 s = **Looping** |
| tlačítko → `sneak` | nos dolů |
| tlačítko → `aux1` | **střelba** |
| tlačítko → `dig` / `place` | náklon (roll) L/P; dvojklik = **Barrel roll** |
| tlačítko → `zoom` | **Boost** |
| dvojité „dozadu" (`down`) | **Immelmann** (otočka 180°) |

Pravá páčka je hlavní řízení (jako myš), levá dává plyn a yaw — plyn i zatáčení
jsou **proporcionální** podle výchylky páčky.

## Které fyzické tlačítko dělá co? → příkaz `/gp`

Nativní mapování tlačítko→akce si Luanti drží interně a liší se podle
ovladače. Zjistíš ho takhle:

1. Ve hře napiš do chatu **`/gp`** (zapne diagnostiku).
2. Uprostřed obrazovky se ukáže živě: výchylka levé páčky `L(x,y)` a seznam
   právě „stisknutých" akcí (`jump aux1 dig …`).
3. Zmáčkni postupně každé tlačítko na ovladači a poznamenej si, která akce
   se rozsvítí. Tak zjistíš, které tlačítko je střelba (`aux1`), náklon
   (`dig`/`place`), plyn atd.
4. Znovu `/gp` = vypnout.

Když ti nějaká akce sedí na nepohodlném tlačítku, napiš mi mapování z `/gp`
a **přemapuju herní akce** na ergonomičtější tlačítka (mod si určuje, co která
akce dělá — takže to jde doladit bez externího nástroje).

## Řešení potíží

- **Ovladač nereaguje** → připoj ho *před* startem hry; zkus `joystick_type =
  xbox` (pro 360) nebo `ps5` (pro DualShock 4/5) místo `auto`.
- **Kamera ujíždí sama** → zvyš `joystick_deadzone` (např. 3500).
- **Otáčení moc rychlé/pomalé** → uprav `joystick_frustum_sensitivity`.
- Přepínání ovladačů: `joystick_id` (0 = první).

> Starý `profiles/aerowars-xbox.amgp` (AntiMicroX) zůstává pro platformy, kde
> nativní joystick nestačí — na macOS ale používej nativní cestu výše.
