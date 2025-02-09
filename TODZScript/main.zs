class TOD_Handler : EventHandler
{
	array<Actor> monstersFiredThisTic;
	array<TOD_TextBox> allTextBoxes;
	array<TOD_TextBox> activeTextBoxes;
	TOD_Le_GlScreen projection;
	TOD_Le_Viewport viewport;

	bool isPlayerTyping;
	int typeDelayTics;
	const TYPEDELAY = TICRATE / 2;
	uint perfectWords;
	uint perfectLevels;
	enum EPerfection
	{
		PERFECT_WordsPerLevel = 5,
		PERFECT_LevelsForLife = 3,
	}

	ui TOD_TextBox currentTextBox;
	ui Font typeFont;
	ui int currentPosition;
	ui String typedString;
	ui uint displayCharacterTics;
	ui String displayCharacter;
	ui bool imperfect;
	ui Shape2D textBoxMarker;
	ui Shape2DTransform markerTransform;

	override void OnRegister()
	{
		projection = New("TOD_Le_GlScreen");
	}

	override bool WorldHitscanPreFired(WorldEvent e)
	{
		if (e.thing.player) return false;

		if (monstersFiredThisTic.Find(e.thing) != monstersFiredThisTic.Size())
		{
			return true;
		}
		else
		{
			monstersFiredThisTic.Push(e.thing);
			let proj = e.thing.A_SpawnProjectile('TOD_HitscanProjectile');
		}
		return true;
	}

	override bool InputProcess (InputEvent e)
	{
		if (e.type == InputEvent.Type_KeyDown && !isPlayerTyping && activeTextBoxes.Size() > 0)
		{
			String bind = bindings.GetBinding(e.KeyScan);
			if (bind ~== "+attack" || bind ~== "+altattack")
			{
				EventHandler.SendNetworkEvent("TOD_StartTyping");
				return true;
			}
		}

		return false;
	}

	override void NetworkProcess (ConsoleEvent e)
	{
		// test event that spawns a random monster:
		if (e.name ~== "TOD_Test")
		{
			let ppawn = players[e.Player].mo;
			Vector2 ofs = Actor.RotateVector((192, 0), ppawn.angle + frandom(-90, 90));
			Vector3 spawnPos = ppawn.Vec3Offset(ofs.x, ofs.y, 0);
			class<Actor> victimClass = DoomMonsters[random(0, DoomMonsters.Size()-1)];
			let victim = Actor.Spawn(victimClass, spawnPos);
			victim.A_Face(ppawn);

			let stt = TOD_TextBox.Attach(ppawn, victim);
			if (!stt && victim)
			{
				victim.Destroy();
			}
		}

		if (e.name ~== "TOD_FinishTyping")
		{
			int id = e.args[0];
			if (id < activeTextBoxes.Size())
			{
				let tbox = activeTextBoxes[id];
				if (tbox)
				{
					activeTextBoxes.Delete(id);
					tbox.FinishTyping(e.args[1]);
				}
				if (activeTextBoxes.Size() <= 0)
				{
					ToggleTyping(false);
				}
			}
		}

		if (e.name ~== "TOD_StartTyping")
		{
			ToggleTyping(true);
		}
		if (e.name ~== "TOD_StopTyping")
		{
			ToggleTyping(false);
		}
		if (e.name ~== "TOD_ToggleTyping")
		{
			ToggleTyping(!isPlayerTyping);
		}

		if (e.name ~== "TOD_Deactivate")
		{
			int id = e.args[0];
			if (id < activeTextBoxes.Size())
			{
				let tbox = activeTextBoxes[id];
				activeTextBoxes.Delete(id);
				if (tbox)
				{
					tbox.Deactivate();
				}
			}
		}

		if (e.name ~== "TOD_WrongCharacter")
		{
			ResetPerfectCounter();
		}
	}

	override void InterfaceProcess (ConsoleEvent e)
	{
		if (e.name ~== "TOD_FocusTextbox")
		{
			typedstring = "";
			currentTextBox = activeTextBoxes[e.args[0]];
		}

		if (e.name ~== "TOD_PlayerDamaged")
		{
			let hud = TOD_Hud(statusbar);
			if (hud)
			{
				hud.PlayerDamaged();
			}
		}

		if (e.name ~== "TOD_PerfectLevelComplete")
		{
			let hud = TOD_Hud(statusbar);
			if (hud)
			{
				hud.PerfectLevelComplete();
			}
		}
	}

	override bool UiProcess(UiEvent e)
	{
		if (e.type == UiEvent.Type_KeyDown)
		{
			if (e.KeyChar == UiEvent.Key_ESCAPE)
			{
				Menu.SetMenu("MainMenu");
				return false;
			}

		}

		if (e.Type == UiEvent.Type_Char && !typeDelayTics)
		{
			String chr = String.Format("%c", e.keyChar);
			if (!chr) return false;
			//Console.Printf("UiProcess captured character \cd%s\c-", chr);
			TypeCharacter(chr);
			return true;
		}

		return false;
	}

	void ToggleTyping(bool enable)
	{
		if (!enable || activeTextBoxes.Size() <= 0)
		{
			isPlayerTyping = false;
			isUiProcessor = false;
			//level.SetFrozen(false);
			return;
		}

		if (!isPlayerTyping)
		{
			isPlayerTyping = true;
			isUiProcessor = true;
			players[0].mo.A_Stop();
			players[0].mo.A_AlertMonsters(1024);
			//level.SetFrozen(true);
			typeDelayTics = TYPEDELAY;
		}
	}

	void IncrementPerfectCounter()
	{
		if (++perfectWords >= PERFECT_WordsPerLevel)
		{
			perfectWords = 0;
			perfectLevels++;
			S_StartSound("tod/perfect", CHAN_AUTO);
			if (perfectLevels % PERFECT_LevelsForLife == 0)
			{
				players[0].mo.GiveBody(1);
			}
			EventHandler.SendInterfaceEvent(0, "TOD_PerfectLevelComplete");
		}
	}

	void ResetPerfectCounter()
	{
		// If the current perfect level counter is above
		// zero, reset it to zero:
		if (perfectWords > 0)
		{
			perfectWords = 0;
		}
		// If it was already zero, reset all levels
		// to zero:
		else
		{
			perfectLevels = 0;
		}
	}

	ui bool TypeCharacter(String chr)
	{
		if (!chr) return false;

		chr = TOD_Utils.CleanQuotes(chr);
		chr = TOD_Utils.CleanDashes(chr);

		if (currentTextBox && !currentTextBox.IsActive())
		{
			currentTextBox = null;
		}

		if (!currentTextBox)
		{
			for (int i = 0; i < activeTextBoxes.Size();  i++)
			{
				if (activeTextBoxes[i] && activeTextBoxes[i].firstCharacter ~== chr)
				{
					currentTextBox = activeTextBoxes[i];
					typedstring = "";
					break;
				}
			}
		}
		if (!currentTextBox)
		{
			S_StartSound("TOD/wrong", CHAN_AUTO);
			//EventHandler.SendNetworkEvent("TOD_WrongCharacter");
			//imperfect = true;
			return false;
		}
		if (!typedString)
		{
			currentPosition = -1;
			imperfect = false;
		}

		currentPosition++;
		String nextChar = currentTextBox.stringToType.Mid(currentPosition, 1);
		// skip spaces:
		while (nextChar == " ")
		{
			currentPosition++;
			typedString.AppendFormat(" ");
			nextChar = currentTextBox.stringToType.Mid(currentPosition, 1);
		}
		//Console.Printf("Expected character \cy%s\c- at pos \cd%d\c-. Trying character: \cd%s\c-", nextChar, currentPosition, chr);
		if (chr ~== nextChar)
		{
			typedString.AppendFormat(nextChar);
			S_StartSound("TOD/hit", CHAN_AUTO);
			if (typedString == currentTextBox.stringToType)
			{
				EventHandler.SendNetworkEvent("TOD_FinishTyping", activeTextBoxes.Find(currentTextBox), imperfect);
				S_StartSound("TOD/finishtyping", CHAN_AUTO);
				currentTextBox = null;
				currentPosition = -1;
				typedString = "";
			}
			return true;
		}
		// spaces don't count as either right or wrong:
		if (chr != " ")
		{
			EventHandler.SendNetworkEvent("TOD_WrongCharacter");
			S_StartSound("TOD/wrong", CHAN_AUTO);
			displayCharacterTics = TICRATE;
			displayCharacter = chr;
			imperfect = true;
		}
		currentPosition--;
		return false;
	}

	override void UiTick()
	{
		if (displayCharacterTics)
		{
			displayCharacterTics--;
			if (displayCharacterTics == 0)
			{
				displayCharacter = "";
			}
		}

		if (isPlayerTyping && currentTextBox && (!currentTextBox.IsActive() || !currentTextBox.projection || !currentTextBox.projection.IsInScreen()))
		{
			currentTextBox = null;
			typedString = "";
		}
	}

	override void WorldTick()
	{
		if (activeTextBoxes.Size() <= 0)
		{
			ToggleTyping(false);
		}
		if (typeDelayTics)
		{
			typeDelayTics--;
		}

		monstersFiredThisTic.Clear();

		//Console.MidPrint(smallfont, String.Format("active textboxes: \cd%d\c-", activeTextBoxes.Size()));
	}

	ui void DrawTextBox(TOD_TextBox tbox, Vector2 resolution, double ticFrac, bool isCurrent = false)
	{
		let mo = tbox.subject;
		if (!mo) return;
		projection.ProjectActorPosPortal(mo, (0, 0, mo.height*0.5), ticFrac);

		if (!projection.IsInFront())
		{
			//EventHandler.SendNetworkEvent("TOD_Deactivate", activeTextBoxes.Find(tbox));
			return;
		}

		viewport.FromHUD();
		Vector2 pos = viewport.SceneToCustom(projection.ProjectToNormal(), resolution);

		// Size of the box and indentation:
		Vector2 size = (280, 64);

		double indent = 8;
		// Change size and position based on current string width:
		size.x = typeFont.StringWidth(tbox.stringToType) + indent*2;
		pos.x -= size.x*0.5;
		if (!isCurrent)
		{
			size.y *= 0.5;
			//pos.y += 32;
		}

		// Screen.Dim doesn't have DTA flags, so we need VirtualToRealCoords
		// handleaspect is false because we've already handled it above

		// border
		Vector2 border = (5, 5);
		if (isCurrent)
		{
			border = (9, 9);
		}
		Vector2 dimPos, dimSize;
		/*if (isCurrent)
		{
			[dimPos, dimSize] = Screen.VirtualToRealCoords(pos - border, size + border*2, resolution, handleaspect:false);
			Screen.Dim(0xff00ff, 1.0, dimPos.x, dimPos.y, dimSize.x, dimSize.y);
		}*/
		border = (3, 3);
		[dimPos, dimSize] = Screen.VirtualToRealCoords(pos - border, size + border*2, resolution, handleaspect:false);
		Screen.Dim(0x80AA60, 1.0, dimPos.x, dimPos.y, dimSize.x, dimSize.y);

		double pulseFreq = TOD_Utils.LinearMap(tbox.typeTics, 0, tbox.startTypeTime, TICRATE*0.25, TICRATE*2);
		double alpha = 0.5 + 0.5 * sin(360.0 * level.time / pulseFreq);
		alpha *= TOD_Utils.LinearMap(tbox.typeTics, 0, tbox.startTypeTime, 1.0, 0.0);
		Screen.Dim(0xFF0000, alpha, dimPos.x, dimPos.y, dimSize.x, dimSize.y);

		// inner black area
		[dimPos, dimSize] = Screen.VirtualToRealCoords(pos, size, resolution, handleaspect:false);
		color col = isCurrent? 0x000030 : 0x101010;
		Screen.Dim(col, 1.0, dimPos.x, dimPos.y, dimSize.x, dimSize.y);
		
		// String to type (top):
		pos += (indent, 10);
		Screen.DrawText(typeFont,
			Font.CR_Yellow,
			pos.x,
			pos.y,
			tbox.stringToType,
			DTA_VirtualWidthF, resolution.x,
			DTA_VirtualHeightF, resolution.y,
			DTA_KeepRatio, true);

		if (isCurrent)
		{
			// String typed so far (below):
			pos.y += 32;
			Screen.DrawText(typeFont,
				Font.CR_White,
				pos.x,
				pos.y,
				typedString,
				DTA_VirtualWidthF, resolution.x,
				DTA_VirtualHeightF, resolution.y,
				DTA_KeepRatio, true);

			// Blinking text cursor:
			pos.x += typeFont.StringWidth(typedString);
			Screen.DrawText(typeFont,
				Font.CR_White,
				pos.x,
				pos.y,
				"_",
				DTA_VirtualWidthF, resolution.x,
				DTA_VirtualHeightF, resolution.y,
				DTA_KeepRatio, true,
				DTA_Alpha, 0.5 + 0.5 * sin(360.0 * level.time / (TICRATE*0.5)));

			// Wrong character typed (red, fading out and sliding down):
			if (displayCharacterTics)
			{
				pos.y += TOD_Utils.LinearMap(displayCharacterTics, 1, TICRATE, 8, 0);
				Screen.DrawText(typeFont,
					Font.CR_Red,
					pos.x,
					pos.y,
					displayCharacter,
					DTA_VirtualWidthF, resolution.x,
					DTA_VirtualHeightF, resolution.y,
					DTA_KeepRatio, true,
					DTA_Alpha, displayCharacterTics / double(TICRATE));
			}

			if (!textBoxMarker)
			{
				textBoxMarker = new('Shape2D');
				markerTransform = new('Shape2DTransform');
				textBoxMarker.PushVertex((0.15, 0.15));
				textBoxMarker.PushVertex((-0.5, -0.1));
				textBoxMarker.PushVertex((-0.2, -0.2));
				textBoxMarker.PushVertex((-0.1, -0.5));
				for (int i = 0; i < 4; i++)
				{
					textBoxMarker.PushCoord((0,0));
				}
				textBoxMarker.PushTriangle(0,1,2);
				textBoxMarker.PushTriangle(0, 1, 2);
				textBoxMarker.PushTriangle(2, 3, 0);
			}

			let markerPos = dimPos;
			let markerArea = dimSize;
			let hudscale = statusbar.GetHudScale();
			for (int i = 0; i < 4; i++)
			{
				markerTransform.Clear();
				markerTransform.Scale(hudscale * 15);
				markerTransform.Rotate(90 * i);
				switch (i)
				{
				default:
					markerTransform.Translate(markerPos);
					break;
				case 1:
					markerTransform.Translate((markerPos.x + markerArea.x, markerPos.y));
					break;
				case 2:
					markerTransform.Translate((markerPos.x + markerArea.x, markerPos.y + markerArea.y));
					break;
				case 3:
					markerTransform.Translate((markerPos.x, markerPos.y + markerArea.y));
					break;
				}
				textBoxMarker.SetTransform(markerTransform);
				Screen.DrawShapeFill(0x0000cc, 1.0, textBoxMarker);
			}
		}
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (activeTextBoxes.Size() <= 0) return;

		if (!projection) return;
	
		Vector2 resolution = 480 * (Screen.GetAspectRatio(), 1);

		projection.CacheCustomResolution(resolution);
		projection.CacheFov(players[consoleplayer].fov);
		projection.OrientForRenderOverlay(e);
		projection.BeginProjection();

		if (!typeFont)
		{
			typeFont = Font.FindFont('NewConsoleFont');
		}

		foreach (tbox : activeTextBoxes)
		{
			if (tbox && tbox != currentTextBox)
			{
				DrawTextBox(tbox, resolution, e.fractic, false);
			}
		}

		if (currentTextBox)
		{
			DrawTextBox(currentTextBox, resolution, e.fractic, true);
		}
	}

	override void WorldLoaded(WorldEvent e)
	{
		ToggleTyping(false);
	}

	override void WorldThingSpawned(WorldEvent e)
	{
		if (e.thing.bIsMonster && !e.thing.bFriendly && e.thing.bShootable)
		{
			TOD_TextBox.Attach(players[0].mo, e.thing);
		}

		else if (e.thing.bMissile && (!e.thing.target || !e.thing.target.player))
		{
			TOD_ProjectileTextBox.Attach(players[0].mo, e.thing);
		}

		/*else if (e.thing is 'Blood' || e.thing.bIsPuff || e.thing is 'BulletPuff')
		{
			e.thing.bNoTimeFreeze = true;
		}*/

		else if (e.thing is 'Health')
		{
			e.thing.Destroy();
		}
	}

	override void WorldThingRevived(WorldEvent e)
	{
		if (e.thing.bIsMonster && !e.thing.bFriendly && e.thing.bShootable)
		{
			TOD_TextBox.Attach(players[0].mo, e.thing);
		}
	}

	// used for testing:
	static const class<Actor> DoomMonsters[] =
	{
		'Arachnotron',             // Arachnotron
		'Archvile',                // Arch-vile
		'BaronOfHell',             // Baron of Hell
		'HellKnight',              // Hell knight
		'Cacodemon',               // Cacodemon
		'Cyberdemon',              // Cyberdemon
		'Demon',                   // Demon
		'Spectre',                 // Partially invisible demon
		'ChaingunGuy',             // Former human commando
		'DoomImp',                 // Imp
		'Fatso',                   // Mancubus
		'LostSoul',                // Lost soul
		'PainElemental',           // Pain elemental
		'Revenant',                // Revenant
		'ShotgunGuy',              // Former human sergeant
		'SpiderMastermind',        // Spider mastermind
		'WolfensteinSS',           // Wolfenstein soldier
		'ZombieMan'
	};
}

class TOD_HitscanProjectile : Actor
{
	Default
	{
		Projectile;
		Speed 10;
		Renderstyle 'Stencil';
		Stencilcolor "FFAA00";
		+BRIGHT
		//+NOTIMEFREEZE
		Scale 0.25;
		DamageFunction 1;
		Radius 4;
		Height 4;
	}

	States {
	Spawn:
		AMRK A -1;
		stop;
	Death:
		TNT1 A 1;
		stop;
	}
}