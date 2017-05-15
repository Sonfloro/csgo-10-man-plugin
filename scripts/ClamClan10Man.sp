#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Sonfloro"
#define PLUGIN_VERSION "0.05"

#include <sourcemod>
#include <cstrike>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "ClamClan10Man",
	author = PLUGIN_AUTHOR,
	description = "Plugin for creating 10 Mans",
	version = PLUGIN_VERSION,
	url = "www.clamclan.org"
};
// Csgo team numbers : 1: Spectator, 2: Terrorist, 3: Counter-Terrorist


// TODO:
/*
Make messages in chat look better and attempt to remove all echoing from the changing of server commands: DONE

Remove redundent For loops and use more global variables for common things (ie. captain clientIDs): DONE

Setup autoexec for configs (knife round, warmup, live game): DONE

Program a ready-up system for warmup and before match starts

Setup !pause command: DONE

Disable commands during the 10 man: DONE

Add random captains function

Add captian selection menu: DONE

Add "End Game" function that either restarts the server or the map and sets the game back to warmup.

*/
char ownerID[17] = "76561198178274343";
char g_sCaptain1[MAX_NAME_LENGTH];
char g_sCaptain2[MAX_NAME_LENGTH];
char knifeRoundWinner;
bool b_isCapt1Picking = true;
bool b_enableTimers = true;
bool b_warmup = true;
bool b_knifeRound = false;
bool b_gameStarted = false;
bool b_matchIsPaused = false;
bool b_team2Unpause = false;
bool b_team3Unpause = false;
bool b_CaptainsSet = false;
bool b_TeamChange = false;
bool b_firstCaptChosen = false;
int g_captain1CID;
int g_captain2CID;
Handle g_hLocked = INVALID_HANDLE;



public void OnPluginStart()
{
	
	RegAdminCmd("sm_startGame", cmd_startGame, ADMFLAG_CHEATS);
	//RegAdminCmd("sm_rejoin", cmd_rejoin, ADMFLAG_GENERIC);
	RegAdminCmd("sm_setCaptain", cmd_setCaptain, ADMFLAG_CHEATS);
	RegAdminCmd("sm_clearCaptains", cmd_clearCaptains, ADMFLAG_CHEATS);
	RegAdminCmd("sm_setServer", cmd_setServer, ADMFLAG_CHEATS);
	RegAdminCmd("sm_setKnifeRound", cmd_setKnifeRound, ADMFLAG_CHEATS);
	//RegAdminCmd("sm_respawn", cmd_respawn, ADMFLAG_GENERIC);
	RegAdminCmd("sm_forceUnpause", cmd_forceUnpauseMatch, ADMFLAG_CHEATS);
	RegAdminCmd("sm_randomCaptains", cmd_randomCaptains, ADMFLAG_CHEATS);
	RegConsoleCmd("sm_pause", cmd_pauseMatch);
	RegConsoleCmd("sm_unpause", cmd_unpauseMatch);
	RegConsoleCmd("sm_captains", cmd_captains);
	
	HookEvent("server_cvar", Event_serverCvar, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamchange_pending", Event_TeamChangePending);
	HookEvent("bomb_exploded", Event_BombExploded, EventHookMode_Post);
	AddCommandListener(Command_JoinTeam, "jointeam");
	g_hLocked = CreateConVar("sm_lock_teams", "1", "Enable or disable locking teams during match");
}


public void OnMapStart()
{
	ServerCommand("exec 10ManWarmup.cfg");
	SetConVarBool(g_hLocked, false);
}

public void OnClientPutInServer(int client)
{
	if (b_enableTimers)
	{
		CreateTimer(7.0, respawnTimer, client);
	}
}



public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{

	char displayCaptains[] = ".captains";

	if (strcmp(sArgs[0], displayCaptains, false) == 0)
	{
		if (b_CaptainsSet)
		{
			PrintToChat(client, "\x01[\x07ClamClan\x01]  %s and %s are the captains. ", g_sCaptain1, g_sCaptain2);
			return Plugin_Handled;
		}
		else
		{
			PrintToChat(client, "\x01[\x07ClamClan\x01]  The captains have not been set.");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (b_warmup)
	{
		if (!b_TeamChange)
		{
			int userId = event.GetInt("userid");
			int user = GetClientOfUserId(userId);
	
			if (b_enableTimers)
			{
				CreateTimer(2.0, respawnTimer, user);
			}
		}
		else
		{
			b_TeamChange = false;
		}
	}
}

public Action Event_serverCvar(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}



public int Menu_ChooseTeammate(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[MAX_NAME_LENGTH];
		
		menu.GetItem(param2, info, sizeof(info));
		
	}
}

public void Event_TeamChangePending(Event event, const char[] name, bool dontBroadcast)
{
	if (b_warmup)
	{
		b_TeamChange = true;
		int userId = event.GetInt("userid");
		int user = GetClientOfUserId(userId);
		int team = event.GetInt("toteam");
		ChangeClientTeam(user, team);
	
		if (b_enableTimers)
		{
			CreateTimer(2.0, teamChangeRespawnTimer, user);
		}
		b_TeamChange = false;
	}
}

public Action Event_BombExploded(Event event, const char[] name, bool dontBroadcast)
{
	if (b_warmup)
	{
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientConnected(i) && GetClientHealth(i) == 0)
			{
				CS_RespawnPlayer(i);
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (b_knifeRound)
	{
		int totalCThp = 0;
		int totalTEhp = 0;
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				if (GetClientTeam(i) == 2)
				{
					totalTEhp += GetClientHealth(i);
				}
				else if (GetClientTeam(i) == 3)
				{
					totalCThp += GetClientHealth(i);
				}
			}
		}	
		if (totalCThp > totalTEhp)
		{
			knifeRoundWinner = 'C';
			PrintToChatAll("\x01[\x07ClamClan\x01]  The Counter-Terrorist side win.");
		}
		else if (totalTEhp > totalCThp)
		{
			knifeRoundWinner = 'T';
			PrintToChatAll("\x01[\x07ClamClan\x01]  The Terrorist side win.");
		}
		b_knifeRound = false;
		createKnifeMenu();
	}
}

public void createKnifeMenu()
{
	Menu knifeMenu = new Menu(KnifeMenuHandler);
	knifeMenu.AddItem("Counter-Terrorist", "Counter-Terrorist");
	knifeMenu.AddItem("Terrorist", "Terrorist");
	knifeMenu.ExitButton = false;
	knifeMenu.SetTitle("Choose what side you want to start on.");
	
	if (knifeRoundWinner == 'T')
	{
		if (GetClientTeam(g_captain1CID) == 2)
		{
			knifeMenu.Display(g_captain1CID, MENU_TIME_FOREVER);
		}
		else
		{
			knifeMenu.Display(g_captain2CID, MENU_TIME_FOREVER);
		}
	}
	if (knifeRoundWinner == 'C')
	{
		if (GetClientTeam(g_captain1CID) == 3)
		{
			knifeMenu.Display(g_captain1CID, MENU_TIME_FOREVER);
		}
		else
		{
			knifeMenu.Display(g_captain2CID, MENU_TIME_FOREVER);
		}
	}
	
}

public int KnifeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[MAX_NAME_LENGTH];
		bool found = menu.GetItem(param2, info, sizeof(info));
		if (found)
		{
			int TteamIndex[5];
			int CTteamIndex[5];
			int tLoop = 0;
			int ctLoop = 0;
			for (int i = 1; i < MaxClients; i++)
			{
				if (IsClientConnected(i))
				{
					if (GetClientTeam(i) == 2)
					{
						TteamIndex[tLoop] = i;
						tLoop++;
					}
					if (GetClientTeam(i) == 3)
					{
						CTteamIndex[ctLoop] = i;
						ctLoop++;
					}
				}
			}
			if (strcmp(info, "Counter-Terrorist", false) == 0)
			{
				if (knifeRoundWinner == 'T')
				{
					for (int i = 0; i < 5; i++)
					{
						ChangeClientTeam(TteamIndex[i], 3);
						ChangeClientTeam(CTteamIndex[i], 2);
					}
					delete menu;
					ServerCommand("sm_setServer");
				}
				else
				{
					delete menu;
					ServerCommand("sm_setServer");
				}
			}
			if (strcmp(info, "Terrorist", false) == 0)
			{
				if (knifeRoundWinner == 'C')
				{
					for (int i = 0; i < 5; i++)
					{
						ChangeClientTeam(TteamIndex[i], 3);
						ChangeClientTeam(CTteamIndex[i], 2);
					}
					delete menu;
					ServerCommand("sm_setServer");
				}
				else
				{
					delete menu;
					ServerCommand("sm_setServer");
				}
			}
		}
	}
}
public Action respawnTimer(Handle timer, any user)
{
	if (b_warmup)
	{
		CS_RespawnPlayer(user);
		if (GetClientTeam(user) > 1)
		{
			SetEntProp(user, Prop_Send, "m_iAccount", 16000);
		}
	}
}

public Action teamChangeRespawnTimer(Handle timer, int user)
{
	if (b_warmup)
	{
		CS_RespawnPlayer(user);
	}
}

public Action Command_JoinTeam(int client, const char[] command, int args)
{    
    if (client != 0)
    {
        if(IsClientInGame(client) && !IsFakeClient(client))
        {
            if (GetClientTeam(client) > 0 && GetConVarBool(g_hLocked))
            {
                PrintToChat(client, "\x01[\x07ClamClan\x01] \x01 \x07You cannot change your team during a match!");
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}  

/*
public Action cmd_respawn(int client, int args)
{
	if (b_warmup)
	{
		CS_RespawnPlayer(client);
		if (GetClientTeam(client) > 1)
		{
			SetEntProp(client, Prop_Send, "m_iAccount", 16000);
		}
	}
	return Plugin_Handled;
}
*/

void create_CaptainMenu(int callerClient)
{
	Menu menu = new Menu(CaptainMenuHandler);
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			char temp[MAX_NAME_LENGTH];
			GetClientName(i, temp, sizeof(temp));
			if (strcmp(g_sCaptain1, temp, false) != 0)
			{
				if (b_firstCaptChosen)
				{
					char Client_name[MAX_NAME_LENGTH];
					GetClientName(i, Client_name, sizeof(Client_name));
					if (GetClientTeam(i) != GetClientTeam(g_captain1CID))
					{
						menu.AddItem(Client_name, Client_name);
					}
				}
				else
				{
					char Client_name[MAX_NAME_LENGTH];
					GetClientName(i, Client_name, sizeof(Client_name));
					menu.AddItem(Client_name, Client_name);
				}
			}
		}
	}
	menu.SetTitle("Choose a Captain: ");
	menu.ExitButton = true;
	menu.Display(callerClient, MENU_TIME_FOREVER);
}



public int CaptainMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[MAX_NAME_LENGTH];
		bool found = menu.GetItem(param2, info, sizeof(info));
		if (found)
		{
			if (strlen(g_sCaptain1) == 0)
			{
				g_sCaptain1 = info;
				PrintToChatAll("\x01[\x07ClamClan\x01]  Added %s as first captain.", g_sCaptain1);
				b_firstCaptChosen = true;
				for (int i = 1; i < MaxClients; i++)
				{
					if (IsClientConnected(i))
					{
						char temp[MAX_NAME_LENGTH];
						GetClientName(i, temp, sizeof(temp));
						if (strncmp(g_sCaptain1, temp, false) == 0)
						{
							g_captain1CID = i;
						}
					}
				}
				delete menu;
			}
			else if (strlen(g_sCaptain2) == 0)
			{
				g_sCaptain2 = info;
				PrintToChatAll("\x01[\x07ClamClan\x01]  Added %s as second captain.", g_sCaptain2);
				b_CaptainsSet = true;
				delete menu;
			}
		}
	}
}

void create_teamMenu()
{
	bool menuIsPopulated = false;
	Menu menu = new Menu(TeamMenuHandler);
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (GetClientTeam(i) == 1)
			{
				char client_name[MAX_NAME_LENGTH];
				GetClientName(i, client_name, sizeof(client_name));
				menu.AddItem(client_name, client_name);
				menuIsPopulated = true;
			}
		}
	}
	if (!menuIsPopulated)
	{
		delete menu;
		ServerCommand("sm_setKnifeRound");
	}
	else
	{
		menu.SetTitle("Choose a teammate:");
		menu.ExitButton = false;
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				char temp[MAX_NAME_LENGTH];
				GetClientName(i, temp, sizeof(temp));
				if (strcmp(temp, g_sCaptain1, false) == 0 && b_isCapt1Picking)
				{
					menu.Display(i, MENU_TIME_FOREVER);
				}
				else if (strcmp(temp, g_sCaptain2, false) == 0 && !b_isCapt1Picking)
				{
					menu.Display(i, MENU_TIME_FOREVER);
				}
			}
		}
	}
}

public int TeamMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[MAX_NAME_LENGTH];
		bool found = menu.GetItem(param2, info, sizeof(info));
		if (found)
		{
			setPickTeam(info);
			delete menu;
			if (b_isCapt1Picking)
			{
				b_isCapt1Picking = false;
				create_teamMenu();
			}
			else
			{
				b_isCapt1Picking = true;
				create_teamMenu();
			}
		}
	}
}

void setPickTeam(char[] name)
{
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			char temp[MAX_NAME_LENGTH];
			GetClientName(i, temp, sizeof(temp));
			if (strcmp(temp, name, false) == 0 && b_isCapt1Picking)
			{
				ChangeClientTeam(i, 2);
			}
			else if (strcmp(temp, name, false) == 0 && !b_isCapt1Picking)
			{
				ChangeClientTeam(i, 3);
			}
		}
	}
}

/*
public Action cmd_rejoin(int client, int args)
{
	if (b_warmup)
	{
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				ChangeClientTeam(i, 3);
			}
		}
	}
	return Plugin_Handled;	
}
*/

public Action cmd_startGame(int client, int args)
{
	char capCheck[MAX_NAME_LENGTH];
	if (b_CaptainsSet)
	{
		b_enableTimers = false;
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				ForcePlayerSuicide(i);
				GetClientName(i, capCheck, sizeof(capCheck));
				if (strcmp(capCheck, g_sCaptain1, false) == 0)
				{
					g_captain1CID = i;
					ChangeClientTeam(i, 2);
				}
				else if (strcmp(capCheck, g_sCaptain2, false) == 0)
				{
					g_captain2CID = i;
					ChangeClientTeam(i, 3);
				}
				else
				{
					ChangeClientTeam(i, 1);
				}
			}
		}
		SetConVarBool(g_hLocked, true);
		ServerCommand("sv_cheats 1");
		ServerCommand("mp_buytime 1");
		ServerCommand("mp_freezetime 20");
		ServerCommand("sv_infinite_ammo 0");
		ServerCommand("mp_warmup_end");
		ServerCommand("mp_restartgame 1");
		ServerCommand("sv_alltalk 1");
		ServerCommand("sv_pausable 1");
		ServerCommand("mp_pause_match");
		ServerCommand("sv_cheats 0"); 
		create_teamMenu(); 
	}
	else
	{
		PrintToChatAll("\x01[\x07ClamClan\x01]  Error, captains have not been set!");
	}
	
	return Plugin_Handled;
}



// Deprecating for CaptainMenu
/*
public Action cmd_setCaptain(int client, int args)
{
	if (!b_gameStarted)
	{
		if (strlen(g_sCaptain1) == 0)
		{
			GetCmdArg(1, g_sCaptain1, sizeof(g_sCaptain1));
			PrintToChatAll("\x01[\x07ClamClan\x01]  Added %s as first captain.", g_sCaptain1);
		}
		else if (strlen(g_sCaptain2) == 0)
		{
			GetCmdArg(1, g_sCaptain2, sizeof(g_sCaptain2));
			PrintToChatAll("\x01[\x07ClamClan\x01]  Added %s as second captain.", g_sCaptain2);
			b_CaptainsSet = true;
		}
		else
		{
			PrintToChatAll("\x01[\x07ClamClan\x01]  Both Captains are already selected, use !clearCaptains to reset captains");
		}
	}
	return Plugin_Handled;
}
*/

public Action cmd_clearCaptains(int client, int args)
{
	if (!b_gameStarted)
	{
		g_sCaptain1 = "";
		g_sCaptain2 = "";
		b_CaptainsSet = false;
		PrintToChatAll("\x01[\x07ClamClan\x01]  Captains have been cleared! You may now set new captains.");
	}
	return Plugin_Handled;
}

public Action cmd_setServer(int client, int args)
{
	b_warmup = false;
	b_knifeRound = false;
	b_gameStarted = true;
	SetConVarBool(g_hLocked, true);
	ServerCommand("sv_cheats 1");
	ServerCommand("exec setup10Man.cfg");
	PrintToChatAll("\x01[\x07ClamClan\x01]  ClamClan official CS:GO 10 Man Server Config executed (version 0.05)");
	
	
	return Plugin_Handled;
}


public Action cmd_setKnifeRound(int client, int args)
{
	ServerCommand("exec setKnifeRound.cfg");
	
	for (int i = 0; i < 9; i++)
	{
		PrintToChatAll("\x01[\x07ClamClan\x01] -");
	}
	
	PrintToChatAll("\x01[\x07ClamClan\x01]  Starting Knife round!");
	PrintToChatAll("\x01[\x07ClamClan\x01]  Team with the most hp at the end wins!");
	
	b_knifeRound = true;
	
	return Plugin_Handled;
	
}

public Action cmd_pauseMatch(int client, int args)
{
	if (b_gameStarted)
	{
		char invokerClient[MAX_NAME_LENGTH];
		GetClientName(client, invokerClient, MAX_NAME_LENGTH);
		if (!b_matchIsPaused)
		{
			PrintToChatAll("\x01[\x07ClamClan\x01]  %s has invoked a pause.", invokerClient);
			PrintToChatAll("\x01[\x07ClamClan\x01]  Use !unpause to requst an unpause.");
			ServerCommand("mp_pause_match");
			b_matchIsPaused = true;
		}
	}
	return Plugin_Handled;
}

public Action cmd_unpauseMatch(int client, int args)
{
	if (b_gameStarted)
	{
		char invokerClient[MAX_NAME_LENGTH];
		GetClientName(client, invokerClient, MAX_NAME_LENGTH);
		if (b_matchIsPaused)
		{
			if (GetClientTeam(client) == 2)
			{
				b_team2Unpause = true;
			}
			if (GetClientTeam(client) == 3)
			{
				b_team3Unpause = true;
			}
			if (b_team2Unpause && b_team3Unpause)
			{
				PrintToChatAll("\x01[\x07ClamClan\x01]  Match has been unpaused.");
				ServerCommand("mp_unpause_match");
				b_matchIsPaused = false;
				return Plugin_Handled;
			}
			PrintToChatAll("\x01[\x07ClamClan\x01]  %s has requested for an unpause.", invokerClient);
			PrintToChatAll("\x01[\x07ClamClan\x01]  Match will unpause once the other team has requested for an unpause.");
		}
	}
	return Plugin_Handled;
}

public Action cmd_forceUnpauseMatch(int client, int args)
{
	if (b_gameStarted)
	{
		char invokerClient[MAX_NAME_LENGTH];
		char invokerID[100];
		GetClientAuthId(client, AuthId_SteamID64, invokerID, 100, true);
		GetClientName(client, invokerClient, MAX_NAME_LENGTH);
		if (strncmp(ownerID, invokerID, false) == 0)
		{
			PrintToChatAll("\x01[\x07ClamClan\x01]  %s has forced an unpause.", invokerClient);
			ServerCommand("mp_unpause_match");
			b_matchIsPaused = false;
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

public Action cmd_setCaptain(int client, int args)
{
	if (!b_CaptainsSet)
	{
		create_CaptainMenu(client);
	}
	else
	{
		PrintToChatAll("\x01[\x07ClamClan\x01]  Captains have already been set.");
	}
	return Plugin_Handled;
}

public Action cmd_randomCaptains(int client, int args)
{
	
}



public Action cmd_captains(int client, int args)
{
	if (b_CaptainsSet)
	{
		PrintToChat(client, "\x01[\x07ClamClan\x01]  %s and %s are the captains. ", g_sCaptain1, g_sCaptain2);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "\x01[\x07ClamClan\x01]  The captains have not been set.");
		return Plugin_Handled;
	}
}


