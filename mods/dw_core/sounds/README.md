# Zvuky DoggioWars

Hra si soubory najde sama podle jména (`music.lua`). Chybějící soubor
znamená ticho, ne chybu. Formát je vždy **Ogg Vorbis**, smyčky musí
navazovat bez cvaknutí.

## Témata ostrovů (`dw_music_<biom>.ogg`)

Stereo, 60–120 s, smyčka. Při přiblížení k ostrovu se 6 s crossfadem
přepne z předchozího tématu.

| Soubor | Biom |
|---|---|
| `dw_music_sky.ogg` | mezi ostrovy, volná obloha |
| `dw_music_verdant.ogg` | zelený ostrov, louky a lesy |
| `dw_music_glacial.ogg` | ledová plošina |
| `dw_music_volcanic.ogg` | sopka, láva |
| `dw_music_atoll.ogg` | korálový atol, laguna |
| `dw_music_mycelial.ogg` | houbový, svítící spory |
| `dw_music_barren.ogg` | holá skála, kamenný strážce |
| `dw_music_jungle.ogg` | džungle |
| `dw_music_desert.ogg` | poušť |
| `dw_music_crystal.ogg` | krystalové jehly, elektřina |
| `dw_music_ashen.ogg` | spálený, popel a uhlíky |
| `dw_music_savanna.ogg` | savana |
| `dw_music_swamp.ogg` | bažina, bahno |

## Bytosti (`dw_creature_<druh>.ogg`)

**Mono** (jinak engine neumí poziční zvuk), 10–30 s, smyčka. Zvuk je
připnutý k hlavě bytosti a se vzdáleností slábne, takže se do tématu
ostrova domíchá, když se k bytosti přiblížíš.

| Soubor | Bytost |
|---|---|
| `dw_creature_dragon_fire.ogg` | ohnivý drak |
| `dw_creature_dragon_ice.ogg` | ledový drak |
| `dw_creature_dragon_water.ogg` | vodní drak |
| `dw_creature_dragon_mud.ogg` | bahenní drak |
| `dw_creature_dragon_electric.ogg` | elektrický drak |
| `dw_creature_worm.ogg` | písečný červ |
| `dw_creature_guardian.ogg` | kamenný strážce |
| `dw_creature_jelly.ogg` | medúza |
| `dw_creature_jelly_glow.ogg` | svítící medúza |
| `dw_creature_whale.ogg` | nebeská velryba |

Hlasitost: Nastavení → Vše → `dw_music_volume`, `dw_creature_volume`.
Ve hře `/music` hudbu vypne/zapne.
