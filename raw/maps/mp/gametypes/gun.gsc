//****************************************************************************
//                                                                          **
//           Confidential - (C) Activision Publishing, Inc. 2010            **
//                                                                          **
//****************************************************************************
//                                                                          **
//    Module:  The Gun Game ported from MW3                                 **
//             (1) Players advance through a predetermined list of weapons  **
//                 after killing an enemy.                                  **
//             (2) Melee kill will drop the victim one weapon level down.   **
//             (3) Committing suicide will also drop one level down from    ** 
//                 the weapon progression.                                  **                   
//             (4) Player who reaches the end of the weapon progression     **
//                 list win the watch.                                      **
//             (5) Players' custom perk, equipment and killstreak are       **
//                 disabled in this game mode.                              **
//                                                                          **
//                                                                          ** 
//    Created: August 23rd, 2011 - James Chen                               **
//                                                                          **
//***************************************************************************/

#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes\_class;

GUN_HUD_PREV_GUN = 0;
GUN_HUD_CUR_GUN = 1;
GUN_HUD_NEXT_GUN = 2;
GUN_TABLE_ICON_INDEX = 6;

main()
{
	precachestring( &"SPLASHES_DROPPED_GUN_RANK" );
	precachestring( &"SPLASHES_GAINED_GUN_RANK" );
	precachestring( &"SPLASHES_DROPPED_ENEMY_GUN_RANK" );

	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();

	//tagJC<NOTE>: The following three C func are not present in NX1 codebase.
	//             * GetMatchRulesData
	//             * isUsingMatchRulesData
	//             * SetCommonRulesFromMatchRulesData
	//             Those three functions are related to the recipe system in MW3.  The following code block is commented out
	//             for the moment.  In the case where we decide to port over the recipe system, this section can be uncommented
	//             quickly.

	/* if ( isUsingMatchRulesData() )
	{
		//	set common values
		setCommonRulesFromMatchRulesData( true );
		
		//	set everything else (private match options, default .cfg file values, and what normally is registered in the 'else' below)	
		level.matchRules_guns = GetMatchRulesData( "gunData", "guns" );
		level.matchRules_numGuns = GetMatchRulesData( "gunData", "numGuns" );			
		
		SetDvar( "scr_gun_winlimit", 1 );
		registerWinLimitDvar( "gun", 1 );
		SetDvar( "scr_gun_roundlimit", 1 );
		registerRoundLimitDvar( "gun", 1 );
		SetDvar( "scr_gun_halftime", 0 );
		registerHalfTimeDvar( "gun", 0 );
			
		SetDvar( "scr_gun_promode", 0 );		
	}
	else
	{ */
		registerTimeLimitDvar( level._gameType, 10, 0, 1440 );
		registerScoreLimitDvar( level._gameType, 0, 0, 1000 );
		registerRoundLimitDvar( level._gameType, 1, 0, 10 );
		registerWinLimitDvar( level._gameType, 0, 0, 10 );
		registerNumLivesDvar( level._gameType, 0, 0, 10 );
		registerHalfTimeDvar( level._gameType, 0, 0, 1 ); 
	// }
	
	level._chooseTeam = false;
	level._teamBased = false;
	level._doPrematch = true;
	level._killstreakRewards = false;
	level._onStartGameType = ::onStartGameType;
	level._onSpawnPlayer = ::onSpawnPlayer;
	level._getSpawnPoint = ::getSpawnPoint;
	level._onPlayerKilled = ::onPlayerKilled;
	level._onTimeLimit = ::onTimeLimit;
	level._blockWeaponDrops = true;
	level._blockRechargeablePerk = true; 
	level._blockClassChange = true;
	level._overridePlayerModel = true;
	level._disableWarSuit = true;
	setDvar( "scr_game_hardpoints", "0" );
	setDvar( "scr_game_perks", "0" );

	game["dialog"]["gametype"] = "gun";
}

onStartGameType()
{
	setClientNameMode("auto_change");

	setObjectiveText( "allies", &"OBJECTIVES_DM" );
	setObjectiveText( "axis", &"OBJECTIVES_DM" );

	if ( level._splitscreen )
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_DM" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_DM" );
	}
	else
	{
		setObjectiveScoreText( "allies", &"OBJECTIVES_DM_SCORE" );
		setObjectiveScoreText( "axis", &"OBJECTIVES_DM_SCORE" );
	}
	setObjectiveHintText( "allies", &"OBJECTIVES_DM_HINT" );
	setObjectiveHintText( "axis", &"OBJECTIVES_DM_HINT" );

	level._spawnMins = ( 0, 0, 0 );
	level._spawnMaxs = ( 0, 0, 0 );

	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "allies", "mp_dm_spawn" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "axis", "mp_dm_spawn" );

	level._mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level._spawnMins, level._spawnMaxs );
	setMapCenter( level._mapCenter );
	
	maps\mp\gametypes\_rank::registerScoreInfo( "gained_gun_rank", 50 );
	maps\mp\gametypes\_rank::registerScoreInfo( "dropped_enemy_gun_rank", 100 );

	allowed[0] = "gun";
	maps\mp\gametypes\_gameobjects::main(allowed);

	level._QuickMessageToAll = true;
	level._blockWeaponDrops = true;
	
	gun();
}

gun()
{
	//tagJC<NOTE>: Potentially, we might want to move the following gun progression specification into an external file.
	//	temp hard coded progression
	level.gunGameGunProgression     = [];	
	//	hand guns
	level.gunGameGunProgression[0]  = "beretta";	
	//	machine pistols
	level.gunGameGunProgression[1]  = "glock";
	level.gunGameGunProgression[2]  = "beretta393";
	//	sub
	level.gunGameGunProgression[3]  = "type104";
	level.gunGameGunProgression[4]  = "ump45";
	level.gunGameGunProgression[5]  = "p90";			
	//	assault - auto
	level.gunGameGunProgression[6]  = "scar";
	level.gunGameGunProgression[7]  = "xm108";
	level.gunGameGunProgression[8]  = "fal";		
	//	lmg
	level.gunGameGunProgression[9]  = "glo";
	level.gunGameGunProgression[10] = "m240";
	//	shotgun
	level.gunGameGunProgression[11] = "spas12";
	level.gunGameGunProgression[12] = "aa12";
	level.gunGameGunProgression[13] = "m1014";
	//	assault - burst
	level.gunGameGunProgression[14] = "famas";
	level.gunGameGunProgression[15] = "asmk27";	
	//	sniper
	level.gunGameGunProgression[16] = "barrett";
	level.gunGameGunProgression[17] = "wa2000";	
	//	launcher
	level.gunGameGunProgression[18] = "xm25";
	
	//	precache
	for ( i=0; i<level.gunGameGunProgression.size; i++ )
	{
		icon = tablelookup( "mp/statstable.csv", 4, level.gunGameGunProgression[i], GUN_TABLE_ICON_INDEX );
		precacheShader( icon );
	}
	
	//	set index on enter	
	level thread onPlayerConnect();	
}

onPlayerConnect()
{
	for ( ;; )
	{
		level waittill( "connected", player );
		
		player.gunGameGunIndex = 0;
		player.gunGamePrevGunIndex = 0;
		player initGunHUD();
		
		player thread refillAmmo();
		player thread refillSingleCountAmmo();
	}
}

initGunHUD()
{
	self.gunIcons = [];
	baseGun = tablelookup( "mp/statstable.csv", 4, level.gunGameGunProgression[0], GUN_TABLE_ICON_INDEX );
	if ( level._splitscreen )
	{
		xOffset = -50;
		for ( i=0; i<3; i++ )
		{			
			self.gunIcons[i] = createIcon( baseGun, 28, 28 );
			self.gunIcons[i] setPoint( "BOTTOM RIGHT", "BOTTOM RIGHT", (0+xOffset), -78 );
			self.gunIcons[i].alpha = 0;
			self.gunIcons[i].color = (0.9, 0.8, 0.65);
			self.gunIcons[i].hidewheninmenu = true;
			level thread hideOnGameEnd( self.gunIcons[i] );
			xOffset += 50;
		}
	}
	else
	{
		xOffset = -165;
		for ( i=0; i<3; i++ )
		{
			self.gunIcons[i] = createIcon( baseGun, 40, 40 );
			self.gunIcons[i] setPoint( "BOTTOM", "BOTTOM", (160+xOffset), -365 );
			self.gunIcons[i].alpha = 0;
			self.gunIcons[i].color = (0.9, 0.8, 0.65);
			self.gunIcons[i].hidewheninmenu = true;
			level thread hideOnGameEnd( self.gunIcons[i] );
			xOffset += 50;
		}
	}
	self.gunIcons[GUN_HUD_CUR_GUN].alpha = 0.75;
	self.gunIcons[GUN_HUD_CUR_GUN].color = (1, 1, 1);	
}

updateGunHUD()
{
	//	current gun
	self setGunHUDIcon( GUN_HUD_CUR_GUN, self.gunGameGunIndex );
	
	//	previous gun
	if ( self.gunGameGunIndex == 0 )
		self.gunIcons[GUN_HUD_PREV_GUN].alpha = 0;
	else
		self setGunHUDIcon( GUN_HUD_PREV_GUN, self.gunGameGunIndex-1 );
	
	//	next gun
	if ( self.gunGameGunIndex == level.gunGameGunProgression.size-1 )
		self.gunIcons[GUN_HUD_NEXT_GUN].alpha = 0;
	else
		self setGunHUDIcon( GUN_HUD_NEXT_GUN, self.gunGameGunIndex+1 );
}

setGunHUDIcon( iconIndex, gunIndex )
{	
	//	get the icon for this gun
	icon = tablelookup( "mp/statstable.csv", 4, level.gunGameGunProgression[gunIndex], GUN_TABLE_ICON_INDEX );

	//tagJC<NOTE>: MW3 uses another column in the statstable to specify the ratio.  Currently hard coding the ratio to 2.
	ratio = 2;	

	//	set defaults
	if ( level._splitscreen )
	{
		width = 28;
		height = 28;
		point = "BOTTOM RIGHT";
		relativePoint = "BOTTOM RIGHT";
		baseX = 0;
		baseY = -78;
	}
	else
	{
		width = 40;
		height = 40;
		point = "BOTTOM";
		relativePoint = "BOTTOM";
		baseX = -165;
		baseY = -365;
	}
	
	//	shrink and fade non current
	if ( iconIndex != GUN_HUD_CUR_GUN )
	{
		width *= 0.66;
		height *= 0.66;
		alpha = 0.33;
	}
	
	//	fix for ratio
	if ( ratio == 2 )
		width *= 2;
	else if ( ratio == 4 )
	{
		width *= 2;
		height *= 0.5;
	}
	
	//	set the shader, update width/height
	width = int( width );
	height = int( height );
	self.gunIcons[iconIndex] setShader( icon, width, height );
	self.gunIcons[iconIndex].width = width;
	self.gunIcons[iconIndex].height = height;		
	
	//	default pos
	xOffset = 0;
	
	//	default color
	color = (1, 1, 1);
	
	//	adjust pos of non current
	if ( iconIndex == GUN_HUD_PREV_GUN )
	{
		xOffset = ( ( self.gunIcons[GUN_HUD_CUR_GUN].width / 2 ) + ( self.gunIcons[GUN_HUD_PREV_GUN].width / 2 ) ) * -1;
		color = (0.9, 0.8, 0.65);
	}
	else if ( iconIndex == GUN_HUD_NEXT_GUN )
	{
		xOffset = ( self.gunIcons[GUN_HUD_CUR_GUN].width / 2 ) + ( self.gunIcons[GUN_HUD_NEXT_GUN].width / 2 );
		color = (0.9, 0.8, 0.65);
	}
	
	//	set pos
	self.gunIcons[iconIndex] setPoint( point, relativePoint, (baseX+xOffset), baseY );
	
	//	set color
	self.gunIcons[iconIndex].color = color;
	
	//	set alpha
	self.gunIcons[iconIndex].alpha = 0.75;
}

getSpawnPoint()
{
	spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( self.pers["team"] );
	spawnPoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_DM( spawnPoints );

	return spawnPoint;
}

onSpawnPlayer()
{
	self thread waitLoadoutDone();
	
	level notify ( "spawned_player" );	
}

waitLoadoutDone()
{	
	level endon( "game_ended" );
	self endon( "disconnect" );
	
	level waittill( "player_spawned" );
	
	//tagJC<NOTE>: Taking away players' weapon and equipment loadouts
	self TakeAllWeapons();
	self giveNextGun();
}

giveNextGun()
{	
	oldWeapon = self.primaryWeapon;
	newWeapon = level.gunGameGunProgression[self.gunGameGunIndex] + "_mp";
	
	//	give gun
	_giveWeapon( newWeapon );		
	self setSpawnWeapon( newWeapon );
	newWeaponShort = strtok( newWeapon, "_" );
	self.pers["primaryWeapon"] = newWeaponShort[0];		
	self.primaryWeapon = newWeapon;
	self GiveStartAmmo( newWeapon );
	self switchToWeapon( newWeapon );
	self takeWeapon( oldWeapon );		
	
	//	gain/drop scoring/messaging
	if ( self.gunGamePrevGunIndex > self.gunGameGunIndex )
	{
		//	we dropped :(
		self thread maps\mp\gametypes\_rank::xpEventPopup( &"SPLASHES_DROPPED_GUN_RANK" );		
	}
	else if ( self.gunGamePrevGunIndex < self.gunGameGunIndex )
	{
		//	we gained :)
		self thread maps\mp\gametypes\_rank::xpEventPopup( &"SPLASHES_GAINED_GUN_RANK" );
		//tagJC<NOTE>: A fourth boolean argument is added for the function givePlayerScore.  The new argument is used to specify whether
		//             the game should estimate the time when the match is ending.  In this particular game mode, since the 
		//             winning logic is not dependent on players' scores.  The time estimation logic is a waste of efforts and 
		//             that is why the game mode should override the estimation process. 
		maps\mp\gametypes\_gamescore::givePlayerScore( "gained_gun_rank", self, undefined, true );	
	}
	self.gunGamePrevGunIndex = self.gunGameGunIndex;
	
	//	update the personal gun progress hud
	self updateGunHUD();
}

onPlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration, lifeId )
{
	if ( isDefined( attacker ) && isPlayer( attacker ) )
	{
		if ( attacker == self || sMeansOfDeath == "MOD_MELEE" )
		{
			playSoundOnPlayers( "mp_war_objective_lost" );			
			
			//	drop level for suicide and getting knifed
			self.gunGamePrevGunIndex = self.gunGameGunIndex;
			self.gunGameGunIndex = int( max( 0, self.gunGameGunIndex-1 ) );		
			
			if ( sMeansOfDeath == "MOD_MELEE" )
			{
				attacker thread maps\mp\gametypes\_rank::xpEventPopup( &"SPLASHES_DROPPED_ENEMY_GUN_RANK" );
				//tagJC<NOTE>: A fourth boolean argument is added for the function givePlayerScore.  The new argument is used to specify whether
				//             the game should estimate the time when the match is ending.  In this particular game mode, since the 
				//             winning logic is not dependent on players' scores.  The time estimation logic is a waste of efforts and 
				//             that is why the game mode should override the estimation process.  
				maps\mp\gametypes\_gamescore::givePlayerScore( "dropped_enemy_gun_rank", attacker, undefined, true );				
			}	
		}
		else
		{
			attacker.gunGamePrevGunIndex = attacker.gunGameGunIndex;
			attacker.gunGameGunIndex++;
			if ( attacker.gunGameGunIndex == level.gunGameGunProgression.size-1 )
			{
				playSoundOnPlayers( "mp_enemy_obj_captured" );
				level thread teamPlayerCardSplash( "callout_top_gun_rank", attacker );
			}
			else
				playSoundOnPlayers( "mp_war_objective_taken" );					
				
			if ( attacker.gunGameGunIndex >= level.gunGameGunProgression.size )
				level thread maps\mp\gametypes\_gamelogic::endGame( attacker, &"MP_ENEMIES_ELIMINATED" );
			else
				attacker giveNextGun();			
		}
	}
}

onTimeLimit()
{
	level._finalKillCam_winner = "none";
	winner = getHighestProgressedPlayer();
	
	if ( isDefined( winner ) )
		thread maps\mp\gametypes\_gamelogic::endGame( winner, &"MP_ENEMIES_ELIMINATED" );
	else
		thread maps\mp\gametypes\_gamelogic::endGame( "tie", game["strings"]["time_limit_reached"] );
}

//	JDS TODO: not fair, do something real here, maybe score as secondary
getHighestProgressedPlayer()
{
	highestProgress = -1;
	highestProgressedPlayer = undefined;
	foreach( player in level._players )
	{
		if ( isDefined( player.gunGameGunIndex ) && player.gunGameGunIndex > highestProgress )
		{
			highestProgress = player.gunGameGunIndex;
			highestProgressedPlayer = player;
		}
	}
	return highestProgressedPlayer;
}

refillAmmo()
{
	level endon( "game_ended" );
	self  endon( "disconnect" );
	
	while ( true )
	{
		self waittill( "reload" );
		self playLocalSound( "scavenger_pack_pickup" );
		self GiveStartAmmo( (level.gunGameGunProgression[self.gunGameGunIndex]+"_mp") );
	}	
}

refillSingleCountAmmo()
{
	level endon( "game_ended" );
	self  endon( "disconnect" );
	
	while ( true )
	{
		if ( isDefined( self.primaryWeapon ) && self getAmmoCount( self.primaryWeapon ) == 0 )
		{
			//	fake a reload time
			wait( 2 );
			self notify( "reload" );
			wait( 1 );
		}
		else
			wait( 0.05 );
	}	
}

hideOnGameEnd( hudElem )
{
	level waittill("game_ended");
	hudElem.alpha = 0;
}