-- Indexek és egyediség a ttt_server adatbázishoz (futtasd egyszer phpMyAdminban / mysql CLI-ben)
-- A kód név / serial alapján keres, ezek nélkül minden lekérdezés teljes táblaolvasás.

ALTER TABLE `users`        ADD UNIQUE KEY `uq_users_serial` (`Serial`);
ALTER TABLE `weapons`      ADD INDEX `idx_weapons_owner` (`owner_name`, `is_equipped`, `slot_type`);
ALTER TABLE `owned_skins`  ADD INDEX `idx_skins_player` (`player_name`);
ALTER TABLE `inventory`    ADD UNIQUE KEY `uq_inventory_owner` (`owner_name`);   -- a /giveitem ON DUPLICATE KEY-hez kell
ALTER TABLE `reports`      ADD INDEX `idx_reports_active` (`Active`);
ALTER TABLE `report_messages` ADD INDEX `idx_msgs_report` (`Report_ID`);
ALTER TABLE `shop_logs`    ADD INDEX `idx_shoplogs_player` (`player`);
ALTER TABLE `admin_commands` ADD INDEX `idx_admincmd_admin` (`admin_name`);

-- A reports / report_messages táblák utf8mb3-ban vannak, a többi utf8mb4-ben; egységesítés:
ALTER TABLE `reports`         CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
ALTER TABLE `report_messages` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- Név-egyediség a login rendszerhez (egy név = egy fiók). Ha már van két azonos név a táblában,
-- előbb nevezd át az egyiket, különben az ALTER hibát ad.
ALTER TABLE `users` ADD UNIQUE KEY `uq_users_name` (`Név`);
