# MTA:SA TTT szerver – projekt áttekintés és állapot

*Frissítve: 2026-09-11 – kódátnézés, optimalizálás és Paddy kérései (login, fixadmin, opt rendszer, replay) után. Az eredeti fájlok a `_backup_original/` mappában vannak.*

## Architektúra

12 MTA resource + 1 MySQL adatbázis (`ttt_server`). A resource-ok az `exports` rendszeren keresztül beszélnek egymással, a közös állapot a játékos `elementData`-jában él:

| Kulcs | Jelentés | Ki írja |
|---|---|---|
| `admin` | admin szint 0–3 (0 játékos, 1 Admin, 2 Főadmin, 3 Tulajdonos) | ttt-login (DB-ből), ttt-admin |
| `tttRole` | `"Traitor"` / `"Detective"` / `"Innocent"` / `false` | ttt-core, ttt-admin |
| `charID`, `accName`, `money` | DB-s fiók adatok | ttt-login |
| `adminVision` | admin látmód be/ki | ttt-admin |
| `joinTime` | belépés unix ideje (scoreboard játékidő) | ttt-scoreboard |
| `isCorpse`, `corpse:*` | hulla ped adatai | ttt-core |

Függőségi sorrend indításnál: **ttt-sql → ttt-login → ttt-admin → ttt-core → többi**.

## Resource-ok

**ttt-sql** – MySQL kapcsolat (`dbConnect`), újrapróbálkozás 5 mp-enként. Exportok: `dbQueryExec` (INSERT/UPDATE), `getDatabaseHandler` (a többi resource ezzel futtat callback-es `dbQuery`-t). A kapcsolati adatok a `meta.xml` `<settings>`-ben vannak, `mtaserver.conf`-ból felülírhatók.

**ttt-login** – Serial alapú automatikus regisztráció/bejelentkezés (`users` tábla), pénz és adminszint betöltése, spawn. **Egy név = egy fiók**: az első belépéskori nick lesz a fiók neve (ha szabad, különben `Guest_XXXX`), később mindig erre a névre áll vissza a játékos, névváltás tiltva (`/changename [név]` csak szabad névre), ugyanazzal a serial-lal második kliens kick, névbitorló kick, amikor a valódi tulaj belép. Mentés kilépéskor, resource leálláskor és 5 percenként. Betöltés után `ttt:onPlayerLoaded` eventet küld.

**ttt-core** – A játékmenet: körök indítása (min. 2 játékos), szerepek kiosztása (1 Traitor, 3+ főnél 1 Detective), köridő (150 mp, `/setttt 120-240`), győzelem-ellenőrzés, hullák (`createPed`) a halál helyén kattintható infóval (név, szerep, fegyver, idő), Traitor chat (`/tc`). Kliens: visszaszámláló, hulla infó panel, `M` = kurzor.

**ttt-admin** – Admin parancsok: `/setadmin`, `/a`, `/fa`, `/setmoney`, `/givemoney`, `/revokemoney`, `/getpos`, `/freeze`, `/kick`, `/teams`, `/setteam`, `/sethp`, `/reveal` (admin látmód), `/giveskin`, `/pskin`, NPC tesztek (`/npc`, `/npcrole`, `/npcadmin`). Chat prefix rang szerint. Minden admin akció az `admin_commands` táblába és Discordra megy. Tulajdonos jog **serial** alapján (`OWNER_SERIALS`); `/fixadmin` bármikor visszaadja a 3-as szintet, de **csak** az ott felsorolt serialoknak.

**ttt-dc** – Discord híd: `fetchRemote` POST a `http://127.0.0.1:3000/adminlog` címre (a Node.js bot **nincs a repóban**). Exportok: `sendAdminLog`, `sendMoneyLog`, `sendSkinLog`. Teszt: `/testdc`.

**ttt-hud** – Cyberpunk stílusú DX HUD (szerep, HP, armor, pénz, idő, ping), szerep-bejelentés animáció, nametag rendszer rang-színnel és admin látmóddal. Az alap GTA HUD el van rejtve.

**ttt-scoreboard** – `TAB` scoreboard: státusz, rang+név, pénz, játékidő (szerveroldali `joinTime`-ból), ping.

**ttt-report** – `/report [név] [indok]` → `reports` + `report_messages` tábla. Adminoknak HUD indikátor számlálóval, kattintásra terminál-stílusú panel: lista, chat, lezárás. Minden szerveroldali event admin-ellenőrzött.

**ttt-shop** – `F3`: Traitor Black Market / Detective Armory. Fülek: SHOP (fegyver, armor, medkit), SKILLEK (ped stat fejlesztés), SKINEK (→ ttt-skin). A tárgylista a `shared_items.lua`-ban közös; a kliens csak indexet küld, az árat a szerver nézi.

**ttt-skin** – `F4`: skin bolt a ruhabolt interiorban, preview peddel, VÁSÁRLÁS/MEGVÁSÁROLVA fülekkel. Egyedi modellek (Darth Maul, Ezio, Chiss, Gran, Weequay, Clay) DFF/TXD cserével. Tulajdon az `owned_skins` táblában, szerveroldali cache-sel.

**ttt-weapon** – Perzisztens fegyver-inventory (`weapons` tábla): `F2` drag&drop GUI, 20 táska-slot + 5 aktív slot típuskorlátozással, fegyverenként serial, durability, sebzés-módosítók (fej/test/kar/láb), buffok (tűz, sokk, méreg, életszívás), átkok. Fejlesztő itemek (`inventory` tábla: opt_adder, opt_changer, curse_remover) húzással a fegyverre. Admin: `/giveweapon`, `/setweaponstat`, `/delweapon`, `/giveopt [Név] [db]`, `/giveitem [Név] [opt_adder|opt_changer|curse_remover] [db]`, `/stats`. Az aktív slotban lévő fegyverek statjai modell szerint cache-elve (`equippedByModel`), a sebzéslogika a kézben lévő fegyver modelljét ebből olvassa szinkron módon. Itemek: `opt_adder` új opt, `opt_changer` a meglévő optok újrapörgetése (+ buff csere), `curse_remover` átkok törlése.

**ttt-replay** – Kör-visszajátszás. A szerver 5×/mp rögzíti minden játékos pozícióját, forgását, fegyverét, él-e/guggol-e, plusz az öléseket; az utolsó 3 kört tartja memóriában. `/replay [1-3]` (Admin+, csak körön kívül/halottként) a felvételt a kérő kliensre küldi, ahol **kliensoldali pedek** játsszák vissza interpolálva (csak a néző látja): név/szerep/fegyver címke, halál animáció, esemény-lista, SPACE szünet, ←/→ ugrás, NUM+/- sebesség, F7 kamera-követés váltás, `/replaystop`, `/replays` lista.

## Mi készült el a 2026-09-10-es átnézésben

Biztonság: a shop/skin/reroll/upgrade eventek már nem hisznek a kliensnek (ár, ingyenesség, költség, oszlopnév szerveroldalon dől el); SQL injection a `/setweaponstat`-ban megszűnt (whitelist); `/fixadmin` (bárkinek 3-as admin) és a név alapú „Paddy” admin eltávolítva; report eventek admin-ellenőrzöttek; `/giveweapon`, `/npc` jogosultságot kér; `isPlayerAdmin` precedencia-hiba (mindenki admin volt) javítva.

Működési hibák: duplán regisztrált `onPlayerWasted` és dupla `M` bind (kioltották egymást); halott játékosok sosem kerültek vissza a körbe (fagyva maradtak a térkép alatt); hullák sosem törlődtek; kör közben kilépőnél nem volt győzelem-ellenőrzés; dupla kör-indítás lehetősége; `admin`/`adminLevel` kulcs keveredés (nametag, login, npcadmin); pénz-log `nil` hiba rossz névnél; `owner_id`/`dbid` nem létező oszlop a rerollban; `reloadPlayerWeapons` event nem létezett; `drag_drop.lua` nem látta a `gui_main.lua` lokáljait (halott kód volt) → összevonva; fejlesztő itemek darabszáma fixen 50 volt → DB-ből jön; skin bolt fix koordinátára teleportált kilépéskor → visszavisz; Health Boost / Stealth Walk pénzt vont, de nem adott semmit → „HAMAROSAN”; report ID 500 ms-os időzítő helyett `LAST_INSERT_ID`; scoreboard játékidő a kliens belépésétől számolt → szerveridő; `exports:dbQuery(callback)` (MTA-ban függvény nem megy át exporton) → natív `dbQuery` handlerrel.

Optimalizálás: render handlerek csak nyitott GUI-nál futnak (shop, skin, inventory), `fileExists` cache, `getRealTime` egyszer/frame, összevont `onClientRender` a core-ban, közös segédfüggvények az adminban (~630 → ~330 sor), periodikus pénzmentés, indexek (`ttt_server_indexes.sql`).

## 2026-09-11 – Paddy kérései (Discord)

1. *Login: mentse az admin szintet, pénzt, és ne lehessen két Paddy* → a login már mentett; a név-egyediség új: fióknév serialhoz kötve, névváltás tiltva, bitorló kick, `users.Név` unique index (az `ttt_server_indexes.sql`-ben).
2. */fixadmin maradjon* → visszakerült, de csak az `OWNER_SERIALS` listában lévő serialok használhatják (előtte bárki 3-as admint kapott vele, ráadásul hibás volt – `target` nil).
3. *Opt rendszer néha nem érzékeli az M4-et* → az ok: fegyverváltáskor aszinkron SQL lekérdezés töltötte a statot, ami későn/nem futott le. Most a slotban lévő fegyverek statjai modellenként cache-ben vannak, a találatkor szinkron olvassuk. Belépéskor és minden slot-módosításkor frissül.
4. *Opt forgató nem működik* → az `opt_changer` item eddig nem volt implementálva (csak `opt_adder`); most a meglévő optokat pörgeti újra és a buffot cseréli. `curse_remover` is működik.
5. */giveopt [Név] [mennyiség]* → kész (Admin+), névrészletre is keres; `/giveitem`-mel a másik két item is adható.
6. *Replay rendszer NPC-kkel* → új `ttt-replay` resource (részletek fent). MVP: fegyver a ped kezében nem jelenik meg (kliensoldali pednek nem adható fegyver), csak a címkén; lövés/animáció nincs rögzítve.

## Hátralévő / ismert hiányosságok (teendők)

1. **`ttt_server_indexes.sql` lefuttatása** az adatbázison (a `/giveopt` ON DUPLICATE KEY-hez az `inventory.owner_name`, a névegyediséghez a `users.Név` unique index kell). Az `mtaserver.conf`-ban a `ttt-replay`-t is indítani kell.
2. **Sebzés-rendszer**: szerveroldali `onPlayerDamage` nem cancelelhető → játékos ellen az alap sebzés + custom sebzés is megy. Átállítandó `onClientPlayerDamage` cancel + szerveres számításra. A `mod_head_dmg` jelenleg abszolút sebzés, nem %.
3. **Szerep láthatóság**: a `tttRole` elementData minden klienshez szinkronizálódik → cheat klienssel látható ki a Traitor. Megoldás: `setElementData(..., false)` + saját szerep külön `triggerClientEvent`-tel, admin látmódhoz szerveres lista.
4. **Név helyett serial/charID kulcs** az `owned_skins`, `weapons`, `inventory` táblákban (névváltásnál elveszik minden).
5. Skill fejlesztések (`setPedStat`) nincsenek perzisztálva – újracsatlakozásnál elvesznek, újra megvehetők.
6. Átok-generálás (mikor kap átkot egy fegyver), piac (`is_on_market`), pénzes reroll UI nincs implementálva. Replay: fegyver a ped kezében, lövés-effekt, felvétel mentése fájlba/DB-be (most csak memória, restartnál elveszik).
7. Halott játékosok spectate módja (most csak fagyva állnak a térkép alatt).
8. Report: a bejelentő nem látja az admin válaszát.
9. Jelszó a kódból `mtaserver.conf`-ba: `<setting name="*ttt-sql.db_pass" value="..."/>`.
10. Discord bot forrása nincs a repóban – érdemes mellé tenni (`discord-bot/`).
