class TOD_Handler : EventHandler
{
	array<TOD_TextBox> allTextBoxes;
	array<TOD_TextBox> activeTextBoxes;
	TOD_Le_GlScreen projection;
	TOD_Le_Viewport viewport;

	bool isPlayerTyping;
	int typeDelayTics;
	const TYPEDELAY = TICRATE / 2;

	ui TOD_TextBox currentTextBox;
	ui Font typeFont;
	ui Font headerFont;
	ui int currentPosition;
	ui String typedString;
	ui uint displayCharacterTics;
	ui String displayCharacter;
	ui bool imperfect;
	ui int headerStringOffset;
	ui int headerStringMax;
	const HEADERTEXT = "Type to survive! Type to survive! Type to survive! Type to survive! Type to survive! Type to survive! Type to survive! Type to survive!";
	ui int headerTextWidth;

	override void OnRegister()
	{
		projection = New("TOD_Le_GlScreen");
	}

	override bool InputProcess (InputEvent e)
	{
		if (e.type == InputEvent.Type_KeyDown && !isPlayerTyping)
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
	}

	override void InterfaceProcess (ConsoleEvent e)
	{
		if (e.name ~== "TOD_FocusTextbox")
		{
			currentTextBox = activeTextBoxes[e.args[0]];
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
			level.SetFrozen(false);
			return;
		}

		if (!isPlayerTyping)
		{
			isPlayerTyping = true;
			isUiProcessor = true;
			players[0].mo.A_Stop();
			players[0].mo.A_AlertMonsters(1024);
			level.SetFrozen(true);
			typeDelayTics = TYPEDELAY;
		}
	}

	ui bool TypeCharacter(String chr)
	{
		if (!chr) return false;

		chr = TOD_Utils.CleanQuotes(chr);
		chr = TOD_Utils.CleanDashes(chr);

		if (!currentTextBox)
		{
			for (int i = 0; i < activeTextBoxes.Size();  i++)
			{
				if (activeTextBoxes[i] && activeTextBoxes[i].firstCharacter ~== chr)
				{
					currentTextBox = activeTextBoxes[i];
					break;
				}
			}
		}
		if (!currentTextBox)
		{
			return false;
		}
		if (!typedString)
		{
			currentPosition = -1;
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
		// spaces don't count but also don't produce the 'wrong' sound:
		if (chr != " ")
		{
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

		if (isPlayerTyping)
		{
			if ((headerStringOffset += 4) > headerStringMax) headerStringOffset = 0;
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

		//Console.MidPrint(smallfont, String.Format("active textboxes: \cd%d\c-", activeTextBoxes.Size()));
	}

	override void WorldLoaded(WorldEvent e)
	{
		ToggleTyping(false);
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
			pos.y += 32;
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
		Screen.Dim(0xCCFF60, 1.0, dimPos.x, dimPos.y, dimSize.x, dimSize.y);

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
		}
	}

	ui void DrawHeaders(Vector2 res = (640, 480))
	{
		Vector2 resolution = res.y * (Screen.GetAspectRatio(), 1);

		if (!headerFont)
		{
			headerFont = Font.FindFont('BigUpper');
		}
		if (!headerTextWidth)
		{
			headerTextWidth = headerFont.StringWidth(HEADERTEXT);
			headerStringMax = resolution.x / 2;
		}
		
		Vector2 vSize = (resolution.x, 30);
		Vector2 pos1, pos2, size;
		[pos1, size] = Screen.VirtualToRealCoords((0,0), vSize, resolution, handleaspect:false);
		pos2 = Screen.VirtualToRealCoords((0, resolution.y - vSize.y), vSize, resolution, handleaspect:false);
		
		Screen.Dim(0x000000, 0.8, pos1.x, pos1.y, size.x, size.y);
		Screen.Dim(0x000000, 0.8, pos2.x, pos2.y, size.x, size.y);

		double alpha = 0.5 + 0.5 * sin(360.0 * level.time / TICRATE);
		for (int i = 0; i < 4; i++)
		{
			double xofs = (i < 2)? headerStringOffset : -headerStringOffset;
			Screen.DrawText(headerFont, 
				Font.CR_Orange, 
				(i == 0 || i == 2)? xofs : xofs - headerTextWidth,
				(i < 2)? 4 : resolution.y - vSize.y*0.7,
				HEADERTEXT,
				DTA_VirtualWidthF, res.x,
				DTA_VirtualHeightF, res.y);
			Screen.DrawText(headerFont, 
				Font.CR_White, 
				(i == 0 || i == 2)? xofs : xofs - headerTextWidth,
				(i < 2)? 4 : resolution.y - vSize.y*0.7,
				HEADERTEXT,
				DTA_VirtualWidthF, res.x,
				DTA_VirtualHeightF, res.y,
				DTA_Alpha, alpha);
		}

		if (typeDelayTics)
		{
			double alpha = 0.5 + -0.5 * sin(360.0 * typeDelayTics / (TYPEDELAY));
			Screen.Dim(0xffffff, alpha, pos1.x, pos1.y, size.x, size.y);
			Screen.Dim(0xffffff, alpha, pos2.x, pos2.y, size.x, size.y);
		}
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (activeTextBoxes.Size() <= 0) return;

		if (!projection) return;

		if (isPlayerTyping)
		{
			DrawHeaders();
		}
	
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
			if (tbox != currentTextBox)
			{
				DrawTextBox(tbox, resolution, e.fractic, false);
			}
		}

		if (currentTextBox)
		{
			DrawTextBox(currentTextBox, resolution, e.fractic, true);
		}
	}

	override void WorldThingSpawned(WorldEvent e)
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