#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

ConVar sv_skyname;
ConVar sv_skychange_showmenu;

ArrayList g_hSkyNames;

#define FILEPATH_SKYCONFIG "configs/skynames.txt"

#define CONCMD_SKY_DESCRIPTION "Change the skybox of the current map to any valid existing sky name"

public Plugin myinfo = 
{
	name = "Client-Side Sky Changer",
	author = "Saturn34",
	description = "Lets players replace the current map's skybox to their desired sky texture",
	version = "1.0",
	url = "https://github.com/Saturn34/change-skybox"
};

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_TF2)
		SetFailState("This plugin only works on Team Fortress 2.");

	ReadSkyConfig();

	// Cache ConVar into global variable, as its faster to call FindConVar() only once rather than everytime the sky needs to be changed
	sv_skyname = FindConVar("sv_skyname");

	if (sv_skyname == null)
		ThrowError("sv_skyname is not a valid server console variable");

	// ConVars
	sv_skychange_showmenu = CreateConVar("sv_skychange_showmenu", "1", "When a sky name is not found, display the sky changing menu to player", 0, true, 0.0, true, 1.0);

	// Commands
	RegAdminCmd("sm_reloadskynames", Cmd_ReloadSkyConfig, ADMFLAG_CONFIG);
	
	RegConsoleCmd("sm_skybox", Cmd_ChangeMySkybox, CONCMD_SKY_DESCRIPTION);
	RegConsoleCmd("sm_skyname", Cmd_ChangeMySkybox, CONCMD_SKY_DESCRIPTION);
	RegConsoleCmd("sm_sky", Cmd_ChangeMySkybox, CONCMD_SKY_DESCRIPTION);
}

public Action Cmd_ReloadSkyConfig(int client, int args)
{
	ReadSkyConfig();
	ReplyToCommand(client, "[SM] Successfully reloaded %s and found %d skies", FILEPATH_SKYCONFIG, g_hSkyNames.Length);
	return Plugin_Handled;
}

public Action Cmd_ChangeMySkybox(int client, int args)
{
	char sSkyName[64];
	GetCmdArg(1, sSkyName, sizeof(sSkyName));
	if (args != 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_sky <skyname>");

		// Bring up the menu when no arguments are specified
		OpenChangeSkyMenu(client, true);
		return Plugin_Handled;
	}

	ReplaceString(sSkyName, sizeof(sSkyName), "\\", "/");

	if (!IsStringValidSkyName(sSkyName))
	{
		ReplyToCommand(client, "[SM] Sky name \"%s\" is not found in the sky list.", sSkyName);
		
		OpenChangeSkyMenu(client, true);
		return Plugin_Handled;
	}

	ReplyToCommand(client, "[SM] Your skybox has been changed to %s", sSkyName);
	SendConVarValue(client, sv_skyname, sSkyName);
	return Plugin_Handled;
}

// Tests to see if a string is in sky name arraylist
bool IsStringValidSkyName(char[] sky)
{
	char sValidSky[64];
	for (int i = 0; i < g_hSkyNames.Length; i++)
	{
		g_hSkyNames.GetString(i, sValidSky, sizeof(sValidSky));

		if (StrEqual(sky, sValidSky, false))
			return true;
	}
	return false;
}

// Loads sky names into arraylist line-by-line from file skynames.txt
void ReadSkyConfig()
{
	if (g_hSkyNames != null)
	{
		delete g_hSkyNames;
	}

	char sSkyFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sSkyFilePath, sizeof(sSkyFilePath), FILEPATH_SKYCONFIG);

	// Let each member of array hold 65 bytes, converting them to cell type for parameter
	g_hSkyNames = new ArrayList(ByteCountToCells(65));

	Handle file = OpenFile(sSkyFilePath, "r");
	if (file == null)
	{
		LogError("Could not open file: %s", sSkyFilePath);
		return;
	}
	
	char sLine[64];
	while (!IsEndOfFile(file) && ReadFileLine(file, sLine, sizeof(sLine)))
	{
		TrimString(sLine);
		
		// Ignore lines that are empty or start with "//"
		if (sLine[0] == '\0'  || (sLine[0] == '/' && sLine[1] == '/'))
			continue;

		ReplaceString(sLine, sizeof(sLine), "\\", "/");

		g_hSkyNames.PushString(sLine);
	}
}

void OpenChangeSkyMenu(int client, bool foundNoSky = false)
{
	if (foundNoSky && !sv_skychange_showmenu.IntValue) 
		return;

	// No skies found in list, cancel menu
	if (g_hSkyNames.Length == 0)
	{
		ReplyToCommand(client, "[SM] There are no skynames setup.");
		ThrowError("No skies found in %s", FILEPATH_SKYCONFIG);
		return;
	}
	
	Menu hChangeSky = new Menu(Menu_ChangeSky);	
	hChangeSky.SetTitle("Change your sky:");

	char sValidSky[64];
	for (int i = 0; i < g_hSkyNames.Length; i++)
	{
		g_hSkyNames.GetString(i, sValidSky, sizeof(sValidSky));
		hChangeSky.AddItem(sValidSky, sValidSky);
	}

	hChangeSky.ExitButton = true;
	hChangeSky.Display(client, MENU_TIME_FOREVER);
	return;
}

public int Menu_ChangeSky(Handle menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sSkyName[64];
			GetMenuItem(menu, param2, sSkyName, sizeof(sSkyName));
			SendConVarValue(client, sv_skyname, sSkyName);
			ReplyToCommand(client, "[SM] Your skybox has been changed to %s", sSkyName);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}