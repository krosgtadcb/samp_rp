// =============================================================================
//  DAIS RP - Gamemode Principal para SA-MP
//  Plataforma: SA-MP 0.3.7
//  Lenguaje: Pawn
//  Descripción: Servidor RP completo estilo DAIS Zone
// =============================================================================

#include <a_samp>
#include <a_mysql>       // Plugin MySQL
#include <sscanf2>       // Plugin SSCANF
#include <streamer>      // Plugin Streamer
#include <ZCMD>          // Procesador de comandos ZCMD

// =============================================================================
//  CONSTANTES GLOBALES
// =============================================================================
#define MAX_PLAYERS_RP      100
#define MAX_FACTIONS        15
#define MAX_VEHICLES_RP     500
#define MAX_HOUSES          300
#define MAX_BUSINESSES      100
#define MAX_ITEMS           50
#define MAX_INV_SLOTS       20
#define MAX_CLANS           50
#define MAX_ACHIEVEMENTS    30
#define MAX_GAS_STATIONS    50
#define MAX_DEALERSHIPS     20
#define MAX_TUNING_PARTS    50
#define SERVER_NAME         "DAIS RP"
#define MYSQL_HOST          "127.0.0.1"
#define MYSQL_USER          "root"
#define MYSQL_PASS          ""
#define MYSQL_DB            "daisrp"

// Colores
#define COLOR_WHITE         0xFFFFFFFF
#define COLOR_RED           0xFF0000FF
#define COLOR_GREEN         0x00FF00FF
#define COLOR_YELLOW        0xFFFF00FF
#define COLOR_BLUE          0x0000FFFF
#define COLOR_ORANGE        0xFF8C00FF
#define COLOR_PURPLE        0x9400D3FF
#define COLOR_PINK          0xFF69B4FF
#define COLOR_GREY          0xAFAFAFFF
#define COLOR_GOLD          0xFFD700FF
#define COLOR_LIGHTBLUE     0x33CCFFAA

// Estados del jugador
#define STATE_DEAD          0
#define STATE_ALIVE         1
#define STATE_CUFFED        2

// Diálogos
#define DIALOG_LOGIN        1
#define DIALOG_REGISTER     2
#define DIALOG_REGISTER2    3
#define DIALOG_STATS        4
#define DIALOG_SEX          5
#define DIALOG_INVENTORY    6
#define DIALOG_ITEM_USE     7
#define DIALOG_VEHICLE_MENU 8
#define DIALOG_DEALERSHIP   9
#define DIALOG_BUY_VEHICLE  10
#define DIALOG_TRUNK        11
#define DIALOG_TUNING       12
#define DIALOG_GAS_STATION  13
#define DIALOG_ADMIN_VEHICLE 14
#define DIALOG_ADMIN_GAS    15

// Tipos de items
#define ITEM_TYPE_NONE      0
#define ITEM_TYPE_FOOD      1
#define ITEM_TYPE_DRINK     2
#define ITEM_TYPE_WEAPON    3
#define ITEM_TYPE_MEDICAL   4
#define ITEM_TYPE_MATERIAL  5
#define ITEM_TYPE_DRUG      6
#define ITEM_TYPE_TOOL      7

// =============================================================================
//  ENUMERACIONES
// =============================================================================
enum E_PLAYER_DATA {
    pID,
    pName[MAX_PLAYER_NAME],
    pPassword[65],
    pSex,                       // 0 = hombre, 1 = mujer
    pCash,
    pBank,
    Float:pHealth,
    Float:pArmour,
    pHunger,
    pThirst,
    pLevel,
    pExp,
    pFaction,
    pFactionRank,
    pJob,
    pLicenses,
    pWanted,
    pWarns,
    pJailTime,
    pPrisonTime,
    bool:pLogged,
    bool:pRegistered,
    pSkin,
    Float:pX,
    Float:pY,
    Float:pZ,
    Float:pAngle,
    pInterior,
    pVW,
    pPlayTime,
    pKills,
    pDeaths,
    pState,
    pPhoneNumber,
    pPhoneCredit,
    pReputation,
    pHouseID,
    pBizID,
    pClanID,
    pClanRank,
    pAchievements,
    pAdminLevel,
    pMuteTime,
    bool:pCuffed,
    pLastLogin[32],
    pRegisterDate[32],
    pIP[20],
    pSelectedItem,              // Item seleccionado en la mano
    pCurrentVehicle,             // Vehículo actual
    pFuelTimer                   // Timer para consumo de combustible
}

enum E_VEHICLE_DATA {
    vID,
    vOwner[MAX_PLAYER_NAME],
    vModel,
    Float:vX,
    Float:vY,
    Float:vZ,
    Float:vAngle,
    vColor1,
    vColor2,
    vFuel,
    vMaxFuel,
    vMileage,
    Float:vHealth,
    bool:vLocked,
    bool:vInsured,
    vTuning[12],                 // Hasta 12 partes de tuning
    vPlate[32],
    vPrice,
    vFaction,
    vTrunkItems[MAX_INV_SLOTS][2], // Inventario del maletero [itemID][cantidad]
    bool:vEngine,
    bool:vLights,
    bool:vAlarm,
    bool:vDoors,
    bool:vBonnet,
    bool:vBoot,
    vObjective
}

enum E_ITEM_DATA {
    iID,
    iName[32],
    iModel,
    iType,
    iValue,
    iWeight
}

enum E_GAS_STATION_DATA {
    gsID,
    Float:gsX,
    Float:gsY,
    Float:gsZ,
    gsFuel,
    gsPrice,
    gsPickup,
    Text3D:gsLabel
}

enum E_DEALERSHIP_DATA {
    dsID,
    dsName[64],
    Float:dsX,
    Float:dsY,
    Float:dsZ,
    dsVehicles[20][2],           // [modelo][precio]
    dsPickup,
    Text3D:dsLabel
}

enum E_TUNING_PART_DATA {
    tpID,
    tpName[32],
    tpModel,
    tpType,                      // 0=llantas, 1=spoiler, 2=nitro, 3=faros, etc
    tpPrice
}

// =============================================================================
//  VARIABLES GLOBALES
// =============================================================================
new PlayerData[MAX_PLAYERS][E_PLAYER_DATA];
new VehicleData[MAX_VEHICLES_RP][E_VEHICLE_DATA];
new ItemData[MAX_ITEMS][E_ITEM_DATA];
new GasStationData[MAX_GAS_STATIONS][E_GAS_STATION_DATA];
new DealershipData[MAX_DEALERSHIPS][E_DEALERSHIP_DATA];
new TuningPartData[MAX_TUNING_PARTS][E_TUNING_PART_DATA];

// Inventario del jugador: [playerid][slot][0]=itemID, [1]=cantidad
new PlayerInventory[MAX_PLAYERS][MAX_INV_SLOTS][2];

// MySQL
new MySQL:g_SQL;

// Timers globales
new g_HungerTimer;
new g_SaveTimer;
new g_FuelTimer;

// Variables adicionales
new g_TempPassword[MAX_PLAYERS][65];
new g_MysqlRaceCheck[MAX_PLAYERS];
new g_TotalGasStations = 0;
new g_TotalDealerships = 0;

// TextDraws HUD
new PlayerText:pHUD_Background[MAX_PLAYERS];
new PlayerText:pHUD_HungerBar[MAX_PLAYERS];
new PlayerText:pHUD_ThirstBar[MAX_PLAYERS];
new PlayerText:pHUD_ExpBar[MAX_PLAYERS];
new PlayerText:pHUD_HungerText[MAX_PLAYERS];
new PlayerText:pHUD_ThirstText[MAX_PLAYERS];
new PlayerText:pHUD_LevelText[MAX_PLAYERS];
new PlayerText:pHUD_ExpText[MAX_PLAYERS];
new PlayerText:pHUD_MoneyText[MAX_PLAYERS];
new PlayerText:pHUD_FuelText[MAX_PLAYERS];
new PlayerText:pHUD_SpeedText[MAX_PLAYERS];

// =============================================================================
//  FORWARDS
// =============================================================================
forward OnPlayerDataLoad(playerid);
forward OnPlayerRegister(playerid);
forward OnPlayerFullDataLoad(playerid);
forward HungerThirstUpdate();
forward AutoSave();
forward FuelConsumptionUpdate();
forward LoadVehicles();
forward LoadGasStations();
forward LoadDealerships();
forward LoadItems();

// =============================================================================
//  CALLBACKS PRINCIPALES
// =============================================================================

public OnGameModeInit() {
    print("==============================================");
    print(" DAIS RP - Iniciando servidor...");
    print("==============================================");

    // Conectar MySQL
    g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB);
    if(mysql_errno(g_SQL) != 0) {
        print("[ERROR] No se pudo conectar a MySQL!");
        SendRconCommand("exit");
        return 1;
    }
    print("[MySQL] Conexion exitosa.");

    // Crear tablas si no existen
    CreateDatabaseTables();

    // Configurar servidor
    SetGameModeText("DAIS RP");
    ShowNameTags(1);
    ShowPlayerMarkers(0);
    UsePlayerPedAnims();
    EnableStuntBonusForAll(0);
    DisableInteriorEnterExits();
    SetWeather(10);
    SetWorldTime(12);

    // Iniciar timers
    g_HungerTimer = SetTimer("HungerThirstUpdate", 60000, true);
    g_SaveTimer   = SetTimer("AutoSave", 300000, true);
    g_FuelTimer   = SetTimer("FuelConsumptionUpdate", 10000, true);

    // Cargar datos
    LoadItems();
    LoadVehicles();
    LoadGasStations();
    LoadDealerships();

    print("[DAIS RP] Gamemode iniciado correctamente!");
    return 1;
}

public OnGameModeExit() {
    print("[DAIS RP] Cerrando servidor, guardando datos...");
    SaveAllData();
    mysql_close(g_SQL);
    KillTimer(g_HungerTimer);
    KillTimer(g_SaveTimer);
    KillTimer(g_FuelTimer);
    print("[DAIS RP] Datos guardados. Hasta pronto!");
    return 1;
}

public OnPlayerConnect(playerid) {
    // Resetear datos del jugador
    ResetPlayerData(playerid);

    // Crear HUD para el jugador
    CreatePlayerHUD(playerid);

    // Obtener nombre del jugador
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

    // Verificar en base de datos
    new query[256];
    mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `players` WHERE `name` = '%e' LIMIT 1", name);
    g_MysqlRaceCheck[playerid] = mysql_tquery(g_SQL, query, "OnPlayerDataLoad", "i", playerid);

    // Congelar al jugador mientras carga
    TogglePlayerControllable(playerid, false);
    
    // Posición de spawn temporal
    SetPlayerPos(playerid, 1958.3783, 1343.1572, 15.3746);
    SetPlayerCameraPos(playerid, 1962.0, 1343.0, 17.0);
    SetPlayerCameraLookAt(playerid, 1958.0, 1343.0, 15.0);

    // Mensajes de bienvenida
    SendClientMessage(playerid, COLOR_GOLD, "________________________________________");
    SendClientMessage(playerid, COLOR_GOLD, "  Bienvenido a "SERVER_NAME);
    SendClientMessage(playerid, COLOR_GREY, "  Cargando tu perfil, por favor espera...");
    SendClientMessage(playerid, COLOR_GOLD, "________________________________________");
    return 1;
}

public OnPlayerDisconnect(playerid, reason) {
    // Guardar datos si estaba logueado
    if(PlayerData[playerid][pLogged]) {
        SavePlayerData(playerid);
        SavePlayerInventory(playerid);
    }
    
    // Destruir HUD
    DestroyPlayerHUD(playerid);
    
    // Resetear datos
    ResetPlayerData(playerid);
    
    // Cancelar consultas pendientes
    if(g_MysqlRaceCheck[playerid]) {
        g_MysqlRaceCheck[playerid] = 0;
    }

    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    new msg[128];
    format(msg, sizeof(msg), "[Sistema] %s ha abandonado el servidor.", name);
    SendClientMessageToAll(COLOR_GREY, msg);
    return 1;
}

public OnPlayerSpawn(playerid) {
    if(!PlayerData[playerid][pLogged]) return 0;

    // Restaurar datos del jugador
    SetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
    SetPlayerArmour(playerid, PlayerData[playerid][pArmour]);
    SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
    SetPlayerInterior(playerid, PlayerData[playerid][pInterior]);
    SetPlayerVirtualWorld(playerid, PlayerData[playerid][pVW]);

    // Posición de spawn
    SetPlayerPos(playerid, PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ]);
    SetPlayerFacingAngle(playerid, PlayerData[playerid][pAngle]);

    // Actualizar dinero
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, PlayerData[playerid][pCash]);

    // Actualizar HUD
    UpdatePlayerHUD(playerid);

    // Mensaje de bienvenida
    SendClientMessage(playerid, COLOR_GREEN, "[Sistema] Bienvenido de vuelta!");
    return 1;
}

public OnPlayerDeath(playerid, killerid, reason) {
    PlayerData[playerid][pDeaths]++;
    PlayerData[playerid][pState] = STATE_DEAD;
    return 1;
}

public OnPlayerText(playerid, text[]) {
    if(!PlayerData[playerid][pLogged]) return 0;
    if(PlayerData[playerid][pMuteTime] > 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] Estás silenciado.");
        return 0;
    }

    new name[MAX_PLAYER_NAME], msg[256];
    GetPlayerName(playerid, name, sizeof(name));
    format(msg, sizeof(msg), "%s [ID:%d]: %s", name, playerid, text);
    
    // Enviar a todos
    SendClientMessageToAll(COLOR_WHITE, msg);
    return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger) {
    if(!ispassenger) {
        PlayerData[playerid][pCurrentVehicle] = vehicleid;
    }
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid) {
    PlayerData[playerid][pCurrentVehicle] = 0;
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    #pragma unused listitem
    
    switch(dialogid) {
        case DIALOG_LOGIN: {
            if(!response) {
                Kick(playerid);
                return 1;
            }
            HandleLogin(playerid, inputtext);
        }
        case DIALOG_REGISTER: {
            if(!response) {
                Kick(playerid);
                return 1;
            }
            HandleRegister(playerid, inputtext);
        }
        case DIALOG_REGISTER2: {
            if(!response) {
                Kick(playerid);
                return 1;
            }
            HandleRegisterConfirm(playerid, inputtext);
        }
        case DIALOG_SEX: {
            if(!response) {
                Kick(playerid);
                return 1;
            }
            if(listitem == 0) { // Hombre
                PlayerData[playerid][pSex] = 0;
                PlayerData[playerid][pSkin] = 250;
            } else { // Mujer
                PlayerData[playerid][pSex] = 1;
                PlayerData[playerid][pSkin] = 13;
            }
            SetPlayerSkin(playerid, PlayerData[playerid][pSkin]);
            SendClientMessage(playerid, COLOR_GREEN, "[Sistema] Skin seleccionada correctamente.");
        }
        case DIALOG_INVENTORY: {
            if(!response) return 1;
            HandleInventorySelection(playerid, listitem);
        }
        case DIALOG_ITEM_USE: {
            if(!response) return 1;
            HandleItemUse(playerid, listitem);
        }
        case DIALOG_VEHICLE_MENU: {
            if(!response) return 1;
            HandleVehicleMenu(playerid, listitem);
        }
        case DIALOG_DEALERSHIP: {
            if(!response) return 1;
            ShowDealershipVehicles(playerid, listitem);
        }
        case DIALOG_BUY_VEHICLE: {
            if(!response) return 1;
            BuyVehicle(playerid, listitem);
        }
        case DIALOG_TRUNK: {
            if(!response) return 1;
            HandleTrunkMenu(playerid, listitem);
        }
        case DIALOG_TUNING: {
            if(!response) return 1;
            HandleTuningMenu(playerid, listitem);
        }
        case DIALOG_GAS_STATION: {
            if(!response) return 1;
            HandleGasStation(playerid, listitem, inputtext);
        }
        case DIALOG_ADMIN_VEHICLE: {
            if(!response || PlayerData[playerid][pAdminLevel] < 1) return 1;
            CreateAdminVehicle(playerid, listitem);
        }
        case DIALOG_ADMIN_GAS: {
            if(!response || PlayerData[playerid][pAdminLevel] < 2) return 1;
            CreateGasStation(playerid);
        }
    }
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid) {
    // Verificar gasolineras
    for(new i = 0; i < g_TotalGasStations; i++) {
        if(pickupid == GasStationData[i][gsPickup]) {
            ShowGasStationMenu(playerid, i);
            return 1;
        }
    }
    
    // Verificar concesionarios
    for(new i = 0; i < g_TotalDealerships; i++) {
        if(pickupid == DealershipData[i][dsPickup]) {
            ShowDealershipMenu(playerid, i);
            return 1;
        }
    }
    return 1;
}

// =============================================================================
//  BASE DE DATOS
// =============================================================================
CreateDatabaseTables() {
    // Tabla de jugadores
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS `players` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY,\
        `name` VARCHAR(24) UNIQUE NOT NULL,\
        `password` VARCHAR(65) NOT NULL,\
        `sex` INT DEFAULT 0,\
        `cash` INT DEFAULT 5000,\
        `bank` INT DEFAULT 10000,\
        `health` FLOAT DEFAULT 100.0,\
        `armour` FLOAT DEFAULT 0.0,\
        `hunger` INT DEFAULT 100,\
        `thirst` INT DEFAULT 100,\
        `level` INT DEFAULT 1,\
        `exp` INT DEFAULT 0,\
        `faction` INT DEFAULT 0,\
        `faction_rank` INT DEFAULT 0,\
        `job` INT DEFAULT 0,\
        `licenses` INT DEFAULT 0,\
        `wanted` INT DEFAULT 0,\
        `warns` INT DEFAULT 0,\
        `jail_time` INT DEFAULT 0,\
        `skin` INT DEFAULT 250,\
        `x` FLOAT DEFAULT 1958.3783,\
        `y` FLOAT DEFAULT 1343.1572,\
        `z` FLOAT DEFAULT 15.3746,\
        `angle` FLOAT DEFAULT 269.1425,\
        `interior` INT DEFAULT 0,\
        `vw` INT DEFAULT 0,\
        `playtime` INT DEFAULT 0,\
        `kills` INT DEFAULT 0,\
        `deaths` INT DEFAULT 0,\
        `phone` INT DEFAULT 0,\
        `phone_credit` INT DEFAULT 100,\
        `reputation` INT DEFAULT 0,\
        `house_id` INT DEFAULT -1,\
        `biz_id` INT DEFAULT -1,\
        `clan_id` INT DEFAULT -1,\
        `clan_rank` INT DEFAULT 0,\
        `achievements` INT DEFAULT 0,\
        `admin_level` INT DEFAULT 0,\
        `mute_time` INT DEFAULT 0,\
        `last_login` VARCHAR(32),\
        `register_date` VARCHAR(32),\
        `ip` VARCHAR(20)\
    )");

    // Tabla de inventario
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS `inventory` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY,\
        `player_id` INT,\
        `slot` INT,\
        `item_id` INT,\
        `amount` INT DEFAULT 1,\
        FOREIGN KEY (`player_id`) REFERENCES `players`(`id`) ON DELETE CASCADE\
    )");

    // Tabla de vehículos
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS `vehicles` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY,\
        `owner` VARCHAR(24),\
        `model` INT,\
        `x` FLOAT, `y` FLOAT, `z` FLOAT, `angle` FLOAT,\
        `color1` INT, `color2` INT,\
        `fuel` INT DEFAULT 100,\
        `max_fuel` INT DEFAULT 100,\
        `mileage` INT DEFAULT 0,\
        `health` FLOAT DEFAULT 1000,\
        `locked` INT DEFAULT 1,\
        `insured` INT DEFAULT 0,\
        `tuning` VARCHAR(128),\
        `plate` VARCHAR(32),\
        `price` INT DEFAULT 0,\
        `faction` INT DEFAULT 0\
    )");

    // Tabla de maletero
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS `vehicle_trunk` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY,\
        `vehicle_id` INT,\
        `slot` INT,\
        `item_id` INT,\
        `amount` INT DEFAULT 1,\
        FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles`(`id`) ON DELETE CASCADE\
    )");

    // Tabla de gasolineras
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS `gas_stations` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY,\
        `x` FLOAT, `y` FLOAT, `z` FLOAT,\
        `fuel` INT DEFAULT 10000,\
        `price` INT DEFAULT 5\
    )");

    // Tabla de concesionarios
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS `dealerships` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY,\
        `name` VARCHAR(64),\
        `x` FLOAT, `y` FLOAT, `z` FLOAT,\
        `vehicles` TEXT\
    )");

    // Tabla de items
    mysql_query(g_SQL, "CREATE TABLE IF NOT EXISTS `items` (\
        `id` INT AUTO_INCREMENT PRIMARY KEY,\
        `name` VARCHAR(32),\
        `model` INT,\
        `type` INT,\
        `value` INT,\
        `weight` INT DEFAULT 1\
    )");

    print("[MySQL] Tablas creadas/verificadas correctamente.");
}

// =============================================================================
//  CARGA DE DATOS
// =============================================================================
LoadItems() {
    // Items por defecto
    ItemData[1][iName] = "Hamburguesa";
    ItemData[1][iModel] = 2703;
    ItemData[1][iType] = ITEM_TYPE_FOOD;
    ItemData[1][iValue] = 30;
    ItemData[1][iWeight] = 1;
    
    ItemData[2][iName] = "Agua";
    ItemData[2][iModel] = 1484;
    ItemData[2][iType] = ITEM_TYPE_DRINK;
    ItemData[2][iValue] = 40;
    ItemData[2][iWeight] = 1;
    
    ItemData[3][iName] = "Botiquin";
    ItemData[3][iModel] = 1580;
    ItemData[3][iType] = ITEM_TYPE_MEDICAL;
    ItemData[3][iValue] = 50;
    ItemData[3][iWeight] = 2;
    
    ItemData[4][iName] = "Llave Inglesa";
    ItemData[4][iModel] = 18633;
    ItemData[4][iType] = ITEM_TYPE_TOOL;
    ItemData[4][iValue] = 0;
    ItemData[4][iWeight] = 3;
    
    print("[Items] Items cargados correctamente.");
}

public OnPlayerDataLoad(playerid) {
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

    if(cache_num_rows() > 0) {
        // Jugador existe - cargar datos básicos
        PlayerData[playerid][pRegistered] = true;
        PlayerData[playerid][pID] = cache_get_value_name_int(0, "id");
        cache_get_value_name(0, "password", PlayerData[playerid][pPassword], 65);
        PlayerData[playerid][pSex] = cache_get_value_name_int(0, "sex");
        
        // Mostrar diálogo de login
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
            "DAIS RP - Iniciar Sesion",
            "Ingresa tu contrasena para continuar:",
            "Entrar", "Salir");
    } else {
        // Jugador nuevo
        PlayerData[playerid][pRegistered] = false;
        
        // Mostrar diálogo de registro
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT,
            "DAIS RP - Registro",
            "Bienvenido al servidor!\n\nCrea tu contrasena (minimo 6 caracteres):",
            "Siguiente", "Salir");
    }
    return 1;
}

// =============================================================================
//  SISTEMA DE LOGIN/REGISTRO
// =============================================================================
HandleLogin(playerid, const inputtext[]) {
    if(strcmp(inputtext, PlayerData[playerid][pPassword]) == 0) {
        // Login exitoso
        PlayerData[playerid][pLogged] = true;
        
        // Cargar todos los datos
        LoadPlayerFullData(playerid);
        
        // Cargar inventario
        LoadPlayerInventory(playerid);
        
        // Descongelar y spawnear
        TogglePlayerControllable(playerid, true);
        SetCameraBehindPlayer(playerid);
        SpawnPlayer(playerid);

        new name[MAX_PLAYER_NAME];
        GetPlayerName(playerid, name, sizeof(name));
        new msg[128];
        format(msg, sizeof(msg), "[Sistema] %s se ha conectado al servidor. [ID: %d]", name, playerid);
        SendClientMessageToAll(COLOR_GREEN, msg);

        // Actualizar última conexión
        UpdateLastLogin(playerid);
        
        SendClientMessage(playerid, COLOR_GREEN, "[Sistema] Login exitoso! Bienvenido.");
    } else {
        SendClientMessage(playerid, COLOR_RED, "[!] Contrasena incorrecta.");
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
            "DAIS RP - Iniciar Sesion",
            "Contrasena incorrecta. Intenta de nuevo:",
            "Entrar", "Salir");
    }
}

HandleRegister(playerid, const inputtext[]) {
    if(strlen(inputtext) < 6) {
        SendClientMessage(playerid, COLOR_RED, "[!] La contrasena debe tener al menos 6 caracteres.");
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT,
            "DAIS RP - Registro",
            "La contrasena es muy corta (minimo 6 caracteres):",
            "Siguiente", "Salir");
        return;
    }
    
    // Guardar contraseña temporal
    strmid(g_TempPassword[playerid], inputtext, 0, strlen(inputtext), 65);
    
    // Confirmar contraseña
    ShowPlayerDialog(playerid, DIALOG_REGISTER2, DIALOG_STYLE_INPUT,
        "DAIS RP - Confirmar Contrasena",
        "Confirma tu contrasena:",
        "Registrar", "Cancelar");
}

HandleRegisterConfirm(playerid, const inputtext[]) {
    if(strcmp(inputtext, g_TempPassword[playerid]) != 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] Las contrasenas no coinciden.");
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT,
            "DAIS RP - Registro",
            "Las contrasenas no coinciden. Ingresa tu contrasena:",
            "Siguiente", "Salir");
        return;
    }

    // Seleccionar sexo
    ShowPlayerDialog(playerid, DIALOG_SEX, DIALOG_STYLE_LIST,
        "Selecciona tu Sexo",
        "Hombre (Skin 250)\nMujer (Skin 13)",
        "Seleccionar", "Cancelar");
}

CreatePlayerAccount(playerid) {
    new name[MAX_PLAYER_NAME], ip[20], query[512], date[32];
    
    GetPlayerName(playerid, name, sizeof(name));
    GetPlayerIp(playerid, ip, sizeof(ip));
    
    // Obtener fecha actual
    new year, month, day, hour, minute, second;
    getdate(year, month, day);
    gettime(hour, minute, second);
    format(date, sizeof(date), "%04d-%02d-%02d %02d:%02d:%02d", 
        year, month, day, hour, minute, second);

    // Generar número de teléfono
    new phone = 600000000 + random(89999999);

    // Insertar en base de datos
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `players` (`name`,`password`,`sex`,`cash`,`bank`,`phone`,`register_date`,`last_login`,`ip`) \
        VALUES ('%e','%s',%d,5000,10000,%d,'%s','%s','%s')",
        name, g_TempPassword[playerid], PlayerData[playerid][pSex], phone, date, date, ip);
    
    g_MysqlRaceCheck[playerid] = mysql_tquery(g_SQL, query, "OnPlayerRegister", "i", playerid);
}

public OnPlayerRegister(playerid) {
    // Obtener el ID insertado
    PlayerData[playerid][pID] = cache_insert_id();
    
    // Inicializar datos del jugador
    PlayerData[playerid][pRegistered] = true;
    PlayerData[playerid][pLogged] = true;
    PlayerData[playerid][pCash] = 5000;
    PlayerData[playerid][pBank] = 10000;
    PlayerData[playerid][pHunger] = 100;
    PlayerData[playerid][pThirst] = 100;
    PlayerData[playerid][pLevel] = 1;
    PlayerData[playerid][pState] = STATE_ALIVE;
    PlayerData[playerid][pHealth] = 100.0;
    PlayerData[playerid][pX] = 1958.3783;
    PlayerData[playerid][pY] = 1343.1572;
    PlayerData[playerid][pZ] = 15.3746;
    PlayerData[playerid][pAngle] = 269.1425;

    // Descongelar y spawnear
    TogglePlayerControllable(playerid, true);
    SetCameraBehindPlayer(playerid);
    SpawnPlayer(playerid);

    // Mensajes de bienvenida
    SendClientMessage(playerid, COLOR_GOLD, "========================================");
    SendClientMessage(playerid, COLOR_GREEN, "[DAIS RP] Registro exitoso! Bienvenido.");
    SendClientMessage(playerid, COLOR_WHITE, "  Has recibido: $5,000 en efectivo y $10,000 en el banco.");
    SendClientMessage(playerid, COLOR_WHITE, "  Usa /ayuda para ver los comandos disponibles.");
    SendClientMessage(playerid, COLOR_GOLD, "========================================");

    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    new msg[128];
    format(msg, sizeof(msg), "[Sistema] %s se ha registrado en el servidor.", name);
    SendClientMessageToAll(COLOR_GREEN, msg);
}

LoadPlayerFullData(playerid) {
    new query[256];
    mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `players` WHERE `id` = %d", PlayerData[playerid][pID]);
    g_MysqlRaceCheck[playerid] = mysql_tquery(g_SQL, query, "OnPlayerFullDataLoad", "i", playerid);
}

public OnPlayerFullDataLoad(playerid) {
    if(cache_num_rows() > 0) {
        // Cargar todos los datos del jugador
        PlayerData[playerid][pCash]         = cache_get_value_name_int(0, "cash");
        PlayerData[playerid][pBank]         = cache_get_value_name_int(0, "bank");
        PlayerData[playerid][pHealth]       = cache_get_value_name_float(0, "health");
        PlayerData[playerid][pArmour]       = cache_get_value_name_float(0, "armour");
        PlayerData[playerid][pHunger]       = cache_get_value_name_int(0, "hunger");
        PlayerData[playerid][pThirst]       = cache_get_value_name_int(0, "thirst");
        PlayerData[playerid][pLevel]        = cache_get_value_name_int(0, "level");
        PlayerData[playerid][pExp]          = cache_get_value_name_int(0, "exp");
        PlayerData[playerid][pFaction]      = cache_get_value_name_int(0, "faction");
        PlayerData[playerid][pFactionRank]  = cache_get_value_name_int(0, "faction_rank");
        PlayerData[playerid][pJob]          = cache_get_value_name_int(0, "job");
        PlayerData[playerid][pLicenses]     = cache_get_value_name_int(0, "licenses");
        PlayerData[playerid][pWanted]       = cache_get_value_name_int(0, "wanted");
        PlayerData[playerid][pWarns]        = cache_get_value_name_int(0, "warns");
        PlayerData[playerid][pJailTime]     = cache_get_value_name_int(0, "jail_time");
        PlayerData[playerid][pSkin]         = cache_get_value_name_int(0, "skin");
        PlayerData[playerid][pX]            = cache_get_value_name_float(0, "x");
        PlayerData[playerid][pY]            = cache_get_value_name_float(0, "y");
        PlayerData[playerid][pZ]            = cache_get_value_name_float(0, "z");
        PlayerData[playerid][pAngle]        = cache_get_value_name_float(0, "angle");
        PlayerData[playerid][pInterior]     = cache_get_value_name_int(0, "interior");
        PlayerData[playerid][pVW]           = cache_get_value_name_int(0, "vw");
        PlayerData[playerid][pPlayTime]     = cache_get_value_name_int(0, "playtime");
        PlayerData[playerid][pKills]        = cache_get_value_name_int(0, "kills");
        PlayerData[playerid][pDeaths]       = cache_get_value_name_int(0, "deaths");
        PlayerData[playerid][pPhoneNumber]  = cache_get_value_name_int(0, "phone");
        PlayerData[playerid][pPhoneCredit]  = cache_get_value_name_int(0, "phone_credit");
        PlayerData[playerid][pReputation]   = cache_get_value_name_int(0, "reputation");
        PlayerData[playerid][pHouseID]      = cache_get_value_name_int(0, "house_id");
        PlayerData[playerid][pBizID]        = cache_get_value_name_int(0, "biz_id");
        PlayerData[playerid][pClanID]       = cache_get_value_name_int(0, "clan_id");
        PlayerData[playerid][pClanRank]     = cache_get_value_name_int(0, "clan_rank");
        PlayerData[playerid][pAchievements] = cache_get_value_name_int(0, "achievements");
        PlayerData[playerid][pAdminLevel]   = cache_get_value_name_int(0, "admin_level");
        PlayerData[playerid][pMuteTime]     = cache_get_value_name_int(0, "mute_time");
    }
}

// =============================================================================
//  SISTEMA DE INVENTARIO
// =============================================================================
LoadPlayerInventory(playerid) {
    new query[256];
    mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `inventory` WHERE `player_id` = %d ORDER BY `slot`", PlayerData[playerid][pID]);
    g_MysqlRaceCheck[playerid] = mysql_tquery(g_SQL, query, "OnPlayerInventoryLoad", "i", playerid);
}

public OnPlayerInventoryLoad(playerid) {
    // Limpiar inventario
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        PlayerInventory[playerid][s][0] = 0;
        PlayerInventory[playerid][s][1] = 0;
    }
    
    new rows = cache_num_rows();
    for(new r = 0; r < rows; r++) {
        new slot = cache_get_value_name_int(r, "slot");
        if(slot >= 0 && slot < MAX_INV_SLOTS) {
            PlayerInventory[playerid][slot][0] = cache_get_value_name_int(r, "item_id");
            PlayerInventory[playerid][slot][1] = cache_get_value_name_int(r, "amount");
        }
    }
}

SavePlayerInventory(playerid) {
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pLogged]) return;
    
    new query[256];
    
    // Eliminar inventario actual
    mysql_format(g_SQL, query, sizeof(query), "DELETE FROM `inventory` WHERE `player_id` = %d", PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "", "");
    
    // Insertar nuevo inventario
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(PlayerInventory[playerid][s][0] > 0 && PlayerInventory[playerid][s][1] > 0) {
            mysql_format(g_SQL, query, sizeof(query),
                "INSERT INTO `inventory` (`player_id`, `slot`, `item_id`, `amount`) VALUES (%d, %d, %d, %d)",
                PlayerData[playerid][pID], s, PlayerInventory[playerid][s][0], PlayerInventory[playerid][s][1]);
            mysql_tquery(g_SQL, query, "", "");
        }
    }
}

AddItemToInventory(playerid, itemid, amount) {
    if(itemid < 1 || itemid >= MAX_ITEMS) return 0;
    
    // Verificar si ya tiene el item
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(PlayerInventory[playerid][s][0] == itemid) {
            PlayerInventory[playerid][s][1] += amount;
            SendClientMessage(playerid, COLOR_GREEN, "[Inventario] Item agregado.");
            return 1;
        }
    }
    
    // Buscar slot vacío
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(PlayerInventory[playerid][s][0] == 0) {
            PlayerInventory[playerid][s][0] = itemid;
            PlayerInventory[playerid][s][1] = amount;
            SendClientMessage(playerid, COLOR_GREEN, "[Inventario] Item agregado.");
            return 1;
        }
    }
    
    SendClientMessage(playerid, COLOR_RED, "[!] Inventario lleno.");
    return 0;
}

RemoveItemFromInventory(playerid, itemid, amount) {
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(PlayerInventory[playerid][s][0] == itemid) {
            PlayerInventory[playerid][s][1] -= amount;
            if(PlayerInventory[playerid][s][1] <= 0) {
                PlayerInventory[playerid][s][0] = 0;
                PlayerInventory[playerid][s][1] = 0;
            }
            SendClientMessage(playerid, COLOR_GREEN, "[Inventario] Item removido.");
            return 1;
        }
    }
    return 0;
}

ShowInventory(playerid) {
    new str[1024], line[128];
    str[0] = '\0';
    
    format(str, sizeof(str), "Slot\tItem\tCantidad\n");
    
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(PlayerInventory[playerid][s][0] > 0) {
            format(line, sizeof(line), "%d\t%s\t%d\n", 
                s+1, ItemData[PlayerInventory[playerid][s][0]][iName], PlayerInventory[playerid][s][1]);
            strcat(str, line);
        }
    }
    
    if(strlen(str) < 20) {
        strcat(str, "Inventario vacio");
    }
    
    ShowPlayerDialog(playerid, DIALOG_INVENTORY, DIALOG_STYLE_TABLIST_HEADERS,
        "Inventario", str, "Usar", "Cerrar");
}

HandleInventorySelection(playerid, listitem) {
    new slot = listitem;
    if(PlayerInventory[playerid][slot][0] == 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] Slot vacio.");
        return;
    }
    
    PlayerData[playerid][pSelectedItem] = slot;
    
    new str[256];
    format(str, sizeof(str), "Item: %s\nCantidad: %d\n\nQue deseas hacer?",
        ItemData[PlayerInventory[playerid][slot][0]][iName], PlayerInventory[playerid][slot][1]);
    
    ShowPlayerDialog(playerid, DIALOG_ITEM_USE, DIALOG_STYLE_LIST,
        "Usar Item", "Usar\nTirar\nCancelar", "Seleccionar", "Cerrar");
}

HandleItemUse(playerid, listitem) {
    new slot = PlayerData[playerid][pSelectedItem];
    if(slot < 0 || slot >= MAX_INV_SLOTS || PlayerInventory[playerid][slot][0] == 0) return;
    
    new itemid = PlayerInventory[playerid][slot][0];
    
    switch(listitem) {
        case 0: { // Usar
            UseItem(playerid, itemid);
            RemoveItemFromInventory(playerid, itemid, 1);
        }
        case 1: { // Tirar
            RemoveItemFromInventory(playerid, itemid, 1);
            SendClientMessage(playerid, COLOR_YELLOW, "[Inventario] Item tirado.");
        }
    }
    
    PlayerData[playerid][pSelectedItem] = -1;
}

UseItem(playerid, itemid) {
    switch(ItemData[itemid][iType]) {
        case ITEM_TYPE_FOOD: {
            PlayerData[playerid][pHunger] += ItemData[itemid][iValue];
            if(PlayerData[playerid][pHunger] > 100) PlayerData[playerid][pHunger] = 100;
            SendClientMessage(playerid, COLOR_GREEN, "[Item] Has comido.");
            UpdatePlayerHUD(playerid);
        }
        case ITEM_TYPE_DRINK: {
            PlayerData[playerid][pThirst] += ItemData[itemid][iValue];
            if(PlayerData[playerid][pThirst] > 100) PlayerData[playerid][pThirst] = 100;
            SendClientMessage(playerid, COLOR_GREEN, "[Item] Has bebido.");
            UpdatePlayerHUD(playerid);
        }
        case ITEM_TYPE_MEDICAL: {
            new Float:health;
            GetPlayerHealth(playerid, health);
            SetPlayerHealth(playerid, health + ItemData[itemid][iValue]);
            SendClientMessage(playerid, COLOR_GREEN, "[Item] Has usado un botiquin.");
        }
        case ITEM_TYPE_TOOL: {
            // Herramientas para vehículos, etc
            if(itemid == 4) { // Llave inglesa
                if(IsPlayerInAnyVehicle(playerid)) {
                    RepairVehicle(GetPlayerVehicleID(playerid));
                    SendClientMessage(playerid, COLOR_GREEN, "[Item] Has reparado el vehiculo.");
                }
            }
        }
    }
}

// =============================================================================
//  SISTEMA DE VEHÍCULOS
// =============================================================================
public LoadVehicles() {
    mysql_tquery(g_SQL, "SELECT * FROM `vehicles`", "OnVehiclesLoad", "");
}

public OnVehiclesLoad() {
    new rows = cache_num_rows();
    for(new r = 0; r < rows && r < MAX_VEHICLES_RP; r++) {
        new id = cache_get_value_name_int(r, "id");
        VehicleData[id][vID] = id;
        cache_get_value_name(r, "owner", VehicleData[id][vOwner], MAX_PLAYER_NAME);
        VehicleData[id][vModel] = cache_get_value_name_int(r, "model");
        VehicleData[id][vX] = cache_get_value_name_float(r, "x");
        VehicleData[id][vY] = cache_get_value_name_float(r, "y");
        VehicleData[id][vZ] = cache_get_value_name_float(r, "z");
        VehicleData[id][vAngle] = cache_get_value_name_float(r, "angle");
        VehicleData[id][vColor1] = cache_get_value_name_int(r, "color1");
        VehicleData[id][vColor2] = cache_get_value_name_int(r, "color2");
        VehicleData[id][vFuel] = cache_get_value_name_int(r, "fuel");
        VehicleData[id][vMaxFuel] = cache_get_value_name_int(r, "max_fuel");
        VehicleData[id][vMileage] = cache_get_value_name_int(r, "mileage");
        VehicleData[id][vHealth] = cache_get_value_name_float(r, "health");
        VehicleData[id][vLocked] = bool:cache_get_value_name_int(r, "locked");
        VehicleData[id][vInsured] = bool:cache_get_value_name_int(r, "insured");
        
        // Cargar tuning
        new tuningStr[128];
        cache_get_value_name(r, "tuning", tuningStr);
        if(strlen(tuningStr) > 0) {
            new parts[12], partIndex;
            for(new i = 0; i < 12; i++) {
                parts[i] = 0;
            }
            sscanf(tuningStr, "p<,>a<d>[12]", parts);
            for(new i = 0; i < 12; i++) {
                VehicleData[id][vTuning][i] = parts[i];
            }
        }
        
        cache_get_value_name(r, "plate", VehicleData[id][vPlate]);
        VehicleData[id][vPrice] = cache_get_value_name_int(r, "price");
        VehicleData[id][vFaction] = cache_get_value_name_int(r, "faction");
        
        // Crear vehículo
        new vehicleid = CreateVehicle(VehicleData[id][vModel],
            VehicleData[id][vX], VehicleData[id][vY], VehicleData[id][vZ],
            VehicleData[id][vAngle], VehicleData[id][vColor1], VehicleData[id][vColor2], -1);
        
        SetVehicleHealth(vehicleid, VehicleData[id][vHealth]);
        
        // Aplicar tuning
        for(new i = 0; i < 12; i++) {
            if(VehicleData[id][vTuning][i] > 0) {
                AddVehicleComponent(vehicleid, VehicleData[id][vTuning][i]);
            }
        }
        
        // Cargar maletero
        LoadVehicleTrunk(id);
    }
    printf("[Vehículos] %d vehículos cargados.", rows);
}

LoadVehicleTrunk(vehicleid) {
    new query[256];
    mysql_format(g_SQL, query, sizeof(query), "SELECT * FROM `vehicle_trunk` WHERE `vehicle_id` = %d ORDER BY `slot`", vehicleid);
    mysql_tquery(g_SQL, query, "OnVehicleTrunkLoad", "i", vehicleid);
}

public OnVehicleTrunkLoad(vehicleid) {
    // Limpiar maletero
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        VehicleData[vehicleid][vTrunkItems][s][0] = 0;
        VehicleData[vehicleid][vTrunkItems][s][1] = 0;
    }
    
    new rows = cache_num_rows();
    for(new r = 0; r < rows; r++) {
        new slot = cache_get_value_name_int(r, "slot");
        if(slot >= 0 && slot < MAX_INV_SLOTS) {
            VehicleData[vehicleid][vTrunkItems][slot][0] = cache_get_value_name_int(r, "item_id");
            VehicleData[vehicleid][vTrunkItems][slot][1] = cache_get_value_name_int(r, "amount");
        }
    }
}

SaveVehicleTrunk(vehicleid) {
    if(vehicleid < 0 || vehicleid >= MAX_VEHICLES_RP) return;
    
    new query[256];
    
    // Eliminar maletero actual
    mysql_format(g_SQL, query, sizeof(query), "DELETE FROM `vehicle_trunk` WHERE `vehicle_id` = %d", VehicleData[vehicleid][vID]);
    mysql_tquery(g_SQL, query, "", "");
    
    // Insertar nuevo maletero
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(VehicleData[vehicleid][vTrunkItems][s][0] > 0 && VehicleData[vehicleid][vTrunkItems][s][1] > 0) {
            mysql_format(g_SQL, query, sizeof(query),
                "INSERT INTO `vehicle_trunk` (`vehicle_id`, `slot`, `item_id`, `amount`) VALUES (%d, %d, %d, %d)",
                VehicleData[vehicleid][vID], s, VehicleData[vehicleid][vTrunkItems][s][0], VehicleData[vehicleid][vTrunkItems][s][1]);
            mysql_tquery(g_SQL, query, "", "");
        }
    }
}

ShowVehicleMenu(playerid) {
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] No estas en un vehiculo.");
        return;
    }
    
    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    
    new str[256];
    format(str, sizeof(str),
        "Motor: %s\nLuces: %s\nPuertas: %s\nMaletero\nInformacion",
        engine ? "Encendido" : "Apagado",
        lights ? "Encendidas" : "Apagadas",
        doors ? "Abiertas" : "Cerradas");
    
    ShowPlayerDialog(playerid, DIALOG_VEHICLE_MENU, DIALOG_STYLE_LIST,
        "Menu del Vehiculo", str, "Seleccionar", "Cerrar");
}

HandleVehicleMenu(playerid, listitem) {
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) return;
    
    new engine, lights, alarm, doors, bonnet, boot, objective;
    GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
    
    switch(listitem) {
        case 0: { // Motor
            engine = !engine;
            SetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
            SendClientMessage(playerid, COLOR_WHITE, engine ? "[Vehiculo] Motor encendido." : "[Vehiculo] Motor apagado.");
        }
        case 1: { // Luces
            lights = !lights;
            SetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
            SendClientMessage(playerid, COLOR_WHITE, lights ? "[Vehiculo] Luces encendidas." : "[Vehiculo] Luces apagadas.");
        }
        case 2: { // Puertas
            doors = !doors;
            SetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
            SendClientMessage(playerid, COLOR_WHITE, doors ? "[Vehiculo] Puertas abiertas." : "[Vehiculo] Puertas cerradas.");
        }
        case 3: { // Maletero
            ShowTrunkMenu(playerid, vehicleid);
        }
        case 4: { // Informacion
            ShowVehicleInfo(playerid, vehicleid);
        }
    }
}

ShowTrunkMenu(playerid, vehicleid) {
    new str[1024], line[128];
    str[0] = '\0';
    
    format(str, sizeof(str), "Slot\tItem\tCantidad\n");
    
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(VehicleData[vehicleid][vTrunkItems][s][0] > 0) {
            format(line, sizeof(line), "%d\t%s\t%d\n", 
                s+1, ItemData[VehicleData[vehicleid][vTrunkItems][s][0]][iName], VehicleData[vehicleid][vTrunkItems][s][1]);
            strcat(str, line);
        }
    }
    
    if(strlen(str) < 20) {
        strcat(str, "Maletero vacio");
    }
    
    ShowPlayerDialog(playerid, DIALOG_TRUNK, DIALOG_STYLE_TABLIST_HEADERS,
        "Maletero", str, "Seleccionar", "Cerrar");
}

HandleTrunkMenu(playerid, listitem) {
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) return;
    
    new slot = listitem;
    if(VehicleData[vehicleid][vTrunkItems][slot][0] == 0) return;
    
    new itemid = VehicleData[vehicleid][vTrunkItems][slot][0];
    new amount = VehicleData[vehicleid][vTrunkItems][slot][1];
    
    // Transferir del maletero al inventario
    if(AddItemToInventory(playerid, itemid, 1)) {
        VehicleData[vehicleid][vTrunkItems][slot][1]--;
        if(VehicleData[vehicleid][vTrunkItems][slot][1] <= 0) {
            VehicleData[vehicleid][vTrunkItems][slot][0] = 0;
        }
        SendClientMessage(playerid, COLOR_GREEN, "[Maletero] Item transferido a tu inventario.");
        SaveVehicleTrunk(vehicleid);
    }
}

ShowVehicleInfo(playerid, vehicleid) {
    new ownerName[32];
    if(strlen(VehicleData[vehicleid][vOwner]) > 0) {
        format(ownerName, sizeof(ownerName), "%s", VehicleData[vehicleid][vOwner]);
    } else {
        ownerName = "Nadie";
    }
    
    new str[512];
    format(str, sizeof(str),
        "Informacion del Vehiculo\n\n\
        Modelo: %d\n\
        Propietario: %s\n\
        Combustible: %d/%d\n\
        Kilometraje: %d km\n\
        Precio: $%d\n\
        Estado: %s",
        VehicleData[vehicleid][vModel],
        ownerName,
        VehicleData[vehicleid][vFuel], VehicleData[vehicleid][vMaxFuel],
        VehicleData[vehicleid][vMileage],
        VehicleData[vehicleid][vPrice],
        VehicleData[vehicleid][vLocked] ? "Cerrado" : "Abierto");
    
    ShowPlayerDialog(playerid, -1, DIALOG_STYLE_MSGBOX, "Info Vehiculo", str, "Cerrar", "");
}

// =============================================================================
//  SISTEMA DE COMBUSTIBLE
// =============================================================================
public FuelConsumptionUpdate() {
    for(new i = 0; i < MAX_PLAYERS; i++) {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        
        new vehicleid = GetPlayerVehicleID(i);
        if(vehicleid == 0) continue;
        
        if(GetPlayerVehicleSeat(i) != 0) continue;
        
        new engine, lights, alarm, doors, bonnet, boot, objective;
        GetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
        
        if(engine) {
            new Float:speed;
            GetVehicleVelocity(vehicleid, speed, speed, speed);
            speed = floatsqroot(floatpower(speed, 2.0) + floatpower(speed, 2.0) + floatpower(speed, 2.0)) * 200.0;
            
            if(speed > 5) {
                VehicleData[vehicleid][vFuel] -= 1;
                if(VehicleData[vehicleid][vFuel] < 0) VehicleData[vehicleid][vFuel] = 0;
                
                if(VehicleData[vehicleid][vFuel] <= 0) {
                    engine = 0;
                    SetVehicleParamsEx(vehicleid, engine, lights, alarm, doors, bonnet, boot, objective);
                    SendClientMessage(i, COLOR_RED, "[!] Vehiculo sin combustible.");
                }
            }
            
            UpdatePlayerHUD(i);
        }
    }
}

RefuelVehicle(playerid, vehicleid, amount, pricePerUnit) {
    new cost = amount * pricePerUnit;
    if(PlayerData[playerid][pCash] < cost) {
        SendClientMessage(playerid, COLOR_RED, "[!] No tienes suficiente dinero.");
        return 0;
    }
    
    new refuel = amount;
    if(VehicleData[vehicleid][vFuel] + refuel > VehicleData[vehicleid][vMaxFuel]) {
        refuel = VehicleData[vehicleid][vMaxFuel] - VehicleData[vehicleid][vFuel];
        cost = refuel * pricePerUnit;
    }
    
    if(refuel <= 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] El tanque ya esta lleno.");
        return 0;
    }
    
    GivePlayerMoney_RP(playerid, -cost);
    VehicleData[vehicleid][vFuel] += refuel;
    
    new msg[128];
    format(msg, sizeof(msg), "[Gasolinera] Has cargado %dL por $%d.", refuel, cost);
    SendClientMessage(playerid, COLOR_GREEN, msg);
    
    return 1;
}

// =============================================================================
//  SISTEMA DE GASOLINERAS
// =============================================================================
public LoadGasStations() {
    mysql_tquery(g_SQL, "SELECT * FROM `gas_stations`", "OnGasStationsLoad", "");
}

public OnGasStationsLoad() {
    new rows = cache_num_rows();
    g_TotalGasStations = rows;
    
    for(new r = 0; r < rows && r < MAX_GAS_STATIONS; r++) {
        GasStationData[r][gsID] = cache_get_value_name_int(r, "id");
        GasStationData[r][gsX] = cache_get_value_name_float(r, "x");
        GasStationData[r][gsY] = cache_get_value_name_float(r, "y");
        GasStationData[r][gsZ] = cache_get_value_name_float(r, "z");
        GasStationData[r][gsFuel] = cache_get_value_name_int(r, "fuel");
        GasStationData[r][gsPrice] = cache_get_value_name_int(r, "price");
        
        // Crear pickup
        GasStationData[r][gsPickup] = CreatePickup(1239, 23, 
            GasStationData[r][gsX], GasStationData[r][gsY], GasStationData[r][gsZ], 0);
        
        // Crear label 3D
        new label[128];
        format(label, sizeof(label), "[Gasolinera]\nPrecio: $%d/L\nCombustible: %dL", 
            GasStationData[r][gsPrice], GasStationData[r][gsFuel]);
        
        GasStationData[r][gsLabel] = Create3DTextLabel(label, COLOR_YELLOW,
            GasStationData[r][gsX], GasStationData[r][gsY], GasStationData[r][gsZ] + 0.5, 10.0, 0);
    }
    printf("[Gasolineras] %d gasolineras cargadas.", rows);
}

ShowGasStationMenu(playerid, stationid) {
    new str[256];
    format(str, sizeof(str),
        "Precio por litro: $%d\nCombustible disponible: %dL\n\nCuantos litros deseas cargar?",
        GasStationData[stationid][gsPrice], GasStationData[stationid][gsFuel]);
    
    ShowPlayerDialog(playerid, DIALOG_GAS_STATION, DIALOG_STYLE_INPUT,
        "Gasolinera", str, "Cargar", "Cancelar");
}

HandleGasStation(playerid, listitem, inputtext[]) {
    #pragma unused listitem
    
    new amount = strval(inputtext);
    if(amount < 1 || amount > 100) {
        SendClientMessage(playerid, COLOR_RED, "[!] Cantidad invalida (1-100).");
        return;
    }
    
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] No estas en un vehiculo.");
        return;
    }
    
    // Buscar gasolinera cercana
    new stationid = -1;
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    
    for(new i = 0; i < g_TotalGasStations; i++) {
        if(IsPlayerInRangeOfPoint(playerid, 10.0, GasStationData[i][gsX], GasStationData[i][gsY], GasStationData[i][gsZ])) {
            stationid = i;
            break;
        }
    }
    
    if(stationid == -1) {
        SendClientMessage(playerid, COLOR_RED, "[!] No estas cerca de una gasolinera.");
        return;
    }
    
    if(amount > GasStationData[stationid][gsFuel]) {
        SendClientMessage(playerid, COLOR_RED, "[!] No hay suficiente combustible.");
        return;
    }
    
    if(RefuelVehicle(playerid, vehicleid, amount, GasStationData[stationid][gsPrice])) {
        GasStationData[stationid][gsFuel] -= amount;
        
        // Actualizar label
        new label[128];
        format(label, sizeof(label), "[Gasolinera]\nPrecio: $%d/L\nCombustible: %dL", 
            GasStationData[stationid][gsPrice], GasStationData[stationid][gsFuel]);
        Update3DTextLabelText(GasStationData[stationid][gsLabel], COLOR_YELLOW, label);
    }
}

// =============================================================================
//  SISTEMA DE CONCESIONARIOS
// =============================================================================
public LoadDealerships() {
    mysql_tquery(g_SQL, "SELECT * FROM `dealerships`", "OnDealershipsLoad", "");
}

public OnDealershipsLoad() {
    new rows = cache_num_rows();
    g_TotalDealerships = rows;
    
    for(new r = 0; r < rows && r < MAX_DEALERSHIPS; r++) {
        DealershipData[r][dsID] = cache_get_value_name_int(r, "id");
        cache_get_value_name(r, "name", DealershipData[r][dsName], 64);
        DealershipData[r][dsX] = cache_get_value_name_float(r, "x");
        DealershipData[r][dsY] = cache_get_value_name_float(r, "y");
        DealershipData[r][dsZ] = cache_get_value_name_float(r, "z");
        
        // Cargar vehículos
        new vehiclesStr[256];
        cache_get_value_name(r, "vehicles", vehiclesStr);
        if(strlen(vehiclesStr) > 0) {
            new pos, count;
            new temp[32];
            for(new i = 0; i < 20 && count < 20; i++) {
                pos = strfind(vehiclesStr, ",", false, pos);
                if(pos == -1) break;
                
                strmid(temp, vehiclesStr, 0, pos);
                new model, price;
                sscanf(temp, "p<:>dd", model, price);
                DealershipData[r][dsVehicles][count][0] = model;
                DealershipData[r][dsVehicles][count][1] = price;
                count++;
            }
        }
        
        // Crear pickup
        DealershipData[r][dsPickup] = CreatePickup(1274, 23, 
            DealershipData[r][dsX], DealershipData[r][dsY], DealershipData[r][dsZ], 0);
        
        // Crear label 3D
        new label[128];
        format(label, sizeof(label), "[Concesionario]\n%s", DealershipData[r][dsName]);
        DealershipData[r][dsLabel] = Create3DTextLabel(label, COLOR_GOLD,
            DealershipData[r][dsX], DealershipData[r][dsY], DealershipData[r][dsZ] + 0.5, 10.0, 0);
    }
    printf("[Concesionarios] %d concesionarios cargados.", rows);
}

ShowDealershipMenu(playerid, dealershipid) {
    new str[256];
    str[0] = '\0';
    
    for(new i = 0; i < 20; i++) {
        if(DealershipData[dealershipid][dsVehicles][i][0] > 0) {
            format(str, sizeof(str), "%s%s\n", str, GetVehicleModelName(DealershipData[dealershipid][dsVehicles][i][0]));
        }
    }
    
    ShowPlayerDialog(playerid, DIALOG_DEALERSHIP, DIALOG_STYLE_LIST,
        DealershipData[dealershipid][dsName], str, "Comprar", "Cerrar");
}

ShowDealershipVehicles(playerid, listitem) {
    new dealershipid = -1;
    for(new i = 0; i < g_TotalDealerships; i++) {
        if(IsPlayerInRangeOfPoint(playerid, 10.0, DealershipData[i][dsX], DealershipData[i][dsY], DealershipData[i][dsZ])) {
            dealershipid = i;
            break;
        }
    }
    
    if(dealershipid == -1) return;
    
    new model = DealershipData[dealershipid][dsVehicles][listitem][0];
    new price = DealershipData[dealershipid][dsVehicles][listitem][1];
    
    new str[256];
    format(str, sizeof(str),
        "Vehiculo: %s\nPrecio: $%d\n\nEstas seguro que deseas comprarlo?",
        GetVehicleModelName(model), price);
    
    ShowPlayerDialog(playerid, DIALOG_BUY_VEHICLE, DIALOG_STYLE_MSGBOX,
        "Confirmar Compra", str, "Comprar", "Cancelar");
}

BuyVehicle(playerid, listitem) {
    #pragma unused listitem
    
    new dealershipid = -1;
    for(new i = 0; i < g_TotalDealerships; i++) {
        if(IsPlayerInRangeOfPoint(playerid, 10.0, DealershipData[i][dsX], DealershipData[i][dsY], DealershipData[i][dsZ])) {
            dealershipid = i;
            break;
        }
    }
    
    if(dealershipid == -1) return;
    
    new model = DealershipData[dealershipid][dsVehicles][listitem][0];
    new price = DealershipData[dealershipid][dsVehicles][listitem][1];
    
    if(PlayerData[playerid][pCash] < price) {
        SendClientMessage(playerid, COLOR_RED, "[!] No tienes suficiente dinero.");
        return;
    }
    
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    
    // Buscar slot libre
    new slot = -1;
    for(new i = 0; i < MAX_VEHICLES_RP; i++) {
        if(VehicleData[i][vID] == 0) {
            slot = i;
            break;
        }
    }
    
    if(slot == -1) {
        SendClientMessage(playerid, COLOR_RED, "[!] No hay slots disponibles para vehiculos.");
        return;
    }
    
    // Crear vehículo
    new Float:x, Float:y, Float:z, Float:angle;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, angle);
    
    VehicleData[slot][vID] = slot;
    strmid(VehicleData[slot][vOwner], name, 0, strlen(name), MAX_PLAYER_NAME);
    VehicleData[slot][vModel] = model;
    VehicleData[slot][vX] = x + 5.0;
    VehicleData[slot][vY] = y;
    VehicleData[slot][vZ] = z;
    VehicleData[slot][vAngle] = angle;
    VehicleData[slot][vColor1] = random(126);
    VehicleData[slot][vColor2] = random(126);
    VehicleData[slot][vFuel] = 100;
    VehicleData[slot][vMaxFuel] = 100;
    VehicleData[slot][vPrice] = price;
    VehicleData[slot][vLocked] = false;
    
    CreateVehicle(model, x + 5.0, y, z, angle, VehicleData[slot][vColor1], VehicleData[slot][vColor2], -1);
    
    GivePlayerMoney_RP(playerid, -price);
    
    new msg[128];
    format(msg, sizeof(msg), "[Concesionario] Has comprado un %s por $%d.", GetVehicleModelName(model), price);
    SendClientMessage(playerid, COLOR_GREEN, msg);
    
    // Guardar en BD
    SaveVehicleToDB(slot);
}

SaveVehicleToDB(vehicleid) {
    new query[1024];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `vehicles` (`owner`, `model`, `x`, `y`, `z`, `angle`, `color1`, `color2`, `fuel`, `max_fuel`, `price`) \
        VALUES ('%e', %d, %f, %f, %f, %f, %d, %d, %d, %d, %d)",
        VehicleData[vehicleid][vOwner],
        VehicleData[vehicleid][vModel],
        VehicleData[vehicleid][vX],
        VehicleData[vehicleid][vY],
        VehicleData[vehicleid][vZ],
        VehicleData[vehicleid][vAngle],
        VehicleData[vehicleid][vColor1],
        VehicleData[vehicleid][vColor2],
        VehicleData[vehicleid][vFuel],
        VehicleData[vehicleid][vMaxFuel],
        VehicleData[vehicleid][vPrice]);
    
    mysql_tquery(g_SQL, query, "", "");
}

// =============================================================================
//  SISTEMA DE TUNING
// =============================================================================
ShowTuningMenu(playerid) {
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] No estas en un vehiculo.");
        return;
    }
    
    new str[512];
    str[0] = '\0';
    
    // Cargar partes de tuning disponibles
    for(new i = 0; i < MAX_TUNING_PARTS; i++) {
        if(TuningPartData[i][tpID] > 0) {
            format(str, sizeof(str), "%s%s - $%d\n", str, TuningPartData[i][tpName], TuningPartData[i][tpPrice]);
        }
    }
    
    ShowPlayerDialog(playerid, DIALOG_TUNING, DIALOG_STYLE_LIST,
        "Taller de Tuning", str, "Instalar", "Cerrar");
}

HandleTuningMenu(playerid, listitem) {
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) return;
    
    new partid = listitem;
    new price = TuningPartData[partid][tpPrice];
    
    if(PlayerData[playerid][pCash] < price) {
        SendClientMessage(playerid, COLOR_RED, "[!] No tienes suficiente dinero.");
        return;
    }
    
    // Verificar si ya tiene esa parte
    for(new i = 0; i < 12; i++) {
        if(VehicleData[vehicleid][vTuning][i] == TuningPartData[partid][tpModel]) {
            SendClientMessage(playerid, COLOR_RED, "[!] Ya tienes instalada esa pieza.");
            return;
        }
    }
    
    // Buscar slot libre
    for(new i = 0; i < 12; i++) {
        if(VehicleData[vehicleid][vTuning][i] == 0) {
            VehicleData[vehicleid][vTuning][i] = TuningPartData[partid][tpModel];
            AddVehicleComponent(vehicleid, TuningPartData[partid][tpModel]);
            GivePlayerMoney_RP(playerid, -price);
            
            new msg[128];
            format(msg, sizeof(msg), "[Tuning] Has instalado %s por $%d.", TuningPartData[partid][tpName], price);
            SendClientMessage(playerid, COLOR_GREEN, msg);
            
            // Guardar en BD
            UpdateVehicleTuning(vehicleid);
            return;
        }
    }
    
    SendClientMessage(playerid, COLOR_RED, "[!] No hay espacio para mas piezas.");
}

UpdateVehicleTuning(vehicleid) {
    new tuningStr[128], query[256];
    tuningStr[0] = '\0';
    
    for(new i = 0; i < 12; i++) {
        if(VehicleData[vehicleid][vTuning][i] > 0) {
            if(strlen(tuningStr) > 0) {
                format(tuningStr, sizeof(tuningStr), "%s,%d", tuningStr, VehicleData[vehicleid][vTuning][i]);
            } else {
                format(tuningStr, sizeof(tuningStr), "%d", VehicleData[vehicleid][vTuning][i]);
            }
        }
    }
    
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `vehicles` SET `tuning` = '%s' WHERE `id` = %d",
        tuningStr, VehicleData[vehicleid][vID]);
    mysql_tquery(g_SQL, query, "", "");
}

// =============================================================================
//  SISTEMA DE ADMIN
// =============================================================================
CreateAdminVehicle(playerid, listitem) {
    new models[][] = {
        400, 401, 402, 403, 404, 405, 406, 407, 408, 409,
        410, 411, 412, 413, 414, 415, 416, 417, 418, 419
    };
    
    new model = models[listitem];
    new Float:x, Float:y, Float:z, Float:angle;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, angle);
    
    new vehicleid = CreateVehicle(model, x + 5.0, y, z, angle, random(126), random(126), -1);
    
    new msg[128];
    format(msg, sizeof(msg), "[Admin] Has creado un vehiculo modelo %d.", model);
    SendClientMessage(playerid, COLOR_GREEN, msg);
}

CreateGasStation(playerid) {
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    
    if(g_TotalGasStations >= MAX_GAS_STATIONS) {
        SendClientMessage(playerid, COLOR_RED, "[!] Limite de gasolineras alcanzado.");
        return;
    }
    
    new id = g_TotalGasStations;
    GasStationData[id][gsID] = id;
    GasStationData[id][gsX] = x;
    GasStationData[id][gsY] = y;
    GasStationData[id][gsZ] = z;
    GasStationData[id][gsFuel] = 10000;
    GasStationData[id][gsPrice] = 5;
    
    GasStationData[id][gsPickup] = CreatePickup(1239, 23, x, y, z, 0);
    
    new label[128];
    format(label, sizeof(label), "[Gasolinera]\nPrecio: $5/L\nCombustible: 10000L");
    GasStationData[id][gsLabel] = Create3DTextLabel(label, COLOR_YELLOW, x, y, z + 0.5, 10.0, 0);
    
    g_TotalGasStations++;
    
    new query[256];
    mysql_format(g_SQL, query, sizeof(query),
        "INSERT INTO `gas_stations` (`x`, `y`, `z`, `fuel`, `price`) VALUES (%f, %f, %f, 10000, 5)",
        x, y, z);
    mysql_tquery(g_SQL, query, "", "");
    
    SendClientMessage(playerid, COLOR_GREEN, "[Admin] Gasolinera creada correctamente.");
}

// =============================================================================
//  HUD PERSONALIZADO
// =============================================================================
CreatePlayerHUD(playerid) {
    // Fondo del HUD
    pHUD_Background[playerid] = CreatePlayerTextDraw(playerid, 500.0, 360.0, "_");
    PlayerTextDrawUseBox(playerid, pHUD_Background[playerid], 1);
    PlayerTextDrawBoxColor(playerid, pHUD_Background[playerid], 0x00000066);
    PlayerTextDrawTextSize(playerid, pHUD_Background[playerid], 630.0, 0.0);
    PlayerTextDrawLetterSize(playerid, pHUD_Background[playerid], 0.0, 8.0);
    PlayerTextDrawShow(playerid, pHUD_Background[playerid]);
    
    // Barra de hambre
    pHUD_HungerBar[playerid] = CreatePlayerTextDraw(playerid, 510.0, 370.0, "||||||||||||||||||||");
    PlayerTextDrawLetterSize(playerid, pHUD_HungerBar[playerid], 0.3, 0.8);
    PlayerTextDrawColor(playerid, pHUD_HungerBar[playerid], COLOR_ORANGE);
    PlayerTextDrawShow(playerid, pHUD_HungerBar[playerid]);
    
    // Barra de sed
    pHUD_ThirstBar[playerid] = CreatePlayerTextDraw(playerid, 510.0, 385.0, "||||||||||||||||||||");
    PlayerTextDrawLetterSize(playerid, pHUD_ThirstBar[playerid], 0.3, 0.8);
    PlayerTextDrawColor(playerid, pHUD_ThirstBar[playerid], COLOR_BLUE);
    PlayerTextDrawShow(playerid, pHUD_ThirstBar[playerid]);
    
    // Barra de experiencia
    pHUD_ExpBar[playerid] = CreatePlayerTextDraw(playerid, 510.0, 415.0, "||||||||||||||||||||");
    PlayerTextDrawLetterSize(playerid, pHUD_ExpBar[playerid], 0.3, 0.8);
    PlayerTextDrawColor(playerid, pHUD_ExpBar[playerid], COLOR_PURPLE);
    PlayerTextDrawShow(playerid, pHUD_ExpBar[playerid]);
    
    // Textos
    pHUD_HungerText[playerid] = CreatePlayerTextDraw(playerid, 510.0, 370.0, "Hambre: 100%");
    PlayerTextDrawLetterSize(playerid, pHUD_HungerText[playerid], 0.2, 0.8);
    PlayerTextDrawColor(playerid, pHUD_HungerText[playerid], COLOR_WHITE);
    PlayerTextDrawShow(playerid, pHUD_HungerText[playerid]);
    
    pHUD_ThirstText[playerid] = CreatePlayerTextDraw(playerid, 510.0, 385.0, "Sed: 100%");
    PlayerTextDrawLetterSize(playerid, pHUD_ThirstText[playerid], 0.2, 0.8);
    PlayerTextDrawColor(playerid, pHUD_ThirstText[playerid], COLOR_WHITE);
    PlayerTextDrawShow(playerid, pHUD_ThirstText[playerid]);
    
    pHUD_LevelText[playerid] = CreatePlayerTextDraw(playerid, 510.0, 400.0, "Nivel: 1");
    PlayerTextDrawLetterSize(playerid, pHUD_LevelText[playerid], 0.2, 0.8);
    PlayerTextDrawColor(playerid, pHUD_LevelText[playerid], COLOR_GOLD);
    PlayerTextDrawShow(playerid, pHUD_LevelText[playerid]);
    
    pHUD_ExpText[playerid] = CreatePlayerTextDraw(playerid, 510.0, 415.0, "EXP: 0/1000");
    PlayerTextDrawLetterSize(playerid, pHUD_ExpText[playerid], 0.2, 0.8);
    PlayerTextDrawColor(playerid, pHUD_ExpText[playerid], COLOR_WHITE);
    PlayerTextDrawShow(playerid, pHUD_ExpText[playerid]);
    
    pHUD_MoneyText[playerid] = CreatePlayerTextDraw(playerid, 510.0, 430.0, "Efectivo: $0");
    PlayerTextDrawLetterSize(playerid, pHUD_MoneyText[playerid], 0.2, 0.8);
    PlayerTextDrawColor(playerid, pHUD_MoneyText[playerid], COLOR_GREEN);
    PlayerTextDrawShow(playerid, pHUD_MoneyText[playerid]);
    
    pHUD_FuelText[playerid] = CreatePlayerTextDraw(playerid, 510.0, 445.0, "Combustible: 0/0");
    PlayerTextDrawLetterSize(playerid, pHUD_FuelText[playerid], 0.2, 0.8);
    PlayerTextDrawColor(playerid, pHUD_FuelText[playerid], COLOR_YELLOW);
    PlayerTextDrawShow(playerid, pHUD_FuelText[playerid]);
    
    pHUD_SpeedText[playerid] = CreatePlayerTextDraw(playerid, 510.0, 460.0, "Velocidad: 0 km/h");
    PlayerTextDrawLetterSize(playerid, pHUD_SpeedText[playerid], 0.2, 0.8);
    PlayerTextDrawColor(playerid, pHUD_SpeedText[playerid], COLOR_LIGHTBLUE);
    PlayerTextDrawShow(playerid, pHUD_SpeedText[playerid]);
}

UpdatePlayerHUD(playerid) {
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pLogged]) return;
    
    new str[64];
    
    // Actualizar hambre
    format(str, sizeof(str), "Hambre: %d%%", PlayerData[playerid][pHunger]);
    PlayerTextDrawSetString(playerid, pHUD_HungerText[playerid], str);
    
    new hungerBars = PlayerData[playerid][pHunger] / 5;
    new hungerStr[32];
    for(new i = 0; i < 20; i++) {
        if(i < hungerBars) hungerStr[i] = '|';
        else hungerStr[i] = '_';
    }
    hungerStr[20] = '\0';
    PlayerTextDrawSetString(playerid, pHUD_HungerBar[playerid], hungerStr);
    
    // Actualizar sed
    format(str, sizeof(str), "Sed: %d%%", PlayerData[playerid][pThirst]);
    PlayerTextDrawSetString(playerid, pHUD_ThirstText[playerid], str);
    
    new thirstBars = PlayerData[playerid][pThirst] / 5;
    new thirstStr[32];
    for(new i = 0; i < 20; i++) {
        if(i < thirstBars) thirstStr[i] = '|';
        else thirstStr[i] = '_';
    }
    thirstStr[20] = '\0';
    PlayerTextDrawSetString(playerid, pHUD_ThirstBar[playerid], thirstStr);
    
    // Actualizar nivel
    format(str, sizeof(str), "Nivel: %d", PlayerData[playerid][pLevel]);
    PlayerTextDrawSetString(playerid, pHUD_LevelText[playerid], str);
    
    // Actualizar experiencia
    new expNeeded = PlayerData[playerid][pLevel] * 1000;
    format(str, sizeof(str), "EXP: %d/%d", PlayerData[playerid][pExp], expNeeded);
    PlayerTextDrawSetString(playerid, pHUD_ExpText[playerid], str);
    
    new expBars = (PlayerData[playerid][pExp] * 20) / expNeeded;
    new expStr[32];
    for(new i = 0; i < 20; i++) {
        if(i < expBars) expStr[i] = '|';
        else expStr[i] = '_';
    }
    expStr[20] = '\0';
    PlayerTextDrawSetString(playerid, pHUD_ExpBar[playerid], expStr);
    
    // Actualizar dinero
    format(str, sizeof(str), "Efectivo: $%d", PlayerData[playerid][pCash]);
    PlayerTextDrawSetString(playerid, pHUD_MoneyText[playerid], str);
    
    // Actualizar combustible si está en vehículo
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid != 0) {
        format(str, sizeof(str), "Combustible: %d/%d", VehicleData[vehicleid][vFuel], VehicleData[vehicleid][vMaxFuel]);
        PlayerTextDrawSetString(playerid, pHUD_FuelText[playerid], str);
        
        new Float:speed;
        GetVehicleVelocity(vehicleid, speed, speed, speed);
        speed = floatsqroot(floatpower(speed, 2.0) + floatpower(speed, 2.0) + floatpower(speed, 2.0)) * 200.0;
        format(str, sizeof(str), "Velocidad: %.0f km/h", speed);
        PlayerTextDrawSetString(playerid, pHUD_SpeedText[playerid], str);
    } else {
        PlayerTextDrawSetString(playerid, pHUD_FuelText[playerid], "Combustible: 0/0");
        PlayerTextDrawSetString(playerid, pHUD_SpeedText[playerid], "Velocidad: 0 km/h");
    }
}

DestroyPlayerHUD(playerid) {
    PlayerTextDrawDestroy(playerid, pHUD_Background[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_HungerBar[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_ThirstBar[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_ExpBar[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_HungerText[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_ThirstText[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_LevelText[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_ExpText[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_MoneyText[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_FuelText[playerid]);
    PlayerTextDrawDestroy(playerid, pHUD_SpeedText[playerid]);
}

// =============================================================================
//  GUARDADO DE DATOS
// =============================================================================
SavePlayerData(playerid) {
    if(!IsPlayerConnected(playerid) || !PlayerData[playerid][pLogged]) return;

    // Obtener posición actual
    GetPlayerPos(playerid, PlayerData[playerid][pX], PlayerData[playerid][pY], PlayerData[playerid][pZ]);
    GetPlayerFacingAngle(playerid, PlayerData[playerid][pAngle]);
    GetPlayerHealth(playerid, PlayerData[playerid][pHealth]);
    GetPlayerArmour(playerid, PlayerData[playerid][pArmour]);
    
    PlayerData[playerid][pInterior] = GetPlayerInterior(playerid);
    PlayerData[playerid][pVW] = GetPlayerVirtualWorld(playerid);
    
    // Incrementar tiempo de juego
    PlayerData[playerid][pPlayTime] += 5;

    new query[2048];
    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET \
        `sex` = %d, \
        `cash` = %d, \
        `bank` = %d, \
        `health` = %f, \
        `armour` = %f, \
        `hunger` = %d, \
        `thirst` = %d, \
        `level` = %d, \
        `exp` = %d, \
        `faction` = %d, \
        `faction_rank` = %d, \
        `job` = %d, \
        `licenses` = %d, \
        `wanted` = %d, \
        `warns` = %d, \
        `jail_time` = %d, \
        `skin` = %d, \
        `x` = %f, \
        `y` = %f, \
        `z` = %f, \
        `angle` = %f, \
        `interior` = %d, \
        `vw` = %d, \
        `playtime` = %d, \
        `kills` = %d, \
        `deaths` = %d, \
        `phone` = %d, \
        `phone_credit` = %d, \
        `reputation` = %d, \
        `house_id` = %d, \
        `biz_id` = %d, \
        `clan_id` = %d, \
        `clan_rank` = %d, \
        `achievements` = %d, \
        `admin_level` = %d, \
        `mute_time` = %d \
        WHERE `id` = %d",
        PlayerData[playerid][pSex],
        PlayerData[playerid][pCash],
        PlayerData[playerid][pBank],
        PlayerData[playerid][pHealth],
        PlayerData[playerid][pArmour],
        PlayerData[playerid][pHunger],
        PlayerData[playerid][pThirst],
        PlayerData[playerid][pLevel],
        PlayerData[playerid][pExp],
        PlayerData[playerid][pFaction],
        PlayerData[playerid][pFactionRank],
        PlayerData[playerid][pJob],
        PlayerData[playerid][pLicenses],
        PlayerData[playerid][pWanted],
        PlayerData[playerid][pWarns],
        PlayerData[playerid][pJailTime],
        PlayerData[playerid][pSkin],
        PlayerData[playerid][pX],
        PlayerData[playerid][pY],
        PlayerData[playerid][pZ],
        PlayerData[playerid][pAngle],
        PlayerData[playerid][pInterior],
        PlayerData[playerid][pVW],
        PlayerData[playerid][pPlayTime],
        PlayerData[playerid][pKills],
        PlayerData[playerid][pDeaths],
        PlayerData[playerid][pPhoneNumber],
        PlayerData[playerid][pPhoneCredit],
        PlayerData[playerid][pReputation],
        PlayerData[playerid][pHouseID],
        PlayerData[playerid][pBizID],
        PlayerData[playerid][pClanID],
        PlayerData[playerid][pClanRank],
        PlayerData[playerid][pAchievements],
        PlayerData[playerid][pAdminLevel],
        PlayerData[playerid][pMuteTime],
        PlayerData[playerid][pID]);
    
    mysql_tquery(g_SQL, query, "", "");
    
    printf("[SAVE] Datos guardados para %s (ID: %d)", GetPlayerNameStr(playerid), playerid);
}

SaveAllData() {
    for(new i = 0; i < MAX_PLAYERS; i++) {
        if(IsPlayerConnected(i) && PlayerData[i][pLogged]) {
            SavePlayerData(i);
            SavePlayerInventory(i);
        }
    }
    
    // Guardar vehículos
    for(new i = 0; i < MAX_VEHICLES_RP; i++) {
        if(VehicleData[i][vID] > 0) {
            SaveVehicleTrunk(i);
        }
    }
    
    print("[SAVE] Todos los datos guardados.");
}

UpdateLastLogin(playerid) {
    new date[32], query[128];
    
    new year, month, day, hour, minute, second;
    getdate(year, month, day);
    gettime(hour, minute, second);
    format(date, sizeof(date), "%04d-%02d-%02d %02d:%02d:%02d", 
        year, month, day, hour, minute, second);

    mysql_format(g_SQL, query, sizeof(query),
        "UPDATE `players` SET `last_login` = '%s' WHERE `id` = %d",
        date, PlayerData[playerid][pID]);
    mysql_tquery(g_SQL, query, "", "");
}

// =============================================================================
//  SISTEMA DE HAMBRE Y SED
// =============================================================================
public HungerThirstUpdate() {
    for(new i = 0; i < MAX_PLAYERS; i++) {
        if(!IsPlayerConnected(i) || !PlayerData[i][pLogged]) continue;
        
        // Reducir hambre y sed
        PlayerData[i][pHunger] -= 2;
        PlayerData[i][pThirst] -= 3;
        
        if(PlayerData[i][pHunger] < 0) PlayerData[i][pHunger] = 0;
        if(PlayerData[i][pThirst] < 0) PlayerData[i][pThirst] = 0;
        
        // Efectos por hambre/sed
        if(PlayerData[i][pHunger] <= 20) {
            new Float:hp;
            GetPlayerHealth(i, hp);
            SetPlayerHealth(i, hp - 1.0);
            SendClientMessage(i, COLOR_RED, "[!] Tienes mucha hambre. Come algo pronto.");
        }
        
        if(PlayerData[i][pThirst] <= 20) {
            new Float:hp;
            GetPlayerHealth(i, hp);
            SetPlayerHealth(i, hp - 1.5);
            SendClientMessage(i, COLOR_BLUE, "[!] Tienes mucha sed. Bebe agua pronto.");
        }
        
        UpdatePlayerHUD(i);
    }
}

public AutoSave() {
    SaveAllData();
    print("[AUTOSAVE] Datos guardados automaticamente.");
}

// =============================================================================
//  SISTEMA DE EXPERIENCIA Y NIVELES
// =============================================================================
GivePlayerExp(playerid, amount) {
    PlayerData[playerid][pExp] += amount;
    new expNeeded = PlayerData[playerid][pLevel] * 1000;
    
    if(PlayerData[playerid][pExp] >= expNeeded) {
        PlayerData[playerid][pExp] -= expNeeded;
        PlayerData[playerid][pLevel]++;
        
        new msg[128];
        format(msg, sizeof(msg), "[Sistema] Has subido al nivel %d!", PlayerData[playerid][pLevel]);
        SendClientMessage(playerid, COLOR_GOLD, msg);
        
        GivePlayerMoney_RP(playerid, PlayerData[playerid][pLevel] * 1000);
    }
    
    UpdatePlayerHUD(playerid);
}

// =============================================================================
//  FUNCIONES DE UTILIDAD
// =============================================================================
ResetPlayerData(playerid) {
    PlayerData[playerid][pLogged]       = false;
    PlayerData[playerid][pRegistered]   = false;
    PlayerData[playerid][pID]           = 0;
    PlayerData[playerid][pSex]          = 0;
    PlayerData[playerid][pCash]         = 0;
    PlayerData[playerid][pBank]         = 0;
    PlayerData[playerid][pHunger]       = 100;
    PlayerData[playerid][pThirst]       = 100;
    PlayerData[playerid][pLevel]        = 1;
    PlayerData[playerid][pExp]          = 0;
    PlayerData[playerid][pFaction]      = 0;
    PlayerData[playerid][pJob]          = 0;
    PlayerData[playerid][pWanted]       = 0;
    PlayerData[playerid][pState]        = STATE_ALIVE;
    PlayerData[playerid][pHealth]       = 100.0;
    PlayerData[playerid][pArmour]       = 0.0;
    PlayerData[playerid][pX]            = 1958.3783;
    PlayerData[playerid][pY]            = 1343.1572;
    PlayerData[playerid][pZ]            = 15.3746;
    PlayerData[playerid][pAngle]        = 269.1425;
    PlayerData[playerid][pInterior]     = 0;
    PlayerData[playerid][pVW]           = 0;
    PlayerData[playerid][pKills]        = 0;
    PlayerData[playerid][pDeaths]       = 0;
    PlayerData[playerid][pAdminLevel]   = 0;
    PlayerData[playerid][pMuteTime]     = 0;
    PlayerData[playerid][pCuffed]       = false;
    PlayerData[playerid][pPhoneCredit]  = 100;
    PlayerData[playerid][pReputation]   = 0;
    PlayerData[playerid][pHouseID]      = -1;
    PlayerData[playerid][pBizID]        = -1;
    PlayerData[playerid][pClanID]       = -1;
    PlayerData[playerid][pSelectedItem] = -1;
    PlayerData[playerid][pCurrentVehicle] = 0;
    
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        PlayerInventory[playerid][s][0] = 0;
        PlayerInventory[playerid][s][1] = 0;
    }
}

GivePlayerMoney_RP(playerid, amount) {
    PlayerData[playerid][pCash] += amount;
    if(PlayerData[playerid][pCash] < 0) PlayerData[playerid][pCash] = 0;
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, PlayerData[playerid][pCash]);
    UpdatePlayerHUD(playerid);
}

GetVehicleModelName(model) {
    new name[32];
    switch(model) {
        case 400: name = "Landstalker";
        case 401: name = "Bravura";
        case 402: name = "Buffalo";
        case 403: name = "Linerunner";
        case 404: name = "Perennial";
        case 405: name = "Sentinel";
        case 406: name = "Dumper";
        case 407: name = "Firetruck";
        case 408: name = "Trashmaster";
        case 409: name = "Stretch";
        case 410: name = "Manana";
        case 411: name = "Infernus";
        case 412: name = "Voodoo";
        case 413: name = "Pony";
        case 414: name = "Mule";
        case 415: name = "Cheetah";
        case 416: name = "Ambulance";
        case 417: name = "Leviathan";
        case 418: name = "Moonbeam";
        case 419: name = "Esperanto";
        default: name = "Desconocido";
    }
    return name;
}

stock GetPlayerNameStr(playerid) {
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    return name;
}

RepairVehicle(vehicleid) {
    SetVehicleHealth(vehicleid, 1000.0);
    VehicleData[vehicleid][vHealth] = 1000.0;
}

// =============================================================================
//  COMANDOS CON ZCMD
// =============================================================================

CMD:ayuda(playerid, params[]) {
    #pragma unused params
    SendClientMessage(playerid, COLOR_GREEN, "Comandos disponibles: /stats, /guardar, /cambiarcontra, /inventario, /vmenu, /comprar");
    return 1;
}

CMD:stats(playerid, params[]) {
    #pragma unused params
    if(!PlayerData[playerid][pLogged]) return SendClientMessage(playerid, COLOR_RED, "[!] No estás logueado.");
    
    new str[512];
    format(str, sizeof(str),
        "=== ESTADISTICAS DE %s ===\n\n\
        Nivel: %d | EXP: %d\n\
        Efectivo: $%d | Banco: $%d\n\
        Hambre: %d%% | Sed: %d%%\n\
        Muertes: %d | Kills: %d\n\
        Tiempo jugado: %d minutos",
        GetPlayerNameStr(playerid),
        PlayerData[playerid][pLevel],
        PlayerData[playerid][pExp],
        PlayerData[playerid][pCash],
        PlayerData[playerid][pBank],
        PlayerData[playerid][pHunger],
        PlayerData[playerid][pThirst],
        PlayerData[playerid][pDeaths],
        PlayerData[playerid][pKills],
        PlayerData[playerid][pPlayTime] / 60
    );
    ShowPlayerDialog(playerid, DIALOG_STATS, DIALOG_STYLE_MSGBOX, "Estadisticas", str, "Cerrar", "");
    return 1;
}

CMD:guardar(playerid, params[]) {
    #pragma unused params
    if(!PlayerData[playerid][pLogged]) return SendClientMessage(playerid, COLOR_RED, "[!] No estás logueado.");
    SavePlayerData(playerid);
    SavePlayerInventory(playerid);
    SendClientMessage(playerid, COLOR_GREEN, "[Sistema] Datos guardados correctamente.");
    return 1;
}

CMD:cambiarcontra(playerid, params[]) {
    #pragma unused params
    if(!PlayerData[playerid][pLogged]) return SendClientMessage(playerid, COLOR_RED, "[!] No estás logueado.");
    ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_INPUT,
        "Cambiar Contrasena",
        "Ingresa tu nueva contrasena:",
        "Cambiar", "Cancelar");
    return 1;
}

CMD:inventario(playerid, params[]) {
    #pragma unused params
    if(!PlayerData[playerid][pLogged]) return SendClientMessage(playerid, COLOR_RED, "[!] No estás logueado.");
    ShowInventory(playerid);
    return 1;
}

CMD:vmenu(playerid, params[]) {
    #pragma unused params
    if(!PlayerData[playerid][pLogged]) return SendClientMessage(playerid, COLOR_RED, "[!] No estás logueado.");
    ShowVehicleMenu(playerid);
    return 1;
}

CMD:comprar(playerid, params[]) {
    #pragma unused params
    if(!PlayerData[playerid][pLogged]) return SendClientMessage(playerid, COLOR_RED, "[!] No estás logueado.");
    
    // Verificar si está en un concesionario
    for(new i = 0; i < g_TotalDealerships; i++) {
        if(IsPlayerInRangeOfPoint(playerid, 10.0, DealershipData[i][dsX], DealershipData[i][dsY], DealershipData[i][dsZ])) {
            ShowDealershipMenu(playerid, i);
            return 1;
        }
    }
    
    SendClientMessage(playerid, COLOR_RED, "[!] No estas cerca de un concesionario.");
    return 1;
}

CMD:reparar(playerid, params[]) {
    #pragma unused params
    if(!PlayerData[playerid][pLogged]) return SendClientMessage(playerid, COLOR_RED, "[!] No estás logueado.");
    
    new vehicleid = GetPlayerVehicleID(playerid);
    if(vehicleid == 0) {
        SendClientMessage(playerid, COLOR_RED, "[!] No estas en un vehiculo.");
        return 1;
    }
    
    // Verificar si tiene llave inglesa
    for(new s = 0; s < MAX_INV_SLOTS; s++) {
        if(PlayerInventory[playerid][s][0] == 4) { // Llave inglesa
            RepairVehicle(vehicleid);
            RemoveItemFromInventory(playerid, 4, 1);
            SendClientMessage(playerid, COLOR_GREEN, "[Vehiculo] Has reparado el vehiculo.");
            return 1;
        }
    }
    
    SendClientMessage(playerid, COLOR_RED, "[!] Necesitas una llave inglesa.");
    return 1;
}

// =============================================================================
//  COMANDOS DE ADMIN
// =============================================================================
CMD:avehiculo(playerid, params[]) {
    #pragma unused params
    if(PlayerData[playerid][pAdminLevel] < 1) return SendClientMessage(playerid, COLOR_RED, "[!] No eres admin.");
    
    new str[512];
    str[0] = '\0';
    
    new models[][] = {
        "Landstalker", "Bravura", "Buffalo", "Linerunner", "Perennial",
        "Sentinel", "Dumper", "Firetruck", "Trashmaster", "Stretch",
        "Manana", "Infernus", "Voodoo", "Pony", "Mule",
        "Cheetah", "Ambulance", "Leviathan", "Moonbeam", "Esperanto"
    };
    
    for(new i = 0; i < 20; i++) {
        format(str, sizeof(str), "%s%s\n", str, models[i]);
    }
    
    ShowPlayerDialog(playerid, DIALOG_ADMIN_VEHICLE, DIALOG_STYLE_LIST,
        "Crear Vehiculo", str, "Crear", "Cancelar");
    return 1;
}

CMD:agasolinera(playerid, params[]) {
    #pragma unused params
    if(PlayerData[playerid][pAdminLevel] < 2) return SendClientMessage(playerid, COLOR_RED, "[!] No eres admin.");
    
    CreateGasStation(playerid);
    return 1;
}

CMD:atuning(playerid, params[]) {
    #pragma unused params
    if(PlayerData[playerid][pAdminLevel] < 2) return SendClientMessage(playerid, COLOR_RED, "[!] No eres admin.");
    
    ShowTuningMenu(playerid);
    return 1;
}

// =============================================================================
//  MAIN
// =============================================================================
main() {
    print("==============================================");
    print("   DAIS RP - Servidor de Rol para SA-MP     ");
    print("   Version: 2.0                              ");
    print("==============================================");
}