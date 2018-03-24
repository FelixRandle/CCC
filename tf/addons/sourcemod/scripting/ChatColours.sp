/*
TODO
Support loading tags based on letters from KV file. Like previous CCC plugin.
Add Natives.
*/

//POSSIBLE CVARS
//VER
//Plugin Tag
//

#pragma semicolon 1
#pragma newdecls required

//////////
//Defines
#define PLUGIN_AUTHOR 		"FliX" 
#define PLUGIN_VERSION 		"1.30"
#define PLUGIN_TAG			"{dodgerblue}[{valve}CCC{dodgerblue}]\x01 "

//////////
//Includes
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <chat-processor>
#include <colorvariables>
#include <regex>

//////////
//Plugin Info
public Plugin myinfo = 
{
	name = 			"ChatColours", 
	author = 		PLUGIN_AUTHOR, 
	description = 	"Adds chat colours and Tag support for TF2", 
	version = 		PLUGIN_VERSION, 
	url = 			"dream-horizon.com"
};

//////////
//Globals
//DATABASE
Database db;

//COOKIES
Handle g_hClientCookieTT = INVALID_HANDLE;
Handle g_hClientCookieTC = INVALID_HANDLE;
Handle g_hClientCookieNC = INVALID_HANDLE;
Handle g_hClientCookieCC = INVALID_HANDLE;

Handle g_chatColoursMain = INVALID_HANDLE;
Handle g_tagTextMenu = INVALID_HANDLE;
Handle g_tagColourMenu = INVALID_HANDLE;
Handle g_nameColourMenu = INVALID_HANDLE;
Handle g_chatColourMenu = INVALID_HANDLE;

//STRINGS
char g_clientTT[MAXPLAYERS][64];
char g_clientTC[MAXPLAYERS][64];
char g_clientNC[MAXPLAYERS][64];
char g_clientCC[MAXPLAYERS][64];
char g_DisplayName[100][256];
char g_SourceName[100][256];
char g_tagName[100][256];

//INTS
int g_ColourCount;
int g_ColourIndex[100];
int g_tagCount;
int g_tagIndex[100];

//BOOLS
bool g_readyToLoad[MAXPLAYERS + 1];

public void OnPluginStart()
{
	//COOKIE CREATION
	g_hClientCookieTT = RegClientCookie("clientTagText", "Text of users tag.", CookieAccess_Private);
	g_hClientCookieTC = RegClientCookie("clientTagColour", "Colour of users tag.", CookieAccess_Private);
	g_hClientCookieNC = RegClientCookie("clientNameColour", "Colour of users name.", CookieAccess_Private);
	g_hClientCookieCC = RegClientCookie("clientChatColour", "Colour of users chat.", CookieAccess_Private);
	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
	
	//ROOT COMMANDS
	RegAdminCmd("sm_reloadccc", CC_Reload, ADMFLAG_ROOT, "[CCC] Reloads colours from database.");
	RegAdminCmd("sm_addccc", CC_AddItem, ADMFLAG_ROOT, "[CCC]");
	
	//ADMIN COMMANDS
	RegAdminCmd("sm_settag", CC_SetTag, ADMFLAG_CHEATS, "[CCC] sm_settag <client> <tag>");
	RegAdminCmd("sm_settagcolour", CC_SetTagColour, ADMFLAG_CHEATS, "[CCC] sm_settag <client> <colour> Please use a supported shortcut or HEX in the format #FFFFFF for your colour.");
	RegAdminCmd("sm_setnamecolour", CC_SetNameColour, ADMFLAG_CHEATS, "[CCC] sm_settag <client> <colour> Please use a supported shortcut or HEX in the format #FFFFFF for your colour.");
	RegAdminCmd("sm_setchatcolour", CC_SetChatColour, ADMFLAG_CHEATS, "[CCC] sm_settag <client> <colour> Please use a supported shortcut or HEX in the format #FFFFFF for your colour.");
	
	//USER COMMANDS
	RegAdminCmd("sm_ccc", CC_Menu, ADMFLAG_RESERVATION, "[CCC] Command to bring up CCC menu");
	RegAdminCmd("sm_resettag", CC_ResetTag, ADMFLAG_RESERVATION, "[CCC] Command to reset the users tag.");
	RegAdminCmd("sm_resettagcolour", CC_ResetTagColour, ADMFLAG_RESERVATION, "[CCC] Command to reset the users tag colour.");
	RegAdminCmd("sm_resetnamecolour", CC_ResetNameColour, ADMFLAG_RESERVATION, "[CCC] Command to reset the users name colour.");
	RegAdminCmd("sm_resetchatcolour", CC_ResetChatColour, ADMFLAG_RESERVATION, "[CCC] Command to reset the users chat colour.");
	MenuCreation();
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	char authorName[MAXLENGTH_NAME];
	GetClientName(author, authorName, sizeof(authorName));
	if(!StrEqual(g_clientNC[author], ""))
	{
		Format(name, MAXLENGTH_NAME, "%s%s\x01",g_clientNC[author], name);
	}
	else
	{
		Format(name, MAXLENGTH_NAME, "\x03%s\x01", name);
	}
	//Format name to include colours
	Format(name, MAXLENGTH_NAME, "%s%s %s", g_clientTC[author], g_clientTT[author], name);
	//Format message to include colours
	Format(message, MAXLENGTH_MESSAGE, "%s%s", g_clientCC[author], message);
	return Plugin_Changed;
}

//To Ensure players cannot end up with staff tags
public void OnClientDisconnect(int client) 
{
	g_clientTT[client] = "";
	g_clientTC[client] = "";
	g_clientNC[client] = "";
	g_clientCC[client] = "";
}

//Load player info only when both cookies are cached and the post-admin checks are completed.
public void OnClientCookiesCached(int client) {
    if (g_readyToLoad[client]) {
        LoadPlayerInfo(client);
    }
    
    g_readyToLoad[client] = true;
}

public void OnClientPostAdminCheck(int client) {
    if (g_readyToLoad[client]) {
        LoadPlayerInfo(client);
    }
    
    g_readyToLoad[client] = true;
}

//COMMAND FUNCTIONS

public Action CC_Reload(int client, int args) 
{
	MenuCreation();
	ReplyToCommand(client, "%sCustomChatColours reloaded.", PLUGIN_TAG);
	return Plugin_Handled;
}

public Action CC_SetTag(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "[SM] Incorrect Usage: sm_settag <client> <tag>");
		return Plugin_Handled;
	}
	char arg1[32], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	TagSet(target, arg2);
	CPrintToChat(client, "%sSuccessfully changed %N's tag to %s", PLUGIN_TAG, target, arg2);
	return Plugin_Handled;
}

public Action CC_SetTagColour(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "[SM] Incorrect Usage: sm_settagcolour <client> <colour>");
		return Plugin_Handled;
	}
	char arg1[32], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	TagColourSet(target, arg2);
	CPrintToChat(client, "%sSuccessfully changed %N's Tag colour to %s", PLUGIN_TAG, target, arg2);
	return Plugin_Handled;
}

public Action CC_SetNameColour(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "[SM] Incorrect Usage: sm_setnamecolour <client> <colour>");
		return Plugin_Handled;
	}
	char arg1[32], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	NameColourSet(target, arg2);
	CPrintToChat(client, "%sSuccessfully changed %N's Name colour to %s", PLUGIN_TAG, target, arg2);
	return Plugin_Handled;
}

public Action CC_SetChatColour(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "[SM] Incorrect Usage: sm_setchatcolour <client> <colour>");
		return Plugin_Handled;
	}
	char arg1[32], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	ChatColourSet(target, arg2);
	CPrintToChat(client, "%sSuccessfully changed %N's Chat colour to %s", PLUGIN_TAG, target, arg2);
	return Plugin_Handled;
}

public Action CC_Menu(int client, int args)
{
	if(IsVoteInProgress())
	{
		CPrintToChat(client, "%sA vote is currently in progress. Please wait until it is over.", PLUGIN_TAG);
		return Plugin_Handled;
	}
	//Create Menu Items.
	g_chatColoursMain = CreateMenu(CCMainHandler);
	SetMenuTitle(g_chatColoursMain, "Custom Chat Colours");
	AddMenuItem(g_chatColoursMain, "TT", "Tag Text");
	AddMenuItem(g_chatColoursMain, "TC", "Tag Colour");
	AddMenuItem(g_chatColoursMain, "NC", "Name Colour");
	AddMenuItem(g_chatColoursMain, "CC", "Chat Colour");
	AddMenuItem(g_chatColoursMain, "RA", "Reset All");
	DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action CC_ResetTag(int client, int args)
{
	ResetTag(client);
	CReplyToCommand(client, "%sTag successfully reset.", PLUGIN_TAG);
	return Plugin_Handled;
}

public Action CC_ResetTagColour(int client, int args)
{
	ResetTagColour(client);
	CReplyToCommand(client, "%sTag colour successfully reset.", PLUGIN_TAG);
	return Plugin_Handled;
}

public Action CC_ResetNameColour(int client, int args)
{
	ResetNameColour(client);
	CReplyToCommand(client, "%sName colour successfully reset.", PLUGIN_TAG);
	return Plugin_Handled;
}

public Action CC_ResetChatColour(int client, int args)
{
	ResetChatColour(client);
	CReplyToCommand(client, "%sChat colour successfully reset.", PLUGIN_TAG);
	return Plugin_Handled;
}

public Action CC_AddItem(int client, int args)
{
	// sm_addccc <type> <displayName> <sourceName>
	if(db == null)
	{
		CReplyToCommand(client, "%sDatabase not connected. Please try again later.", PLUGIN_TAG);
		return Plugin_Handled;
	}
	char itemType[32];
	char displayName[32];
	char sourceName[32];
	GetCmdArg(1, itemType, sizeof(itemType));
	GetCmdArg(2, displayName, sizeof(displayName));
	GetCmdArg(3, sourceName, sizeof(sourceName));
	if(args != 3 || !StrEqual(itemType, "CCC_TAG") || !StrEqual(itemType, "CCC_COLOUR"))
	{
		CReplyToCommand(client, "%sIncorrect Usage: sm_addccc <type> <displayName> <sourceName>", PLUGIN_TAG);
		return Plugin_Handled;
	}
	char escapedDisplayName[64];
	char escapedSourceName[64];
	SQL_EscapeString(db, displayName, escapedDisplayName, sizeof(escapedDisplayName));
	SQL_EscapeString(db, sourceName, escapedSourceName, sizeof(escapedSourceName));
	char query[128];
	Format(query, sizeof(query), "INSERT INTO customChatColours VALUES ('%s','%s','%s')", itemType, escapedDisplayName, escapedSourceName);
	if(!SQL_FastQuery(db, query))
	{
		char error[255];
		SQL_GetError(db, error, sizeof(error));
		CReplyToCommand(client, "%sAn unexpected error occured. Please contact a server operator", PLUGIN_TAG);
		PrintToServer("Failed to query (error: %s)", error);
		return Plugin_Handled;
	}
	CReplyToCommand(client, "%sSuccessfully added %s (Source - %s) as a %s)", displayName, sourceName, itemType);
	return Plugin_Handled;
}

//MENU ITEMS

void MenuCreation()
{	
	if(!CCC_Load())
	{
		SetFailState("Unable to connect to the MySQL server.");
	}
	else
	{
		g_tagColourMenu = CreateMenu(TCHandler);
		SetMenuTitle(g_tagColourMenu, "Tag Colour");
		AddMenuItem(g_tagColourMenu, "RC", "Reset Tag Colour");
		g_nameColourMenu = CreateMenu(NCHandler);
		SetMenuTitle(g_nameColourMenu, "Name Colour");
		AddMenuItem(g_nameColourMenu, "RC", "Reset Name Colour");
		g_chatColourMenu = CreateMenu(CCHandler);
		SetMenuTitle(g_chatColourMenu, "Chat Colour");
		AddMenuItem(g_chatColourMenu, "RC", "Reset Chat Colour");
		int i = 0;
		char strColourIndex[4];
		while(i < g_ColourCount)
		{	
			IntToString(i, strColourIndex, 4);
			AddMenuItem(g_tagColourMenu, strColourIndex, g_DisplayName[i], 0);
			AddMenuItem(g_nameColourMenu, strColourIndex, g_DisplayName[i], 0);
			AddMenuItem(g_chatColourMenu, strColourIndex, g_DisplayName[i], 0);
			i++; 
		}

		g_tagTextMenu = CreateMenu(TTHandler);
		SetMenuTitle(g_tagTextMenu, "Tag Text");
		AddMenuItem(g_tagTextMenu, "RT", "Reset Tag");
		i = 0;
		char strTagIndex[4];
		while(i < g_tagCount)
		{
			IntToString(i, strTagIndex, 4);
			AddMenuItem(g_tagTextMenu, strTagIndex, g_tagName[i], 0);
			i++; 
		}
	}
}

public int CCMainHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		if (StrEqual(cValue, "TT")) {
			DisplayMenu(g_tagTextMenu, client, MENU_TIME_FOREVER);
		} else if (StrEqual(cValue, "TC")) {
			DisplayMenu(g_tagColourMenu, client, MENU_TIME_FOREVER);
		} else if (StrEqual(cValue, "NC")) {
			DisplayMenu(g_nameColourMenu, client, MENU_TIME_FOREVER);
		} else if (StrEqual(cValue, "CC")) {
			DisplayMenu(g_chatColourMenu, client, MENU_TIME_FOREVER);
		} else if (StrEqual(cValue, "RA")) {
			ResetCCC(client);
		}
	}
}

public int TTHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		if (StrEqual(cValue, "RT")) 
		{
			ResetTag(client);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		} 
		else 
		{
			int indexBuffer = StringToInt(cValue, 10);
			TagSet(client, g_tagName[indexBuffer]);
			CPrintToChat(client, "%sNew Tag - %s%s", PLUGIN_TAG, g_clientTC[client], g_tagName[indexBuffer]);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		}
	}
}

public int TCHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		if (StrEqual(cValue, "RC"))
		{
			ResetTagColour(client);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		}
		else
		{
			int indexBuffer = StringToInt(cValue, 10);
			TagColourSet(client, g_SourceName[indexBuffer]);
			CPrintToChat(client, "%sNew Tag Colour - %sThe quick brown fox jumped over the lazy dogs.", PLUGIN_TAG, g_clientTC[client]);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		}
	}
}

public int NCHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		if (StrEqual(cValue, "RC"))
		{
			ResetNameColour(client);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		}
		else
		{
			int indexBuffer = StringToInt(cValue, 10);
			NameColourSet(client, g_SourceName[indexBuffer]);
			CPrintToChat(client, "%sNew Name Colour - %sThe quick brown fox jumped over the lazy dogs.", PLUGIN_TAG, g_clientNC[client]);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		}
	}
}

public int CCHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		if (StrEqual(cValue, "RC"))
		{
			ResetChatColour(client);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		}
		else
		{
			int indexBuffer = StringToInt(cValue, 10);
			ChatColourSet(client, g_SourceName[indexBuffer]);
			CPrintToChat(client, "%sNew Chat Colour - %sThe quick brown fox jumped over the lazy dogs.", PLUGIN_TAG, g_clientCC[client]);
			DisplayMenu(g_chatColoursMain, client, MENU_TIME_FOREVER);
		}
	}
}

//Load Tags and colours from db.

public bool CCC_Load()
{
	char error[255];
	db = SQL_Connect("CustomChatColours", true, error, sizeof(error));
	
	if(db == null)
	{
		PrintToServer("Could not connect: %s", error);
		return false;
	}
	else
	{
		if(!SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS customChatColours(ItemType VARCHAR(20) NOT NULL, displayName VARCHAR(20) NOT NULL, sourceName VARCHAR(20) NOT NULL)"))
		{
			error = "";
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
			return false;
		}
	}
	
	g_tagCount = FetchResults(db, "CCC_TAG");
	PrintToServer("Loaded %i tags for CCC", g_tagCount);
	
	g_ColourCount = FetchResults(db, "CCC_COLOUR");
	PrintToServer("Loaded %i colours for CCC", g_ColourCount);
	return true;	
}

public int FetchResults(Database database, char[] itemType)
{
	/*
	Returns number of rows found.
	*/
	char query[100];
	
	
	Format(query, sizeof(query), "SELECT displayName, sourceName from customChatColours where ItemType = '%s'", itemType);
	DBResultSet results = SQL_Query(database, query);
	if(results == null)
	{
		return 0;
	}
	
	int count = SQL_GetRowCount(results);
	int counter = 0;
	
	while(SQL_FetchRow(results))
	{
		char displayName[64];
		char sourceName[64];
		SQL_FetchString(results, 0, displayName, sizeof(displayName));
		SQL_FetchString(results, 1, sourceName, sizeof(sourceName));
		if(StrEqual(itemType, "CCC_COLOUR"))
		{
			Format(g_DisplayName[counter], 64, "%s", displayName);
			Format(g_SourceName[counter], 64, "%s", sourceName);
			g_ColourIndex[counter] = counter;
		}
		if(StrEqual(itemType, "CCC_TAG"))
		{
			Format(g_tagName[counter], 64, "%s", displayName);
			g_tagIndex[counter] = counter;
		}
		counter++;
	}
	
	delete results;
	return count;
}

//TODO Look at previous CCC, see how it checks a-z admin flags.
/*
PLUGIN FUNCTIONS
*/

stock void LoadPlayerInfo(int client)
{
	char cookieBuffer[32];
	GetClientCookie(client, g_hClientCookieTT, cookieBuffer, sizeof(cookieBuffer));
	g_clientTT[client] = cookieBuffer;
	GetClientCookie(client, g_hClientCookieTC, cookieBuffer, sizeof(cookieBuffer));
	g_clientTC[client] = cookieBuffer;
	GetClientCookie(client, g_hClientCookieNC, cookieBuffer, sizeof(cookieBuffer));
	g_clientNC[client] = cookieBuffer;
	GetClientCookie(client, g_hClientCookieCC, cookieBuffer, sizeof(cookieBuffer));
	g_clientCC[client] = cookieBuffer;
	if(GetUserFlagBits(client) & (ADMFLAG_GENERIC) == (ADMFLAG_GENERIC)) {
		if(StrEqual(g_clientTT[client], "")) {
			ResetTag(client);
		}
	}
	else if (!GetUserFlagBits(client) && StrEqual(g_clientTT[client], ""))
	{
		ResetTag(client);
	}
}

void TagSet(int client, char[] tag, bool checkCorrect = true)
{
	if(!SimpleRegexMatch(tag, "^\\[.*\\]$") && checkCorrect && !StrEqual(tag, ""))
	{
		Format(tag, 64, "[%s]", tag);
	}
	SetClientCookie(client, g_hClientCookieTT, tag);
	Format(g_clientTT[client], 16, tag);
}

void TagColourSet(int client, char[] colour)
{
	if(!SimpleRegexMatch(colour, "^\\{.*\\}$"))
	{
		Format(colour, 64, "{%s}", colour);
	}
	SetClientCookie(client, g_hClientCookieTC, colour);
	Format(g_clientTC[client], 16, colour);
}

void NameColourSet(int client, char[] colour)
{
	if(!SimpleRegexMatch(colour, "^\\{.*\\}$"))
	{
		Format(colour, 64, "{%s}", colour);
	}
	SetClientCookie(client, g_hClientCookieNC, colour);
	Format(g_clientNC[client], 16, colour);
}

void ChatColourSet(int client, char[] colour)
{
	if(!SimpleRegexMatch(colour, "^\\{.*\\}$"))
	{
		Format(colour, 64, "{%s}", colour);
	}
	SetClientCookie(client, g_hClientCookieCC, colour);
	Format(g_clientCC[client], 16, colour);
}

void ResetTagColour(int client)
{
	SetClientCookie(client, g_hClientCookieTC, "");
	Format(g_clientTC[client], 16, "");
}

void ResetNameColour(int client)
{
	SetClientCookie(client, g_hClientCookieNC, "");
	Format(g_clientNC[client], 16, "");
}

void ResetChatColour(int client)
{
	SetClientCookie(client, g_hClientCookieCC, "");
	Format(g_clientCC[client], 16, "");
}

void ResetTag(int client)
{
	//Cycles through user and if flags match admin setup, gives them staff TAG
	if (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_ROOT) == (ADMFLAG_GENERIC | ADMFLAG_ROOT)) {
		TagSet(client,"[WIZARD]");
	} else if (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_CUSTOM6) == (ADMFLAG_GENERIC | ADMFLAG_CUSTOM6)) {
		TagSet(client,"[Director]");
	} else if (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_CHEATS) == (ADMFLAG_GENERIC | ADMFLAG_CHEATS)) {
		TagSet(client,"[Root]");
	} else if (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_PASSWORD) == (ADMFLAG_GENERIC | ADMFLAG_PASSWORD)) {
		TagSet(client,"[Tech]");
	} else if (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_CHANGEMAP) == (ADMFLAG_GENERIC | ADMFLAG_CHANGEMAP)) {
		TagSet(client,"[Manager]");
	} else if (GetUserFlagBits(client) & (ADMFLAG_GENERIC | ADMFLAG_CUSTOM3) == (ADMFLAG_GENERIC | ADMFLAG_CUSTOM3)) {
		TagSet(client,"[Admin]");
	} else if (GetUserFlagBits(client) & (ADMFLAG_GENERIC) == (ADMFLAG_GENERIC)) {
		TagSet(client,"[Mod]");
	} else {
		TagSet(client, "", false);
	}
}

void ResetCCC(int client)
{
	ResetTagColour(client);
	ResetNameColour(client);
	ResetChatColour(client);
	ResetTag(client);
}

stock bool IsValidClient(int client, bool bAllowBots = false, bool bAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bAllowDead && !IsPlayerAlive(client)))
	{
		return false;
	}
	return true;
}
