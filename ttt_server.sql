-- phpMyAdmin SQL Dump
-- version 5.2.2deb2
-- https://www.phpmyadmin.net/
--
-- Gép: localhost:3306
-- Létrehozás ideje: 2026. Sze 10. 00:20
-- Kiszolgáló verziója: 8.4.10-0ubuntu0.25.10.1
-- PHP verzió: 8.4.11

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Adatbázis: `ttt_server`
--

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `admin_commands`
--

CREATE TABLE `admin_commands` (
  `id` int NOT NULL,
  `admin_name` varchar(64) DEFAULT NULL,
  `command` varchar(32) DEFAULT NULL,
  `target_name` varchar(64) DEFAULT NULL,
  `action_details` text,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- A tábla adatainak kiíratása `admin_commands`
--

INSERT INTO `admin_commands` (`id`, `admin_name`, `command`, `target_name`, `action_details`, `date`) VALUES
(102, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-01-27 10:30:03'),
(103, 'Paddy', 'setadmin', 'Paddy', 'Játékos (0)', '2026-01-27 10:30:19'),
(104, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-01-27 10:33:55'),
(105, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-01-27 10:34:03'),
(106, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-01-27 10:38:20'),
(107, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-01-27 10:43:54'),
(108, 'Paddy', 'setadmin', 'Paddy', 'Játékos (0)', '2026-01-27 10:44:07'),
(109, 'Paddy', 'setadmin', 'Paddy', 'Játékos (0)', '2026-01-27 10:44:36'),
(110, 'Paddy', 'Pénz adása', 'Paddy', '$322', '2026-01-27 10:44:45'),
(111, 'Paddy', 'setadmin', 'Paddy', 'Játékos (0)', '2026-01-27 10:45:20'),
(112, 'Paddy', 'Pénz beállítása', 'Paddy', '$5235423523523', '2026-02-02 10:18:11'),
(113, 'Paddy', 'Pénz adása', 'Paddy', '$1', '2026-02-02 10:18:22'),
(114, 'Paddy', 'Pénz levonása', 'Paddy', '-$1', '2026-02-02 10:18:34'),
(115, 'Paddy', 'Pénz levonása', 'Paddy', '-$1', '2026-02-02 10:18:36'),
(116, 'Paddy', 'Pénz levonása', 'Paddy', '-$1', '2026-02-02 10:18:37'),
(117, 'Paddy', 'Pénz levonása', 'Paddy', '-$111111', '2026-02-02 10:18:40'),
(118, 'Paddy', 'setadmin', 'CCmaster', 'Admin (1)', '2026-02-05 20:38:11'),
(119, 'Paddy', 'setadmin', 'CCmaster', 'Főadmin (2)', '2026-02-05 20:39:52'),
(120, 'CCmaster', 'Pénz levonása', 'Paddy', '-$50', '2026-02-05 20:40:33'),
(121, 'CCmaster', 'Pénz adása', 'Paddy', '$50', '2026-02-05 20:40:46'),
(122, 'CCmaster', 'Pénz beállítása', 'Paddy', '$50', '2026-02-05 20:40:53'),
(123, 'Paddy', 'Pénz adása', 'CCmaster', '$5000000', '2026-02-05 20:46:16'),
(124, 'Paddy', 'Pénz adása', 'Paddy', '$5000000', '2026-02-05 20:46:23'),
(125, 'Paddy', 'setadmin', 'CCmaster', 'Főadmin (2)', '2026-02-05 20:49:28'),
(126, 'Paddy', 'Pénz beállítása', 'CCmaster', '$500000', '2026-02-05 20:57:10'),
(127, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-02-19 01:00:51'),
(128, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-02-19 01:01:08'),
(129, 'Console', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-02-19 01:06:03'),
(130, 'Console', 'setadmin', 'Paddy', 'Admin (1)', '2026-02-19 01:06:05'),
(131, 'Console', 'setadmin', 'Paddy', 'Játékos (0)', '2026-02-19 01:06:08'),
(132, 'Console', 'setadmin', 'Paddy', 'Tulajdonos (3)', '2026-02-19 01:06:10'),
(133, 'Paddy', 'Pénz adása', 'Paddy', '$500', '2026-03-17 17:22:49'),
(134, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-03-17 17:23:35'),
(135, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-03-17 17:23:39'),
(136, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-03-17 17:24:05'),
(137, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-03-17 17:24:09'),
(138, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-03-17 17:26:18'),
(139, 'Paddy', 'Pénz adása', 'Paddy', '$100', '2026-03-17 17:26:35'),
(140, 'Paddy', 'Pénz beállítása', 'Paddy', '$100', '2026-03-17 17:26:40'),
(141, 'Paddy', 'Pénz levonása', 'Paddy', '-$50', '2026-03-17 17:26:51'),
(142, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-03-17 17:29:03'),
(143, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-04-16 22:01:24'),
(144, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-04-16 22:01:36'),
(145, 'Paddy', 'Pénz adása', 'Paddy', '$69', '2026-04-16 22:12:08'),
(146, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-04-16 22:12:20'),
(147, 'DENYHAX', 'setadmin', 'DENYHAX', 'Főadmin (2)', '2026-04-20 21:57:13'),
(148, 'DENYHAX', 'setadmin', 'DENYHAX', 'Admin (1)', '2026-04-20 21:57:21'),
(149, 'Paddy', 'Pénz beállítása', 'DENYHAX', '$5', '2026-04-20 22:00:21'),
(150, 'Paddy', 'Pénz beállítása', 'DENYHAX', '$420', '2026-04-20 22:00:46'),
(151, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-04-20 22:18:05'),
(152, 'Paddy', 'setadmin', 'DENYHAX', 'Tulajdonos (3)', '2026-04-20 23:50:28'),
(153, 'Paddy', 'setadmin', 'DENYHAX', 'Főadmin (2)', '2026-04-20 23:50:29'),
(154, 'Paddy', 'setadmin', 'DENYHAX', 'Tulajdonos (3)', '2026-04-20 23:50:32'),
(155, 'Paddy', 'setadmin', 'DENYHAX', 'Főadmin (2)', '2026-04-20 23:57:45'),
(156, 'Paddy', 'setadmin', 'DENYHAX', 'Admin (1)', '2026-04-20 23:57:46'),
(157, 'Paddy', 'setadmin', 'DENYHAX', 'Játékos (0)', '2026-04-20 23:57:48'),
(158, 'Paddy', 'setadmin', 'DENYHAX', 'Tulajdonos (3)', '2026-04-20 23:57:50'),
(159, 'Paddy', 'setadmin', 'DENYHAX', 'Főadmin (2)', '2026-04-21 00:02:10'),
(160, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-04-21 00:02:23'),
(161, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-04-21 00:02:24'),
(162, 'Paddy', 'setadmin', 'DENYHAX', 'Admin (1)', '2026-04-21 00:27:01'),
(163, 'Paddy', 'setadmin', 'DENYHAX', 'Főadmin (2)', '2026-04-21 00:27:04'),
(164, 'Paddy', 'setadmin', 'DENYHAX', 'Tulajdonos (3)', '2026-04-21 00:27:06'),
(165, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-04-21 00:27:12'),
(166, 'Paddy', 'setadmin', 'Paddy', 'Admin (1)', '2026-04-21 00:27:13'),
(167, 'Paddy', 'Pénz beállítása', 'Paddy', '$50', '2026-04-21 00:42:48'),
(168, 'Paddy', 'Pénz adása', 'Paddy', '$100', '2026-04-21 00:43:02'),
(169, 'Paddy', 'Pénz levonása', 'Paddy', '-$25', '2026-04-21 00:43:13'),
(170, 'Paddy', 'setadmin', 'Paddy', 'Főadmin (2)', '2026-04-21 00:44:25');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `inventory`
--

CREATE TABLE `inventory` (
  `id` int NOT NULL,
  `owner_name` varchar(50) NOT NULL,
  `opt_adder` int DEFAULT '0',
  `opt_changer` int DEFAULT '0',
  `curse_remover` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- A tábla adatainak kiíratása `inventory`
--

INSERT INTO `inventory` (`id`, `owner_name`, `opt_adder`, `opt_changer`, `curse_remover`) VALUES
(1, 'Paddy', 1, 2, 50);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `owned_skins`
--

CREATE TABLE `owned_skins` (
  `id` int NOT NULL,
  `player_name` varchar(64) DEFAULT NULL,
  `skin_id` int DEFAULT NULL,
  `skin_name` varchar(64) DEFAULT NULL,
  `price` int DEFAULT NULL,
  `buy_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- A tábla adatainak kiíratása `owned_skins`
--

INSERT INTO `owned_skins` (`id`, `player_name`, `skin_id`, `skin_name`, `price`, `buy_date`) VALUES
(1, 'Paddy', 25, 'Ezio Auditore', 25000, '2026-01-21 15:58:31'),
(2, 'Paddy', 24, 'Darth Maul', 20000, '2026-01-21 15:59:11'),
(3, 'Paddy', 0, 'Skin #0', 0, '2026-01-21 15:59:41'),
(4, 'Paddy', 1, 'Skin #1', 500, '2026-01-21 15:59:56'),
(11, 'Paddy', 181, 'Motoros', 420, '2026-01-21 15:58:31'),
(12, 'Paddy', 33, 'Agent', 4500, '2026-01-26 09:37:05'),
(20, 'Paddy', 63, 'csajos', NULL, '2026-01-26 10:37:23'),
(21, 'Paddy', 248, 'Clay', NULL, '2026-01-26 10:43:29'),
(22, 'Paddy', 29, 'Weequay', 1000, '2026-01-26 18:26:35'),
(23, 'Paddy', 27, 'Chiss', 1000, '2026-01-27 10:21:09'),
(24, 'CCmaster', 285, 'Swat Team', 3000, '2026-02-05 20:48:30'),
(25, 'Paddy', 42, 'Blackbeard', 500, '2026-03-17 16:57:01'),
(26, 'Paddy', 59, 'Jager', 500, '2026-03-17 16:57:37'),
(27, 'Paddy', 43, 'IQ', 500, '2026-03-17 16:57:47'),
(28, 'Paddy', 64, 'Hibana', 500, '2026-03-17 16:58:02'),
(29, 'Paddy', 34, 'Finka', 500, '2026-03-17 16:58:25'),
(30, 'Paddy', 44, 'Clash', 500, '2026-03-17 16:58:46'),
(31, 'Paddy', 30, 'Bandit', 500, '2026-03-17 16:59:56'),
(32, 'Paddy', 83, 'Frost', 500, '2026-03-17 17:03:13'),
(33, 'Paddy', 71, 'Mute', 500, '2026-04-16 22:05:55'),
(34, 'Paddy', 40, 'Ela', 500, '2026-04-16 22:14:05'),
(35, 'Paddy', 73, 'Pulse', 500, '2026-04-16 22:17:19');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `reports`
--

CREATE TABLE `reports` (
  `Reports_ID` int NOT NULL,
  `Opener` varchar(100) NOT NULL,
  `Suspect` varchar(100) DEFAULT 'Nincs megadva',
  `Date` datetime DEFAULT CURRENT_TIMESTAMP,
  `Active` int DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

--
-- A tábla adatainak kiíratása `reports`
--

INSERT INTO `reports` (`Reports_ID`, `Opener`, `Suspect`, `Date`, `Active`) VALUES
(11, 'Paddy', 'albika', '2026-02-02 07:52:21', 0),
(12, 'Paddy', 'kopter', '2026-02-02 16:56:00', 0),
(13, 'CCmaster', 'teszt', '2026-02-05 20:41:28', 0),
(14, 'CCmaster', 'teszt', '2026-02-05 20:43:19', 0),
(15, 'Paddy', 'cc', '2026-02-05 20:44:13', 0),
(16, 'Console', 'teszt', '2026-02-19 01:02:27', 0),
(17, 'Console', 'teszt', '2026-02-19 01:05:46', 0),
(18, 'Console', 'teszt', '2026-02-19 01:05:52', 0),
(19, 'Paddy', 'Bence', '2026-03-17 17:23:06', 0),
(20, 'Paddy', 'dany', '2026-04-16 22:02:41', 0),
(21, 'Paddy', 'teszt', '2026-04-21 00:01:01', 0),
(22, 'Paddy', 'teszt', '2026-04-21 00:05:32', 0),
(23, 'Paddy', 'asd', '2026-04-21 00:25:15', 0),
(24, 'Paddy', 'asd', '2026-04-21 00:28:48', 0),
(25, 'Paddy', 'asdas', '2026-04-21 01:33:44', 0);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `report_messages`
--

CREATE TABLE `report_messages` (
  `Message_ID` int NOT NULL,
  `Report_ID` int NOT NULL,
  `Messager` varchar(100) NOT NULL,
  `Message` text NOT NULL,
  `Date` datetime DEFAULT CURRENT_TIMESTAMP,
  `AdminLevel` int DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

--
-- A tábla adatainak kiíratása `report_messages`
--

INSERT INTO `report_messages` (`Message_ID`, `Report_ID`, `Messager`, `Message`, `Date`, `AdminLevel`) VALUES
(25, 11, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: albika | INDOK: teszt', '2026-02-02 07:52:22', 1),
(26, 11, 'PADDY', 'szia, mi a gond?', '2026-02-02 07:52:31', 1),
(27, 12, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: kopter | INDOK: asd', '2026-02-02 16:56:00', 1),
(28, 12, 'PADDY', 'szia', '2026-02-02 16:56:06', 1),
(29, 13, 'CCMASTER', 'ÚJ REPORT! GYANÚSÍTOTT: teszt | INDOK: szia', '2026-02-05 20:41:29', 1),
(30, 13, 'CCMASTER', 'szia', '2026-02-05 20:41:49', 1),
(31, 13, 'PADDY', 'szia', '2026-02-05 20:41:52', 1),
(32, 13, 'PADDY', 'teszt', '2026-02-05 20:42:47', 1),
(33, 14, 'CCMASTER', 'ÚJ REPORT! GYANÚSÍTOTT: teszt | INDOK: szia', '2026-02-05 20:43:19', 1),
(34, 14, 'PADDY', 'szia', '2026-02-05 20:43:43', 1),
(35, 15, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: cc | INDOK: teszt', '2026-02-05 20:44:13', 1),
(36, 14, 'CCMASTER', 'helló', '2026-02-05 20:44:48', 1),
(37, 15, 'CCMASTER', 'helló', '2026-02-05 20:44:52', 1),
(38, 14, 'PADDY', 'szia', '2026-02-05 20:45:27', 1),
(39, 16, 'CONSOLE', 'ÚJ REPORT! GYANÚSÍTOTT: teszt | INDOK: tsezt', '2026-02-19 01:02:27', 1),
(40, 17, 'CONSOLE', 'ÚJ REPORT! GYANÚSÍTOTT: teszt | INDOK: tesztelek csak', '2026-02-19 01:05:47', 1),
(41, 18, 'CONSOLE', 'ÚJ REPORT! GYANÚSÍTOTT: teszt | INDOK: szia', '2026-02-19 01:05:52', 1),
(42, 17, 'PADDY', 'szia', '2026-02-19 01:05:58', 1),
(43, 19, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: Bence | INDOK: DMelt', '2026-03-17 17:23:07', 1),
(44, 19, 'PADDY', 'szia, mi történt', '2026-03-17 17:23:24', 1),
(45, 20, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: dany | INDOK: csak mert azért', '2026-04-16 22:02:41', 1),
(46, 20, 'PADDY', 'szia', '2026-04-16 22:02:48', 1),
(47, 21, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: teszt | INDOK: asd', '2026-04-21 00:01:02', 1),
(48, 21, 'DENYHAX', 'o/', '2026-04-21 00:01:37', 1),
(49, 21, 'PADDY', 'asd', '2026-04-21 00:02:19', 1),
(50, 21, 'DENYHAX', 'xd', '2026-04-21 00:02:20', 1),
(51, 21, 'DENYHAX', 'xddd', '2026-04-21 00:02:26', 1),
(52, 21, 'DENYHAX', 'dsadada', '2026-04-21 00:02:43', 1),
(53, 21, 'PADDY', 'asdasdasdasdasd', '2026-04-21 00:02:59', 1),
(54, 21, 'DENYHAX', 'hey', '2026-04-21 00:03:17', 1),
(55, 21, 'DENYHAX', 'xd', '2026-04-21 00:03:22', 1),
(56, 21, 'DENYHAX', 'xd', '2026-04-21 00:03:24', 1),
(57, 21, 'DENYHAX', 'xdddd', '2026-04-21 00:03:26', 1),
(58, 21, 'DENYHAX', 'teszt', '2026-04-21 00:03:28', 1),
(59, 21, 'DENYHAX', 'xd', '2026-04-21 00:03:30', 1),
(60, 21, 'DENYHAX', ':D', '2026-04-21 00:04:14', 1),
(61, 21, 'DENYHAX', 'xd', '2026-04-21 00:04:16', 1),
(62, 22, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: teszt | INDOK: asd', '2026-04-21 00:05:32', 1),
(63, 22, 'DENYHAX', 'xd', '2026-04-21 00:06:24', 1),
(64, 22, 'DENYHAX', 'xd', '2026-04-21 00:06:26', 1),
(65, 22, 'DENYHAX', 'xd', '2026-04-21 00:06:29', 1),
(66, 22, 'DENYHAX', ':D', '2026-04-21 00:06:33', 1),
(67, 22, 'DENYHAX', 'lol', '2026-04-21 00:06:42', 1),
(68, 22, 'DENYHAX', 'teszt', '2026-04-21 00:06:46', 1),
(69, 23, 'PADDY', 'szia', '2026-04-21 00:26:21', 3),
(70, 23, 'DENYHAX', 'asd', '2026-04-21 00:26:45', 2),
(71, 23, 'DENYHAX', 'asd', '2026-04-21 00:26:50', 2),
(72, 23, 'PADDY', 'asd', '2026-04-21 00:27:46', 1),
(73, 24, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: asd | INDOK: asd asd', '2026-04-21 00:28:48', 0),
(74, 25, 'PADDY', 'ÚJ REPORT! GYANÚSÍTOTT: asdas | INDOK: asd', '2026-04-21 01:33:44', 0),
(75, 25, 'PADDY', 'mAASD', '2026-04-21 01:33:50', 3),
(76, 25, 'DENYHAX', 'xd', '2026-04-21 01:40:36', 3);

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `shop_logs`
--

CREATE TABLE `shop_logs` (
  `id` int NOT NULL,
  `player` varchar(64) DEFAULT NULL,
  `action` varchar(255) DEFAULT NULL,
  `cost` int DEFAULT NULL,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- A tábla adatainak kiíratása `shop_logs`
--

INSERT INTO `shop_logs` (`id`, `player`, `action`, `cost`, `date`) VALUES
(138, 'Paddy', 'Skill: M4 Skill', 1000, '2026-01-27 10:21:45'),
(139, 'Paddy', 'M4 Carbine', 4500, '2026-01-27 10:21:52'),
(140, 'Paddy', 'Combat Shotgun', 3500, '2026-01-27 10:42:23'),
(141, 'Paddy', 'Skill: Health Boost', 3000, '2026-01-27 10:42:30'),
(142, 'Paddy', 'Skill: Stealth Walk', 2000, '2026-01-27 10:42:33'),
(143, 'Paddy', 'Skill: Silenced Pistol Skill', 0, '2026-01-27 10:42:44'),
(144, 'Paddy', 'Skill: Stamina Upgrade', 1000, '2026-01-27 10:42:52'),
(145, 'Paddy', 'Skill: Stamina Upgrade', 1000, '2026-01-27 10:42:55'),
(146, 'Paddy', 'Skill: Stamina Upgrade', 1000, '2026-01-27 10:42:57'),
(147, 'Paddy', 'Skill: Stamina Upgrade', 1000, '2026-01-27 10:42:58'),
(148, 'Paddy', 'Skill: Stamina Upgrade', 1000, '2026-01-27 10:42:58'),
(149, 'Paddy', 'Skill: Stamina Upgrade', 1000, '2026-01-27 10:42:59'),
(150, 'Paddy', 'Skill: Health Boost', 3000, '2026-01-27 10:43:00'),
(151, 'Paddy', 'Skill: Health Boost', 3000, '2026-01-27 10:43:01'),
(152, 'Paddy', 'Armor (Kevlar)', 2000, '2026-01-27 10:43:10'),
(153, 'Paddy', 'Medkit', 1500, '2026-01-27 10:43:11'),
(154, 'Paddy', 'Grenade', 1000, '2026-01-27 10:43:14'),
(155, 'Paddy', 'Desert Eagle', 2500, '2026-01-28 12:44:33'),
(156, 'Paddy', 'C4 Explosive', 8000, '2026-01-28 12:45:13'),
(157, 'Paddy', 'Desert Eagle', 2500, '2026-01-28 12:45:22'),
(158, 'Paddy', 'Grenade', 1000, '2026-01-31 06:07:48'),
(159, 'Paddy', 'C4 Explosive', 8000, '2026-01-31 06:09:22'),
(160, 'Paddy', 'AK-47', 1000, '2026-01-31 06:09:25'),
(161, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-01-31 06:09:32'),
(162, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-01-31 06:11:25'),
(163, 'Paddy', 'Skill: M4 Skill', 1000, '2026-01-31 06:11:30'),
(164, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-01-31 06:13:10'),
(165, 'Paddy', 'Desert Eagle', 2500, '2026-02-02 08:06:04'),
(166, 'Paddy', 'AK-47', 1000, '2026-02-02 08:27:09'),
(167, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-02-02 08:27:33'),
(168, 'Paddy', 'Armor (Kevlar)', 2000, '2026-02-02 08:47:44'),
(169, 'Paddy', 'Armor (Kevlar)', 2000, '2026-02-02 11:35:14'),
(170, 'Paddy', 'Armor (Kevlar)', 2000, '2026-02-02 16:53:02'),
(171, 'Paddy', 'Sniper Rifle', 5000, '2026-02-02 16:53:04'),
(172, 'Paddy', 'ADMIN_VISION ON', 0, '2026-02-02 16:54:46'),
(173, 'Paddy', 'AK-47', 1000, '2026-02-02 16:55:12'),
(174, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-02-02 16:57:04'),
(175, 'Paddy', 'AK-47', 1000, '2026-02-05 13:00:47'),
(176, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:01:01'),
(177, 'Paddy', 'Skill: M4 Skill', 1000, '2026-02-05 13:01:08'),
(178, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:10:20'),
(179, 'Paddy', 'Skill: M4 Skill', 1000, '2026-02-05 13:10:29'),
(180, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:19:04'),
(181, 'Paddy', 'AK-47', 1000, '2026-02-05 13:31:03'),
(182, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:31:52'),
(183, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:32:33'),
(184, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:32:33'),
(185, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:32:33'),
(186, 'Paddy', 'AK-47', 1000, '2026-02-05 13:33:45'),
(187, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:34:40'),
(188, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:48:11'),
(189, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:48:11'),
(190, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:48:12'),
(191, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:48:12'),
(192, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:48:12'),
(193, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 13:48:12'),
(194, 'Paddy', 'ADMIN_VISION ON', 0, '2026-02-05 14:17:33'),
(195, 'CCmaster', 'M4 Carbine', 4500, '2026-02-05 20:47:50'),
(196, 'CCmaster', 'Skill: M4 Skill', 1000, '2026-02-05 20:47:53'),
(197, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 20:47:56'),
(198, 'Paddy', 'Skill: M4 Skill', 1000, '2026-02-05 20:48:00'),
(199, 'CCmaster', 'ADMIN_VISION ON', 0, '2026-02-05 20:51:07'),
(200, 'Paddy', 'ADMIN_VISION ON', 0, '2026-02-05 20:51:32'),
(201, 'CCmaster', 'M4 Carbine', 4500, '2026-02-05 20:57:31'),
(202, 'Paddy', 'ADMIN_VISION ON', 0, '2026-02-05 21:03:58'),
(203, 'Paddy', 'M4 Carbine', 4500, '2026-02-05 21:04:47'),
(204, 'Paddy', 'AK-47', 1000, '2026-03-14 20:49:18'),
(205, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-03-14 21:07:02'),
(206, 'Paddy', 'AK-47', 1000, '2026-03-14 21:08:50'),
(207, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-03-14 21:08:51'),
(208, 'Paddy', 'M4 Carbine', 4500, '2026-03-14 21:17:30'),
(209, 'Paddy', 'AK-47', 1000, '2026-03-17 16:39:40'),
(210, 'Paddy', 'Skill: AK-47 Skill', 5000, '2026-03-17 16:39:42'),
(211, 'Paddy', 'Skill: M4 Skill', 1000, '2026-03-17 16:39:42'),
(212, 'Paddy', 'M4 Carbine', 4500, '2026-03-17 16:40:16'),
(213, 'Paddy', 'AK-47', 1000, '2026-03-17 17:04:48'),
(214, 'Paddy', 'M4 Carbine', 4500, '2026-03-17 17:06:24'),
(215, 'Paddy', 'AK-47', 1000, '2026-03-17 17:06:41'),
(216, 'Paddy', 'AK-47', 1000, '2026-03-17 17:17:46'),
(217, 'Paddy', 'M4 Carbine', 4500, '2026-03-17 17:18:38'),
(218, 'Paddy', 'AK-47', 1000, '2026-03-17 17:20:08'),
(219, 'Paddy', 'M4 Carbine', 4500, '2026-03-17 17:21:02'),
(220, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-16 22:01:12'),
(221, 'Paddy', 'ADMIN_VISION OFF', 0, '2026-04-16 22:01:34'),
(222, 'Paddy', 'M4 Carbine', 4500, '2026-04-16 22:03:32'),
(223, 'Paddy', 'AK-47', 1000, '2026-04-16 22:04:15'),
(224, 'Paddy', 'Armor (Kevlar)', 2000, '2026-04-16 22:10:46'),
(225, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-16 22:12:31'),
(226, 'Paddy', 'M4 Carbine', 4500, '2026-04-16 22:18:56'),
(227, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-20 23:45:37'),
(228, 'DENYHAX', 'ADMIN_VISION ON', 0, '2026-04-20 23:45:39'),
(229, 'DENYHAX', 'ADMIN_VISION OFF', 0, '2026-04-20 23:47:09'),
(230, 'DENYHAX', 'ADMIN_VISION ON', 0, '2026-04-20 23:53:41'),
(231, 'DENYHAX', 'Armor (Kevlar)', 2000, '2026-04-20 23:54:24'),
(232, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-21 01:11:02'),
(233, 'Paddy', 'ADMIN_VISION OFF', 0, '2026-04-21 01:16:40'),
(234, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-21 01:16:41'),
(235, 'Paddy', 'ADMIN_VISION OFF', 0, '2026-04-21 01:17:30'),
(236, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-21 01:17:31'),
(237, 'Paddy', 'ADMIN_VISION OFF', 0, '2026-04-21 01:18:31'),
(238, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-21 01:18:32'),
(239, 'Paddy', 'ADMIN_VISION ON', 0, '2026-04-21 01:24:45');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `users`
--

CREATE TABLE `users` (
  `ID` int NOT NULL,
  `Név` varchar(50) DEFAULT 'Guest',
  `adminLevel` int DEFAULT '0',
  `Serial` varchar(100) NOT NULL,
  `Money` int DEFAULT '0',
  `Kill` int DEFAULT '0',
  `PremiumPoint` int DEFAULT '0',
  `skins` varchar(100) DEFAULT '1;1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- A tábla adatainak kiíratása `users`
--

INSERT INTO `users` (`ID`, `Név`, `adminLevel`, `Serial`, `Money`, `Kill`, `PremiumPoint`, `skins`) VALUES
(1, 'Paddy', 2, 'F2922808DBCADF044A74BF867CF5BC43', 125, 0, 9999, '29;25'),
(12, 'hax', 0, '173E90F1523CBA253EB651AAD5C9E9B3', 1000, 0, 0, '1;1');

-- --------------------------------------------------------

--
-- Tábla szerkezet ehhez a táblához `weapons`
--

CREATE TABLE `weapons` (
  `id` int NOT NULL,
  `owner_name` varchar(255) NOT NULL,
  `weapon_model` int NOT NULL,
  `serial_number` varchar(50) NOT NULL,
  `durability` int DEFAULT '100',
  `mod_head_dmg` int DEFAULT '0',
  `mod_body_dmg` int DEFAULT '0',
  `mod_arm_dmg` int DEFAULT '0',
  `mod_leg_dmg` int DEFAULT '0',
  `buff_fire` tinyint(1) DEFAULT '0',
  `buff_stun` tinyint(1) DEFAULT '0',
  `buff_poison` tinyint(1) DEFAULT '0',
  `buff_life_drain` tinyint(1) DEFAULT '0',
  `reload_speed_mod` int DEFAULT '0',
  `ammo_capacity_mod` int DEFAULT '0',
  `fire_mode` varchar(15) DEFAULT 'auto',
  `curse_1_type` varchar(20) DEFAULT NULL,
  `curse_1_value` int DEFAULT '0',
  `curse_2_type` varchar(20) DEFAULT NULL,
  `curse_2_value` int DEFAULT '0',
  `is_equipped` tinyint(1) DEFAULT '0',
  `slot_type` int DEFAULT '0',
  `is_on_market` tinyint(1) DEFAULT '0',
  `market_price` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- A tábla adatainak kiíratása `weapons`
--

INSERT INTO `weapons` (`id`, `owner_name`, `weapon_model`, `serial_number`, `durability`, `mod_head_dmg`, `mod_body_dmg`, `mod_arm_dmg`, `mod_leg_dmg`, `buff_fire`, `buff_stun`, `buff_poison`, `buff_life_drain`, `reload_speed_mod`, `ammo_capacity_mod`, `fire_mode`, `curse_1_type`, `curse_1_value`, `curse_2_type`, `curse_2_value`, `is_equipped`, `slot_type`, `is_on_market`, `market_price`) VALUES
(2, 'paddy', 30, 'TTT-DTDYL0QX', 100, 15, 10, 0, 0, 0, 0, 69, 0, 0, 0, 'auto', NULL, 0, NULL, 0, 0, 0, 0, 0),
(3, 'paddy', 31, 'TTT-QSIH569W', 88, 25, 10, 0, 0, 69, 10, 0, 40, 0, 0, 'auto', 'Trevi a nevem xd', 50, 'test', 0, 1, 1, 0, 0),
(6, 'paddy', 30, 'TTT-5547YUW3', 100, 15, 10, 0, 0, 0, 0, 0, 0, 0, 0, 'auto', NULL, 0, NULL, 0, 0, 0, 0, 0),
(8, 'CCmaster', 31, 'TTT-TZBX4W7S', 99, 15, 10, 0, 0, 100, 0, 0, 0, 0, 0, 'auto', NULL, 0, NULL, 0, 1, 1, 0, 0);

--
-- Indexek a kiírt táblákhoz
--

--
-- A tábla indexei `admin_commands`
--
ALTER TABLE `admin_commands`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `inventory`
--
ALTER TABLE `inventory`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `owned_skins`
--
ALTER TABLE `owned_skins`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `reports`
--
ALTER TABLE `reports`
  ADD PRIMARY KEY (`Reports_ID`);

--
-- A tábla indexei `report_messages`
--
ALTER TABLE `report_messages`
  ADD PRIMARY KEY (`Message_ID`);

--
-- A tábla indexei `shop_logs`
--
ALTER TABLE `shop_logs`
  ADD PRIMARY KEY (`id`);

--
-- A tábla indexei `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`ID`),
  ADD UNIQUE KEY `Serial` (`Serial`);

--
-- A tábla indexei `weapons`
--
ALTER TABLE `weapons`
  ADD PRIMARY KEY (`id`),
  ADD KEY `owner_id` (`owner_name`),
  ADD KEY `serial_number` (`serial_number`);

--
-- A kiírt táblák AUTO_INCREMENT értéke
--

--
-- AUTO_INCREMENT a táblához `admin_commands`
--
ALTER TABLE `admin_commands`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=171;

--
-- AUTO_INCREMENT a táblához `inventory`
--
ALTER TABLE `inventory`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT a táblához `owned_skins`
--
ALTER TABLE `owned_skins`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT a táblához `reports`
--
ALTER TABLE `reports`
  MODIFY `Reports_ID` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT a táblához `report_messages`
--
ALTER TABLE `report_messages`
  MODIFY `Message_ID` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=77;

--
-- AUTO_INCREMENT a táblához `shop_logs`
--
ALTER TABLE `shop_logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=240;

--
-- AUTO_INCREMENT a táblához `users`
--
ALTER TABLE `users`
  MODIFY `ID` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT a táblához `weapons`
--
ALTER TABLE `weapons`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
