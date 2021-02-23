#include <sourcemod>
#include <fuckZones>
#include <sdktools>
#include <sdkhooks>
#include <colorvariables>
#include <abnersound>

#undef REQUIRE_PLUGIN
#include <smwarn>

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
	g_cSoundPath = null,
	g_cPlayType,
	g_SlapDamage,
	g_PunishDelay,
	g_PunishFreq,
	g_CooldownDelay,
	g_disabletime,
	g_bEnableWarn,
	g_iWarnValue,
	g_szWarnReason,
	g_cSlapOrDamage,
	cvar_time,
	g_cRampupDamage,
	g_cBlindPlayer,
	g_cStopSoundOnZoneLeave;

int g_iCampCounters[MAXPLAYERS +1] = {0, ...},
	g_iSoundBeingPlayed[MAXPLAYERS + 1] = {-1, ...};

UserMsg g_FadeUserMsgId;

ArrayList sounds;


public Plugin myinfo =
{
	name = "FuckZonesAntiCamp",
	author = "Sarrus",
	description = "An anti-camp module for the fuckZones plugin by Bara.",
	version = "1.2",
	url = "https://github.com/Sarrus1/"
};


public void OnPluginStart() 
{
	LoadTranslations("FuckZonesAntiCamp.phrases");

	cvar_time = CreateConVar("sm_fuckzone_anticamp_time", "10", "Time in seconds before players must leave the zone or die");
	g_SlapDamage = CreateConVar("sm_fuckzone_anticamp_damage", "20", "Damage to inflict to the player when punishing them.", 0, true, 0.0, true, 100.0);
	g_PunishDelay = CreateConVar("sm_fuckzone_anticamp_punishdelay", "5", "How much time before slapping.", 0, true, 0.0);
	g_PunishFreq = CreateConVar("sm_fuckzone_anticamp_punishfreq", "2", "How much time between slaps.", 0, true, 0.0);
	g_CooldownDelay = CreateConVar("sm_fuckzone_anticamp_cooldown_delay", "5.0", "How much time a client has to be out of a camping zone before he is no longer instantly slapped when entering one.", 0, true, 0.0);
	g_disabletime = CreateConVar("sm_fuckzone_anticamp_disabletime", "40", "How much time after the round start until the timer automatically disables. Set to 0 to disable.", 0, true, 0.0);
	g_cSoundPath = CreateConVar("sm_fuckzone_anticamp_sound_path", "misc/anticamp", "The folder path of the camping sounds. Leave blank to disable.");
	g_cPlayType = CreateConVar("sm_fuckzone_anticamp_sound_play_type", "1", "1 - Random, 2- Play in queue");
	g_bEnableWarn = CreateConVar("sm_fuckzone_anticamp_enable_warn", "0", "Enable the warning system. 0 to disable, 1 to enable. ***REQUIRES the SM warn plugin!***", 0, true, 0.0, true, 1.0);
	g_iWarnValue = CreateConVar("sm_fuckzone_anticamp_warn_value", "3", "After how many times a player caught camping should be warned.", 0, true, 0.0);
	g_szWarnReason = CreateConVar("sm_fuckzone_anticamp_warn_reason", "Stop camping.", "The warn reason.");
	g_cSlapOrDamage = CreateConVar("sm_fuckzone_anticamp_slapordamage", "0", "0 to slap a player, 1 to only damage them.", 0, true, 0.0, true, 1.0);
	g_cRampupDamage = CreateConVar("sm_fuckzone_anticamp_rampup_dmg", "0", "Ramp up the damages proportionnaly to amount of time players have been caught camping when slaping players.", _, true, 0.0, true, 1.0);	
	g_cBlindPlayer = CreateConVar("sm_fuckzone_anticamp_blind_player", "1", "Wether or not to blind a player when they get slapped. 0 to disable, 1 to enable.", _, true, 0.0, true, 1.0);	
	g_cStopSoundOnZoneLeave = CreateConVar("sm_fuckzone_anticamp_stop_sound", "1", "Wether or not to stop the camping sound when the player leaves the zone. 0 to disable, 1 to enable.", _, true, 0.0, true, 1.0);	

	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
	HookEvent("teamplay_round_start", Event_OnRoundStart);
	HookEvent("player_death", OnClientDied, EventHookMode_Post);
	HookEvent("player_team", OnClientChangeTeam, EventHookMode_Pre);

	RegAdminCmd("sm_sound_refresh", CommandReload, ADMFLAG_ROOT);

	g_FadeUserMsgId = GetUserMessageId("Fade");

	sounds = new ArrayList(512);

	AutoExecConfig(true,"FuckZonesAntiCamp");
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("smwarn_warn");
	return APLRes_Success;
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
	RefreshSounds(0);

	delete(g_AntiCampDisable);
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
			g_iCampCounters[iClient] = 0;
			if(IsClientInGame(iClient))
				ResetTimer(iClient);
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
	char szSound[128];
	int success = GetSound(sounds, g_cSoundPath, false, szSound, sizeof szSound, g_iSoundBeingPlayed[client]);

	delete(g_hClientTimers[client]);
	delete(g_hPunishTimers[client]);
	delete(g_hCooldownTimers[client]);
	delete(g_hFreqTimers[client]);

	if(success != -1 && g_cStopSoundOnZoneLeave.BoolValue)
	{
		StopSound(client, SNDCHAN_AUTO, szSound);
		g_iSoundBeingPlayed[client] = -1;
	}

	
	if(GetConVarBool(g_cBlindPlayer))
		PerformBlind(0, client, 0);
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
				g_hClientTimers[client] = CreateTimer(GetConVarFloat(cvar_time) + GetConVarFloat(FindConVar("mp_freezetime")), Timer_End, GetClientUserId(client));
			else
				g_hClientTimers[client] = CreateTimer(GetConVarFloat(cvar_time), Timer_End, GetClientUserId(client));
		}
		else
		{
			ResetTimer(client);
			CPrintToChat(client, "%t", "Cooldown_Not_Expired");
		
			char szSound[128];
			bool random = GetConVarInt(g_cPlayType) == 1;
			int success = GetSound(sounds, g_cSoundPath, random, szSound, sizeof(szSound));
			
			if(success != -1)
			{
				g_iSoundBeingPlayed[client] = success;
				PlaySoundClient(client, szSound, 1.0);
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
		return;
	
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

		if(GetConVarBool(g_bEnableWarn) && (g_iCampCounters[client] % GetConVarInt(g_iWarnValue) == 0))
		{
			char szWarnReason[256];
			GetConVarString(g_szWarnReason, szWarnReason, sizeof(szWarnReason));
			smwarn_warn(client, szWarnReason);
		}

		char szSound[128];
		bool random = GetConVarInt(g_cPlayType) == 1;
		int success = GetSound(sounds, g_cSoundPath, random, szSound, sizeof(szSound));
		
		if(success != -1)
		{
			g_iSoundBeingPlayed[client] = random;
			PlaySoundClient(client, szSound, 1.0);
		}

		float SlapDamage = GetConVarFloat(g_SlapDamage);

		if(GetConVarBool(g_cBlindPlayer))
			PerformBlind(0, client, 255);

		if(GetConVarBool(g_cRampupDamage))
			SlapDamage *= g_iCampCounters[client];

		if(g_cSlapOrDamage.BoolValue)
			SDKHooks_TakeDamage(client, 0, 0, SlapDamage);
		else
			SlapPlayer(client, RoundToFloor(SlapDamage), true);

		delete(g_hFreqTimers[client]);
		g_hFreqTimers[client] = CreateTimer(GetConVarFloat(g_PunishFreq), Repeat_Timer, GetClientUserId(client), TIMER_REPEAT);
	}
}


public Action Repeat_Timer(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);

	if (!client)
    return Plugin_Stop; // Stop early, invalid client index.

	if (!IsPlayerAlive(client))
	{
		g_hFreqTimers[client] = null;
		return Plugin_Stop;
  }

	CPrintToChat(client, "%t", "Camp_Message_Self");

	if(g_cSlapOrDamage.BoolValue)
		SDKHooks_TakeDamage(client, 0, 0, GetConVarFloat(g_SlapDamage));
	else
		SlapPlayer(client, GetConVarInt(g_SlapDamage), true);

	return Plugin_Continue;
}

public Action AntiCamp_Disable(Handle timer)
{
	g_anticampdisabled = true;

	CPrintToChatAll("%t", "AntiCamp_Disabled");

	for(int iClient = 1; iClient <= MaxClients; iClient++)
		ResetTimer(iClient);

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


stock bool IsValidClient(int client, bool nobots = true)
{ 
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false; 
	}
	return IsClientInGame(client) && IsClientAuthorized(client); 
} 


stock void PerformBlind(int client, int target, int amount)
{
	if(!IsValidClient(target))
		return;
	
	int targets[2];
	targets[0] = target;
	
	int duration = 1536;
	int holdtime = 1536;
	int flags;
	if (amount == 0)
	{
		flags = (0x0001 | 0x0010);
	}
	else
	{
		flags = (0x0002 | 0x0008);
	}
	
	int color[4] = { 0, 0, 0, 0 };
	color[3] = amount;
	
	Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", duration);
		pb.SetInt("hold_time", holdtime);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(duration);
		bf.WriteShort(holdtime);
		bf.WriteShort(flags);		
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}
	
	EndMessage();

	//LogAction(client, target, "\"%L\" set blind on \"%L\" (amount \"%d\")", client, target, amount);
}

stock void RefreshSounds(int client)
{
	char soundPath[PLATFORM_MAX_PATH];

	GetConVarString(g_cSoundPath, soundPath, sizeof(soundPath));
	
	if(StrEqual("", soundPath))
	{
		if(IsValidClient(client))
			CReplyToCommand(client, "%t", "Invalid Sound Path");
		return;
	}
	
	int size = LoadSounds(sounds, g_cSoundPath);
	if(size > 0)
	{
		if(IsValidClient(client))
			CReplyToCommand(client, "%t", "Sounds Reloaded", size);
	}
	else
	{
		if(IsValidClient(client))
			CReplyToCommand(client, "%t", "Invalid Sound Path");
	}
}
		


public Action CommandReload(int client, int args)
{
	RefreshSounds(client);
	return Plugin_Handled;
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