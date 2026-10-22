# ttt_mc (ttt_minecraft_b5) – MTA:SA resource

A Garry's Mod TTT pálya (*ttt_minecraft_b5*, Finniespin) teljes konverziója MTA:SA-ra: geometria, textúrák,
besütött fények, **az eredeti brush-okból generált collision**, és a pálya teljes Source entitáslogikája
(teleportok, csapdák, ajtók, gombok, traitor szoba, traitor tester, kemence → gyémántblokk → innocent win…).

Lépték: 1 Minecraft blokk (32 Source unit) = 1 méter. A GTA ped így mindenhol átfér, a sebességek és a gravitáció
nagyjából megegyeznek a GMod-dal.

## Telepítés (ttt-core szerver)

1. A `ttt_minecraft_b5` mappa a szerver `resources` mappájába kerül, a `ttt-core` és a többi `ttt-*` mellé.
2. `mtaserver.conf`: `<resource src="ttt_minecraft_b5" startup="1" protected="0" />` (vagy konzolból `start ttt_minecraft_b5`).
3. Ennyi. A pálya magától felismeri a `ttt-core`-t (`Config.MODE = "auto"`):
   - minden `ttt:onRoundStart`-nál resetel (mint a GMod-os CleanUpMap), és **minden szereppel rendelkező játékost**
     a pálya 35 eredeti spawnpontjára szór szét;
   - a játékos addig le van fagyasztva, amíg a kliensén be nem töltött a pálya és alatta a collision
     (különben átesne a pályán);
   - `ttt:onRoundEnd` → a pálya RoundEnd logikája; a kör végén mindenki ott marad, ahol van.
   - Ha a pálya kör közben indul, a futó kör játékosait azonnal átrakja.

Nincs `ttt-core`? Akkor `standalone` módban fut: a pálya önmagában működik, egy admin a `/mcmap` paranccsal teheti
rá a játékosokat.

Parancsok – **csak adminoknak** (`admin` element data ≥ 1, mint a ttt-admin/ttt-int/ttt-replay parancsainál; ACL
Admin/Console csoport; vagy szerver konzol). Nem adminnak: „Ehhez admin jog kell!”, és semmi nem történik.
- `/mcmap` – te a pályára, `/mcmap [név]` – a megadott játékos, `/mcmap all` – mindenki (kör közben csak akinek van szerepe)
- `/mcreset` – a pálya újraindítása
- `/mcdia` – a gyémántércek / arany- és gyémántblokk helye (csak a parancsot kiadó látja; konzolból a konzolba)
- `/gotogold` – teleport az aranyblokkhoz (csak Főadmin = 2-es szinttől, `GOTOGOLD_ADMIN_LEVEL`)
- `/gotodia` – teleport a kész gyémántblokkhoz, ha még nincs: a legközelebbi gyémántérchez; `/gotodia [1-9]` – az adott
  érchez (csak 3-as admintól, `GOTODIA_ADMIN_LEVEL`)

A pálya a GTA világ fölött van (`Config.OFFSET = {0, 0, 600}`, dimension 0). A köd, az ég és a délidő **csak a pályán**
aktív, máshol (pl. Grove Street) minden marad a normál GTA. A pálya a `ttt-replay` nézői dimenziójában is látszik.

## Irányítás

- **Q** – a kézben lévő fegyver eldobása; **F** a földön lévő fegyverre: csere („[F] Felvétel”).
- **F** – használat: gombok, karok, ajtók; blokkok (arany, gyémántérc, agyag, tégla, gyémántblokk) felvétele/letevése.
  A cipelt blokk követi, merre nézel, így bele lehet tenni a kemencébe. (Az E a fegyverváltás.)
- **Traitoroknak**: a traitor gombok piros négyzetként látszanak. Célozz rá, és **F**.
- Fegyverrel / ütéssel törhetők a törhető elemek („Lődd vagy üsd szét a vasércet!”).
- Létra: a fal felé = fel, a faltól el = le, oldalra = oldalazás, ugrás = elengedés.

## Kapcsolat a szerver resource-jaival (`server/bridge.lua`)

| Pálya funkció | Szerveren |
|---|---|
| traitor tester, traitor gombok, traitor szoba | `tttRole` element data (`Traitor` / `Detective` / `Innocent`) – ttt-core |
| kreditbolt szoba (1 kredit → random traitor tárgy) | pénz: 1 kredit = `Config.CREDIT_PRICE` ($1000) – mint a ttt-shop |
| gyémántblokk a világítótoronyba → innocent win | amikor a pálya átteleportál mindenkit az „end”-be, lefut a ttt-core innocent win-je („Az Innocentek győztek!”, kör vége) – `MAP_WIN` |
| csapdával ölés | `killPed(áldozat, csapdát aktiváló traitor)` → ttt-core hulla + ttt-replay esemény |
| pálya fegyverspawnok | MTA pickupok (mint a ttt-int pickupjai), felvétel után eltűnnek |
| traitor szoba vásárlás naplózása | `shop_logs` tábla (`ttt-sql`) + Discord (`ttt-dc` `sendMoneyLog`) – mint a ttt-shop |
| halál a pályától (láva, csapda, leesés) | a ttt-core hullán olvasható ok („Tűz / láva”, „Esés”, „Leesett a pályáról”, „Csapda (pálya)”) |
| admin jog | `admin` element data (ttt-login/ttt-admin), a kliens nem írhatja át (lásd v17) |

Events: `onTTTMapWin(team)`, `onPlayerMinecraftMapReady` (source = játékos, akinek betöltöttek a modellek).
Exportok: `getSpawnPoints()`, `getWeaponSpawns()`, `getMapInfo()`, `resetMap()`, `roundPreparation()`, `roundStart()`,
`roundEnd()`, `fireInput(target, input, param, delay)`.

## Beállítások (`config.lua`)

`MODE`, `OFFSET`, `DIMENSION`, `INTERIOR`, `USE_KEY`, `CREDIT_PRICE`, `FALL_KILL_MARGIN`, `WORLD_SHADER`
(a pálya textúra × besütött fény + saját köd shaderrel, pont mint GModban), `MAP_FOG` (a GMod-os köd 62–109 m),
`FAR_CLIP` (látótáv, az egész pályát le kell fednie), `DECAL_PULL` (érc-decalok / sínek z-fight elleni eltolása),
`LOCK_TIME` (dél + tiszta idő), `TEXTURE_FILTERING` (mipmap a távolban, közelről éles pixelek), `ZONE_CULLING`
(csak az a pályarész látszik, ahol a kamera van – mint a Source PVS), `EDGE_FIX` (1 blokkos peremek javítása),
`SPAWN_WEAPONS` / `SPAWN_AMMO` / `WEAPON_SPAWN_CHANCE` / `PICKUP_HEIGHT` (pálya fegyverspawnok), `USE_HINTS`,
`JUMP_ASSIST`, `DROP_ASSIST_RANGE`,
`SPAWN_WEAPONS`, `MELEE_DAMAGE`, `LADDER_SPEED`, `DEBUG` (minden I/O esemény a konzolra).

## Ami működik

- Teljes pálya: 233 modell, 87 textúra, ~110 ezer háromszög, ore decalok, Minecraft égbolt-színek, mozgó felhők
- Collision az eredeti brush-okból (≈4000 box + mesh), playerclip falakkal együtt, felületanyagokkal (fű, kő, fa, üveg…)
- Mind az 5 trigger_teleport és a 75 point_teleport (nether portál, kamu portál csapda, véletlen arany/gyémánt
  helyek, win teleportok)
- Ajtók, karok, csapóajtók, gombok (lock/unlock, wait), func_movelinear, minecart TNT csapda útvonallal
- Traitor szoba (traitor check ajtó + kill zóna), traitor tester (aranyblokk a crafting asztalra → feloldás,
  piros/zöld lámpa), kreditbolt szoba, összes traitor gomb (víz → láva, nether sziget, üvegpadló, dungeon üveg,
  tester szabotázs)
- Kemence: 9 gyémántérc → gyémántblokk → világítótorony → innocent win (+ villám effekt, fade)
- Víz (GTA vízzel, lehet úszni), létrák, push zónák (sziget széle), kill zónák, tüzes sebzés, robbanások
- Törhető érc/üveg, game_text / ttt_game_text üzenetek, köd, fáklyafények
- Körönkénti teljes reset (mint a TTT `CleanUpMap`)

## Ismert eltérések a GMod-hoz képest

- **Fizika egyszerűsítve**: a blokkokat fel lehet venni és le lehet tenni, és leejtve egyenesen leesnek, de nem
  gurulnak, nem dobhatók, nem tolhatók. A minecartok helyben állnak (lőhetők/törhetők).
- **Fénykapcsolás**: a fények be vannak sütve a modellekbe, ezért a `Trap_Nether_Light TurnOff` nem sötétít.
- **Hangok**: a pálya HL2/CS:S hangfájlokat használ (szél, kemence, zene stingerek), ezek nincsenek a BSP-ben.
  Ha megvannak, tedd őket a `sounds/` mappába ugyanazzal az útvonallal (pl. `sounds/ambient/wind/windgust.wav`),
  és a konverter `make_meta.py`-a felveszi őket a meta.xml-be.
- `trigger_gravity`, `logic_collision_pair`, `func_clip_vphysics`: csak a Source fizikára hatnak, itt nincs hatásuk.
- Kreditbolt szoba: a flaregun / teleporter / decoy / radio helyett GTA megfelelőt ad (molotov / páncél /
  könnygáz / gránát), mert ezeknek nincs GTA-s változata.
- Kiesés: csak az hal meg, aki **a pályán volt** és leesett róla (12 m-rel a legalsó pont alá).

## Első éles teszt: erre figyelj

Kör indulásakor a szerver konzolban ezt kell látnod: `[mc] round start: N players placed on ttt_minecraft_b5`.

A modelleket független olvasóval visszaellenőriztem, a pályát renderelve megnéztem, a logikát pedig 70 forgatókönyvvel
teszteltem szimulált MTA API-val, a szerver valódi `ttt-core` és `ttt-replay` kódjával együtt futtatva. Élő MTA kliensben viszont nem futott. Ezért első alkalommal nézd meg:

1. az X-tengely körül forgó csapóajtók és karok jó irányba nyílnak-e (ha fordítva, a `server/classes.lua`
   `doorMoveTo`-ban az `ax == 1` ágon kell előjelet váltani);
2. a `client/world.fx` shader (ha a gép nem támogatja, a GTA rajzolja a pályát besütött fénnyel; ilyenkor
   `/debugscript 3` figyelmeztet);
3. betöltés után mindenhol megvan-e a collision (`/debugscript 3` hibákat ír, ha bármi nem töltődik be).

## Javítások a 2. játékbeli teszt után (v6)

- **Túl világos / sárgás-zöld pálya, fekete játékos**: a modellek eddig a GTA dinamikus fényét is megkapták a besütött
  fény fölé. Most nincs GTA-fény: a pálya színe textúra × az eredeti Source lightmap (`client/world.fx`), a játékos
  pedig a collision fényértékéből kapja a világosságot (eddig 0 volt → fekete).
- **Szeletekre vágott pálya, eltűnő/ugráló részek, fehér ég**: a látótáv 114 m-re volt vágva (GMod köd), a GTA köd
  viszont nem takarta el a vágást. Most a látótáv 400 m, a ködöt a shader rajzolja pontosan (62–109 m, a horizont
  színébe), az ég a skybox színeiből készült GTA égbolt-gradiens.
- **Vibráló textúrák a távolban**: mipmap-szűrés (közelről továbbra is éles Minecraft pixelek).
- **Z-fight**: az érc-decalok és a sínek külön textúrát kapnak, amit a shader a kamera felé húz; a decalok 3 cm-re
  vannak a blokktól.
- Kivettem a víz/üveg „no depth write” shadert (sorrendtől függően villogást okozhatott).

## Javítások a 3. játékbeli teszt után (v7)

- **1 blokkos lépcsők**: a GTA-s karakter ütközése 3 gömb; a középső gömb egy 1 m magas blokk peremét „talajnak”
  vette, ezért a blokk mellett kicsit megemelkedett (és nem tudott rendesen felugrani), a perem lelépésénél pedig
  félig a blokkban lógva maradt. A kliens ilyenkor leveszi a peremről: elhúzza a lépcsőtől, illetve ha a blokk felé
  megy, felsegíti rá (mint GModban a blokk szélén).
- **Fegyverek**: a lőszer-spawnok GTA-ban fegyverként jelentek meg (240 pickup) – a lőszert kikapcsoltam, körönként a
  fegyverhelyek fele kap fegyvert (véletlenszerűen), a traitor szoba tárgyai mindig. A fegyverek a padlón vannak
  (GModban leesnek a földre), nem a levegőben.
- **Nether „víz alatti” kamera**: a GTA víz egy sík, ami alatt minden víz alatt van – az óceán a teljes pálya alatt
  volt, így a nether is. A vizet most a kliens hozza létre, és csak akkor, ha a kamera a víz pályarészén van.
- **Fekete doboz a pálya tetején**: ez a zárt győzelmi szoba belseje volt. GModban a Source láthatósági rendszere
  (PVS) elrejti, most a pálya is így működik: 4 zóna (felszín, nether, győzelmi szoba, tároló), és mindig csak az
  látszik, amelyikben a kamera van (az ütközés megmarad).

## Javítások a 4. játékbeli teszt után (v8)

- **Gombok, karok, ajtók, blokkok**: a használható dolgokra nézve megjelenik a `[F] Használat / Ajtó / Felvétel`
  felirat. A célzás az entitás dobozával megy (a karok legtöbbje egy láthatatlan gomb a kar előtt – eddig a fal
  „elkapta” a célzást).
- **Kemence, crafting asztal, világítótorony, pigman kemence**: a felvett blokkot (gyémántérc, aranyblokk,
  gyémántblokk, agyag) elég a cél közelében (2,5 m) letenni `F`-fel, és a helyére kerül.
- **Ugrás 1 blokkra**: ha 1 blokkos (0,55–1,6 m) lépcső előtt ugrasz, a karakter egy rövid ugrással felkerül rá
  (a GTA lassú kapaszkodó animációja helyett). Vízből a partnak úszva automatikusan kimászik.
- **Beragadás**: ha a karakter 0,4 mp-ig mozdulatlanul „lóg” egy peremen, a szkript lelöki; 1,5 mp után a
  legközelebbi szabad padlóra teszi.
- **Traitor szoba teteje**: a csalásellenes trigger teteje pont a tető síkja volt; a Source ezt nem számítja
  érintésnek, most a pálya sem.
- **Minecartok**: GModban fizikai tárgyak, amik leesnek a sínre / egymásra; most is a nyugalmi helyükön
  jelennek meg (a két egymás fölötti kocsi GModban is egymásra esik).

## Javítások az 5. játékbeli teszt után (v9)

- **Zárt karok**: a traitor tester karjai/gombjai zárva vannak, amíg valaki meg nem találja és a crafting asztalra
  nem teszi a kis aranyblokkot (tábla: „Search for the small golden block…”), utána pedig a két vasajtónak csukva
  kell lennie. Zárt gombra nézve most „Zárva” látszik az `[F]` helyett.
- **GTA mászás**: magas (2–3 blokkos) falakra mászás és ugrás közben a rásegítés nem nyúl a karakterhez.
- **Minecart**: nem lehet felvenni (GModban is túl nehéz), csak a blokkokat (`CARRY_MAX_SIZE`).

## Javítások a 6. játékbeli teszt után (v10)

- **Létrák** (Minecraft/GMod módra): a létra felé menve felmászol, a tetején rálépsz a blokkra; ha elengeded a
  gombokat, a létrán maradsz; háttal / hátrafelé menve (vagy a tetejéről a szélén lelépve) lemászol; ugrással
  elengeded. Az egymás melletti létrák nem zavarják egymást.
- **Vízből kimászás**: úszás közben bármelyik blokkra, aminek a teteje a lábad és kb. 1,9 m között van (a víz alatti
  sekély blokkokra és a partra is), automatikusan kimászik a karakter, ha arra úszol.
- **Megemelkedés a lépcső mellett**: a peremre „felült” karaktert visszateszi a padlóra.
- **Beragadás két blokk közé**: a lassú lecsúszást is beragadásnak veszi (0,5 mp után lelöki, 1 mp után a
  legközelebbi padlóra teszi); GTA-s mászás közben csak 2,5 mp után.
- **Túl világos pálya, fehér ég**: a GTA időjárás-színszűrője (LS napsütés délben) sárgás fényt adott az egész
  képre; a pályán most ki van kapcsolva (`NO_COLOR_FILTER`), a fényerő állítható (`MAP_BRIGHTNESS`).
- **Zónák**: a láthatóságot a játékos feje alapján dönti el, nem a (falba is belelógó) harmadik személyű kamera.

## Javítás: győzelmi teleport (v11)

- A győzelmi szobában egy hatalmas láthatatlan „player clip” doboz (`Win_Hold`) van: GModban az oda teleportált
  játékosok beleragadnak, 9 mp-ig egy helyben állnak (amíg a fények/villámok mennek), aztán a doboz eltűnik.
  GTA-ban az ütközés kilökte a játékost a doboz tetejére/oldalára, onnan leesett a semmibe (halál). Most a szerver
  a dobozban lévő játékosokat a helyükön tartja (lefagyasztja), amíg a doboz meg nem szűnik – mint GModban.

## Javítások (v12)

- **Hiányzó textúrák**: a térképkészítő „nodraw”-t tett azokra a blokkoldalakra, amiket GModban senki nem lát
  (platformok alja, rejtett oldalak). GTA-ban a mászással ezek látszanak – az ilyen, szabad térre néző oldalak
  (≈5100 db) most a blokk saját textúráját kapják.
- **Létrák**: a mozgás a kamerához képest megy: a fal felé = fel, a faltól el = le, balra/jobbra = oldalra a
  létrán (széles / egymás melletti létrák), semmi = a létrán maradsz, ugrás = elengedés. A fal oldalát a pálya
  geometriájából számolja, nem a karakter forgásából.

## Javítások (v13)

- **Szövegek**: a pálya üzenetei GTA-hoz igazítva (`TEXT_REPLACE`): „Crowbar the iron ore!” → „Shoot or punch the
  iron ore!”, a traitor szoba tárgyainál a GTA-s megfelelő (könnygáz, gránát, páncél, molotov). Ugyanaz az üzenet
  20 mp-en belül nem ismétlődik a chatben.
- **Hangok** (`SOUND_EFFECTS`): felvétel, letevés, behelyezés (kemence: lángolás, világítótorony-láda: nyikorgás),
  gombok/karok kattanása, zárt gomb, láda. A hangokat a konverter generálja (`make_sfx.py`), nincs bennük
  külső hangfájl.

## Magyarítás (v14)

- A játékban megjelenő összes szöveg magyar: a pálya saját üzenetei (`TEXT_REPLACE` a `config.lua`-ban, a
  képernyő közepén és a chatben is), a súgók és a szerver üzenetei. A pálya tábláinak felirata a textúrákban van
  (Minecraft-képek), az angol marad.

## Használat gomb (v15)

- A használat (gombok, karok, ajtók, blokkok felvétele/lerakása, traitor gombok) az **F** billentyű (`USE_KEY`),
  mert az E a fegyverváltás.

## Javítások (v16)

- **Víz alacsony plafon alatt** (barlangi járatok, sziget alatti rések): GTA-ban az úszó karakternek ~1,75 m kell a
  víz fölött, egy blokk magas plafon alatt a víz alá nyomta és beragadt. Ezeken a helyeken nincs GTA-víz, a
  karakter a meder alján sétál.
- **Törhető blokkok**: a lövések sebzése a GMod TTT fegyvereié (`BREAK_DAMAGE`), a shotgun egy lövése az összes
  sörét (88), ököl/ütés 25 (mint a feszítővas).
- **Hangok**: behelyezésnél akkor is szól (kemence, asztal, láda), ha nem `F`-fel, hanem besétálva teszed be;
  Minecraft-stílusú hangok véletlen hangmagassággal. Saját hangokhoz cseréld le a `sounds/sfx/*.wav` fájlokat
  azonos nevűre.
- **Elveszett blokkok**: egy elengedett blokk legfeljebb `SETTLE_MAX_DROP` (6 m) mélyre eshet (távoli játékosnál a
  GTA nem tölti be az ütközést, és a blokk a pálya alá zuhanhatott).
- **`/mcdia`** (admin): kiírja a gyémántércek, az aranyblokk és a gyémántblokk helyét és távolságát, és hogy hány
  érc van már a kemencében. A 9. érc mindig a barlang vasérc-blokkjában van, azt szét kell lőni/ütni.

## Kompatibilitás a szerver összes resource-ával + admin jogok (v17)

A 14 szerveroldali kóddal rendelkező `ttt-*` resource (a ttt-hud csak kliens) valódi kódja együtt futott a pályával a tesztben (kör indítás, halál, hulla,
győzelem, következő kör, admin parancsok), hiba nélkül.

- **Admin parancsok ténylegesen csak adminoknak**: `/mcmap`, `/mcreset`, `/mcdia` – a standalone módban sincs többé
  kivétel. A `/mcdia` válasza csak a kérdezőnek megy (konzolról korábban mindenkinek kiírta az ércek helyét).
  Minden admin parancs a szerver logba kerül.
- **Csalás elleni védelem (az egész szervernek)**: MTA-ban a kliens a saját element datáját átírhatja, és a szerver
  ezt elfogadja. Mivel a szerver összes admin parancsa (ttt-admin, ttt-int, ttt-spawn, ttt-replay, ttt-weapon, ttt-core
  és a pályáé is) az `admin` element datát nézi – és a ttt-login kilépéskor el is menti az adatbázisba –, egy csaló
  kliens adminná tehette volna magát. A pálya most minden kliens által küldött változást visszaállít ezeken:
  `admin`, `tttRole`, `money`, `charID`, `accName`, `adminVision`, `chatCss`, `joinTime`, `isCorpse`, `npcName`,
  `corpse:*`, `mc.*` (`Config.PROTECTED_DATA`). A szerver resource-ai (pl. `/setadmin`) ugyanúgy működnek; a
  próbálkozás a szerver logba kerül, és az online adminok chatüzenetet kapnak. Kikapcsolás: `PROTECT_ELEMENT_DATA = false`.
- **ttt-core hullák**: a pálya okozta halálnál a hullán a „Fegyver” sor olvasható okot mutat a GTA-s
  „Explosion”/„Flamethrower” helyett.
- **ttt-admin `/freeze`**: a pálya mozgássegítői (lépcső, beragadás elleni tolás, létra, trigger_push) fagyasztott
  játékost soha nem mozdítanak; a győzelmi szoba „hold”-ja nem olvasztja ki, akit admin fagyasztott le, a ttt-core kör
  végi kiolvasztása után pedig a hold-ban lévőt visszafagyasztja (különben leesne).
- **ttt-core parkoló**: a halott játékosokat a ttt-core 0,0,-100-ra fagyasztja – ehhez a pálya nem nyúl.
- **ttt-report**: amíg a report ablak le van zárva (`toggleAllControls(false)`), a pálya nem kapcsolja vissza az ugrást.
- **ttt-chat / ttt-skin / menük**: gépelés közben (`guiSetInputEnabled`) és MTA ablak mellett az F nem használ semmit.
- **ttt-replay**: a néző (saját dimenzióban, láthatatlanul) nem kap mozgássegítést; a pályarész-kiválasztás a
  visszajátszott kamerát követi; az ajtók, ércek, blokkok is látszanak a nézőnek.
- **ttt-int `/int`**: más interiorban a pálya triggerei, holdja és segítői nem hatnak a játékosra.
- **Kör közbeni `/mcmap`**: csak ha tényleg fut ttt-core kör (van valakinek szerepe), akkor korlátoz szerepre.

A barátod resource-aiban talált (a pályától független) hibák, amiket érdemes javítani:
- `ttt-hud/sourceC.lua` vége és `ttt-core/sourceC.lua`: mindkettő `bindKey("m", ...)`-szel váltja a kurzort, így az M
  egyszerre kétszer vált – a kurzor beragadhat. A ttt-hud-ban a megjegyzés szerint már törölni akarták: a ttt-hud
  utolsó 3 sorát (`bindKey("m", ...)`) kell kitörölni.
- `ttt-int` és `ttt-spawn` ugyanazokat a parancsokat regisztrálja (`/cspawn`, `/cweapon`, `/showspawns`, `/delspawn`):
  ha mindkettő fut, egy parancs mindkettőben lefut. Elég az egyiket futtatni (a ttt-int az újabb).

## Változások (v18) – a resource neve mostantól `ttt_mc`

- **Statikus minecartok kivéve** (`REMOVE_STATIC_MINECARTS`): a pályán álló 7 fizikai kocsi nincs többé; a traitor
  karral elindítható TNT-s kocsija (`Trap_Creeper_Cart`) megmaradt.
- **Fegyverkorlát** (`WEAPON_LIMIT`, `server/weapons.lua`): legfeljebb 1 fő fegyver (shotgun, Uzi/MP5/Tec-9,
  AK/M4, puskák, nehézfegyverek) + 1 pisztoly. Ha új fegyvert kapsz egy kategóriában, amiben már van (felvétel,
  ttt-shop, admin – mindegy honnan), a régi a lábad elé esik a teljes lőszerével. A saját eldobott fegyveredet 1,5
  mp-ig nem veszed fel újra; utána odasétálva visszacserélheted. Kés, ütőfegyver, gránát nem számít.
- **Vasérc / gyémántérc blokkok** (`BREAK_HITS`): vasérc = 5 lövés gépkarabéllyal (AK/M4), 3 shotgunnal, 10
  pisztollyal, 5 ütés kézzel (SMG 7, puska 3). A gyémántérc blokk ennek a duplája. Egy shotgun-lövés egynek számít.
- **`/gotogold`**: Főadmintól (2) felfelé teleportál az aranyblokkhoz (a tetejére).
- **A győztest a ttt-core dönti el**: a pálya nem zárja le a kört és nem ír ki győztest.
- **Kivett üzenetek**: a „Welcome to ttt_minecraft…” és a „Made by Finniespin…” szöveg soha nem jelenik meg (`TEXT_HIDE`).

## Változások (v19) – fegyvercsere megerősítéssel, eldobás Q-val

- **Nincs automatikus csere**: ha a pálya egy fegyverére (vagy egy eldobott fegyverre) lépsz, és ugyanabban a
  kategóriában (fő fegyver / pisztoly) már van nálad egy másik, megjelenik: **„[F] Felvétel: M4 (helyette eldobod:
  AK-47)”**. F-re cseréled: az új a kezedbe kerül, a régi pedig a teljes lőszerével a helyére. Ha a kategória üres,
  vagy ugyanaz a fegyver (lőszer), automatikusan felveszed, mint eddig. Ajtó / kar / blokk előnyt élvez az F-nél.
- **Q – fegyver eldobása** (`DROP_KEY`): a kézben lévő fegyver (kés, gránát is) eléd esik a lőszerével. A GTA Q-s
  fegyverváltása nem fut le; az egérgörgő és az E továbbra is vált. A saját eldobott fegyvered 1,5 mp-ig nem veszed
  fel újra; utána, ha a helye üres, rálépve visszakapod.
- Más forrásból kapott fegyvernél (ttt-shop, admin, ttt-int pickup) nincs mit megerősíteni: ott a régi a lábad elé
  esik a lőszerével (mint v18-ban).

## Változások (v20)

- **Innocent win az end-nél** (`MAP_WIN = "end_teleport"`): a kész gyémántblokk a világítótoronyba → a pálya
  ~7 mp múlva mindenkit átteleportál az end-be; amikor az első játékos megérkezik, lefut a ttt-core innocent win-je
  („Az Innocentek győztek!”, a ttt-core lezárja a kört és 10 mp múlva újat indít). Ha valamiért senkit nem
  teleportál át, 15 mp után akkor is. `"immediate"` = már a berakáskor, `false` = a pálya nem dönt.
- **`/gotodia`** (3-as admintól): a kész gyémántblokkhoz, vagy ha még nincs, a legközelebbi gyémántérchez teleportál;
  `/gotodia 1`…`9` egy adott érchez.

A modellek újragenerálásához lásd a `bsp2mta_converter` mappát.
