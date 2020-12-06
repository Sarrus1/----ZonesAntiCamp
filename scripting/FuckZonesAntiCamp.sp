#include <sourcemod>
#include <fuckZones>
#include <sdktools>
#include <colorvariables>
#pragma newdecls required
#pragma semicolon 1

#define EFFECT_NAME "AntiCamp Zone"


//Timers Handle
Handle 
	g_AntiCampDisable = null,
	g_hClientTimers[MAXPLAYERS + 1] = {null, ...},
	g_hPunishTimers[MAXPLAYERS + 1] = {null, ...},
	g_hFreqTimers[MAXPLAYERS + 1] = {null, ...},
	g_hCooldownTimers[MAXPLAYERS + 1] = {null, ...};

bool g_anticampdisabled = false;

ConVar 
	g_szSoundFilePath = null,
	g_SlapDamage,
	g_PunishDelay,
	g_PunishFreq,
	g_CooldownDelay,
	g_disabletime,
	cvar_time;

int g_iCampCounters[MAXPLAYERS +1] = {0};

public Plugin myinfo =
{
	name = "FuckZonesAntiCamp",
	author = "Sarrus",
	description = "An anti-camp module for the fuckZones plugin by Bara.",
	version = "1.0",
	url = "https://github.com/Sarrus1/"
};

public void OnPluginStart() 
{
	LoadTranslations("FuckZonesAntiCamp.phrases");

	cvar_time = CreateConVar("sm_fuckzone_anticamp_time", "10", "Time in seconds before players must leave the zone or die");
	g_SlapDamage = CreateConVar("sm_fuckzone_anticamp_slapdamage", "20", "Damage to inflict to the player when slapping.", 0, true, 0.0, true, 100.0);
	g_PunishDelay = CreateConVar("sm_fuckzone_anticamp_punishdelay", "5", "How much time before slapping.", 0, true, 0.0);
	g_PunishFreq = CreateConVar("sm_fuckzone_anticamp_punishfreq", "2", "How much time between slaps.", 0, true, 0.0);
	g_CooldownDelay = CreateConVar("sm_fuckzone_anticamp_cooldown_delay", "5.0", "How much time a client has to be out of a camping zone before he is no longer instantly slapped when entering one.", 0, true, 0.0);
	g_disabletime = CreateConVar("sm_fuckzone_anticamp_disabletime", "40", "How much time after the round start until the timer automatically disables. Set to 0 to disable.", 0, true, 0.0);
	g_szSoundFilePath = CreateConVar("sm_fuckzone_anticamp_sound_path", "misc/anticamp/camper.mp3", "The file path of the camping sound. Leave blank to disable.");


	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("player_death", OnClientDied, EventHookMode_Post);
	HookEvent("player_team", OnClientChangeTeam, EventHookMode_Pre);


	AutoExecConfig(true,"FuckZonesAntiCamp");

}

public Action Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarFloat(g_disabletime) != 0)
	{
		if (IsFreezeTime())
		{
			delete(g_AntiCampDisable);
			g_AntiCampDisable = CreateTimer(GetConVarFloat(g_disabletime) + GetConVarFloat(FindConVar("mp_freezetime")), AntiCamp_Disable);
		}
		else
		{
			delete(g_AntiCampDisable);
			g_AntiCampDisable = CreateTimer(GetConVarFloat(g_disabletime), AntiCamp_Disable);
		}
		g_anticampdisabled = false;
	}
}


public void OnMapStart()
{
	char szSoundFilePath[256];
	char szSoundFullPath[256];
	GetConVarString(g_szSoundFilePath, szSoundFilePath, 256);
	szSoundFullPath = "sound/";
	StrCat(szSoundFullPath, sizeof(szSoundFullPath), szSoundFilePath);
	AddFileToDownloadsTable(szSoundFullPath);
	PrecacheSound(szSoundFilePath);
	delete(g_AntiCampDisable);
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
			g_iCampCounters[iClient] = 0;
			if(IsClientInGame(iClient))
			{
				ResetTimer(iClient);
			}
    }
}

public void OnMapEnd() 
{
	delete(g_AntiCampDisable);
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
      if(IsClientInGame(iClient))
      {
				RequestFrame(ResetTimer, iClient);
      }
    }
}


//Create a reset timer function
public void ResetTimer(int client)
{
	delete(g_hClientTimers[client]);
	delete(g_hPunishTimers[client]);
	delete(g_hCooldownTimers[client]);
	delete(g_hFreqTimers[client]);
}

//Reset timer when client arrives
public void OnClientPutInServer(int client)
{
	g_iCampCounters[client] = 0;
	ResetTimer(client);
}

//Reset timer when client disconnects
public void OnClientDisconnect(int client)
{
	g_iCampCounters[client] = 0;
	ResetTimer(client);
}

//Reset timer when client changes team
public Action OnClientChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	RequestFrame(ResetTimer, client);
}

//Reset timer when client dies
public Action OnClientDied(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	RequestFrame(ResetTimer, client);
}

//Reset timer when the round ends
public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete(g_AntiCampDisable);
	for(int iClient = 1; iClient <= MaxClients; iClient++)
  {
		RequestFrame(ResetTimer, iClient);
  }
}


//Start timer when client enters a zone
public void fuckZones_OnStartTouchZone_Post(int client, int entity, const char[] zone_name, int type)
{
	if(!IsValidClient(client) || IsWarmup() || g_anticampdisabled)
		return;

	if((StrContains(zone_name, "AntiCampCT", false) == 0 && GetClientTeam(client) == 3) || (StrContains(zone_name, "AntiCampT", false) == 0 && GetClientTeam(client) == 2) || (StrContains(zone_name, "AntiCampBoth", false) == 0))
	{
		if (g_hCooldownTimers[client] == null)
		{
			delete(g_hClientTimers[client]);
			if (IsFreezeTime())
			{
				g_hClientTimers[client] = CreateTimer(GetConVarFloat(cvar_time) + GetConVarFloat(FindConVar("mp_freezetime")), Timer_End, GetClientUserId(client));
			}
			else
			{
				g_hClientTimers[client] = CreateTimer(GetConVarFloat(cvar_time), Timer_End, GetClientUserId(client));
			}
		}
		else
		{
			ResetTimer(client);
			CPrintToChat(client, "%t", "Cooldown_Not_Expired");
			char szSoundFilePath[256];
			GetConVarString(g_szSoundFilePath, szSoundFilePath, 256);
			if (!StrEqual(szSoundFilePath, ""))
			{
				EmitSoundToClient(client, szSoundFilePath);
			}
			SlapPlayer(client, GetConVarInt(g_SlapDamage), true);
			g_hFreqTimers[client] = CreateTimer(GetConVarFloat(g_PunishFreq), Repeat_Timer, GetClientUserId(client), TIMER_REPEAT);
		}
	}
}


//Stop timer when client leaves a zone
public void fuckZones_OnEndTouchZone_Post(int client, int entity, const char[] zone_name, int type)
{
	if(!IsValidClient(client) || IsWarmup() || g_anticampdisabled)
		return;

	if((StrContains(zone_name, "AntiCampCT", false) == 0 && GetClientTeam(client) == 3) || (StrContains(zone_name, "AntiCampT", false) == 0 && GetClientTeam(client) == 2) || (StrContains(zone_name, "AntiCampBoth", false) == 0))
	{
		ResetTimer(client);
		if ((GetConVarInt(g_CooldownDelay) != 0) && ((g_hPunishTimers[client] != null) || (g_hFreqTimers[client] != null)))
		{
			g_hCooldownTimers[client] = CreateTimer(GetConVarFloat(g_CooldownDelay), Cooldown_End, GetClientUserId(client));
		}
	}
}


//What to do when the cooldown ends
public Action Cooldown_End(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if(!client)
	{
		return;
	}
	CPrintToChat(client, "%t", "Cooldown_Expired");
	g_hCooldownTimers[client] = null;
}

//What do to when the main timer ends
public Action Timer_End(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if(!client)
	{
		return;
	}
	g_hClientTimers[client] = null;
	if ( client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		delete(g_hPunishTimers[client]);
		g_hPunishTimers[client] = CreateTimer(GetConVarFloat(g_PunishDelay), Punish_Timer, GetClientUserId(client));
		PrintCenterText(client, "%t", "Camp_Message_Warning", GetConVarInt(g_PunishDelay) );
	}
}

//What to do when the punish timer ends
public Action Punish_Timer(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if(!client)
	{
		return;
	}
	g_hPunishTimers[client] = null;
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		g_iCampCounters[client]++;
		CPrintToChatAll("%t", "Camp_Message_All", client, g_iCampCounters[client]);
		char szSoundFilePath[256];
		GetConVarString(g_szSoundFilePath, szSoundFilePath, 256);
		if (!StrEqual(szSoundFilePath, ""))
		{
			EmitSoundToClient(client, szSoundFilePath);
		}
		SlapPlayer(client, GetConVarInt(g_SlapDamage), true);
		delete(g_hFreqTimers[client]);
		g_hFreqTimers[client] = CreateTimer(GetConVarFloat(g_PunishFreq), Repeat_Timer, GetClientUserId(client), TIMER_REPEAT);
	}
}

public Action Repeat_Timer(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if (!client)
	{
    return Plugin_Stop; // Stop early, invalid client index.
  }
	if (!IsPlayerAlive(client))
	{
		g_hFreqTimers[client] = null;
		return Plugin_Stop;
  }
	CPrintToChat(client, "%t", "Camp_Message_Self");
	SlapPlayer(client, GetConVarInt(g_SlapDamage), true);
	return Plugin_Continue;
}

public Action AntiCamp_Disable(Handle timer)
{
	g_anticampdisabled = true;
	CPrintToChatAll("%t", "AntiCamp_Disabled");
	for(int iClient = 1; iClient <= MaxClients; iClient++)
  {
		ResetTimer(iClient);
  }
	g_AntiCampDisable = null;
}

bool IsWarmup()
{
	return (GameRules_GetProp("m_bWarmupPeriod") == 1);
}

bool IsFreezeTime()
{
	return(GameRules_GetProp("m_bFreezePeriod") == 1);
}


public bool IsValidClient(int client)
{
	return (client >= 0 && client <= MaxClients && IsClientConnected(client) && IsClientAuthorized(client) && IsClientInGame(client) && !IsFakeClient(client));
}

/*
bool IsCTZone(StringMap values)
{
	char sValue[MAX_KEY_VALUE_LENGTH];
	if (GetZoneValue(values, "AntiCamp Team", sValue, sizeof(sValue)))
	{
		return (strcmp(sValue, "CT", false) == 0);
	}
	return false;
}

bool IsTZone(StringMap values)
{
	char sValue[MAX_KEY_VALUE_LENGTH];
	if (GetZoneValue(values, "AntiCamp Team", sValue, sizeof(sValue)))
	{
		return (strcmp(sValue, "T", false) == 0);
	}
	return false;
}

bool IsBothZone(StringMap values)
{
	char sValue[MAX_KEY_VALUE_LENGTH];
	PrintToChatAll("Both test");
	if (GetZoneValue(values, "AntiCamp Team", sValue, sizeof(sValue)))
	{
		return (strcmp(sValue, "Both", false) == 0);
	}
	return false;
}

bool GetZoneValue(StringMap values, const char[] key, char[] value, int length)
{
	char sKey[MAX_KEY_NAME_LENGTH];
	StringMapSnapshot keys = values.Snapshot();

	for (int x = 0; x < keys.Length; x++)
	{
		keys.GetKey(x, sKey, sizeof(sKey));

		if (strcmp(sKey, key, false) == 0)
		{
			values.GetString(sKey, value, length);

			delete keys;
			return true;
		}
	}

	delete keys;
	return false;
}
*/