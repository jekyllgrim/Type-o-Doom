class TOD_Handler : EventHandler
{
	array<TOD_TextBox> allTextBoxes;
	array<TOD_TextBox> activeTextBoxes;
	TOD_Le_GlScreen projection;
	TOD_Le_Viewport viewport;

	bool isPlayerTyping;

	ui TOD_TextBox currentTextBox;
	ui Font typeFont;
	ui int currentPosition;
	ui String typedString;
	ui uint displayCharacterTics;
	ui String displayCharacter;
	ui bool imperfect;

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

		if (e.Type == UiEvent.Type_Char)
		{
			String chr = String.Format("%c", e.keyChar);
			if (!chr) return false;
			//Console.Printf("UiProcess captured character \cd%s\c-", chr);
			AddCharacter(chr);
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

		isPlayerTyping = true;
		isUiProcessor = true;
		players[0].mo.A_Stop();
		level.SetFrozen(true);
	}

	ui bool AddCharacter(String chr)
	{
		if (!chr) return false;

		chr = TOD_Utils.CleanQuotes(chr);
		chr = TOD_Utils.CleanDashes(chr);

		if (!currentTextBox)
		{
			foreach (tbox : activeTextBoxes)
			{
				if (tbox && tbox.firstCharacter ~== chr)
				{
					currentTextBox = tbox;
					currentPosition = -1;
					typedString = "";
					break;
				}
			}
		}
		if (!currentTextBox)
		{
			return false;
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
				currentTextBox = null;
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
	}

	override void WorldLoaded(WorldEvent e)
	{
		ToggleTyping(false);
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (activeTextBoxes.Size() <= 0) return;

		if (!projection) return;
	
		let window_aspect = 1.0 * Screen.GetWidth() / Screen.GetHeight();
		let resolution = 480 * (window_aspect, 1);
		let t = e.fractic;

		projection.CacheCustomResolution(resolution);
		projection.CacheFov(players[consoleplayer].fov);
		projection.OrientForRenderOverlay(e);
		projection.BeginProjection();

		foreach (tbox : activeTextBoxes)
		{
			let mo = tbox.subject;
			if (!mo) return;
			projection.ProjectActorPosPortal(mo, (0, 0, mo.height*0.5), t);

			if (!projection.IsInFront()) return;

			viewport.FromHUD();
			Vector2 pos = viewport.SceneToCustom(projection.ProjectToNormal(), resolution);
			if (!typeFont)
			{
				typeFont = Font.FindFont('NewConsoleFont');
			}

			// Size of the box and indentation:
			Vector2 size = (280, 64);
			double indent = 8;
			// Change size and position based on current string width:
			size.x = typeFont.StringWidth(tbox.stringToType) + indent*2;
			pos.x -= size.x*0.5;

			bool isCurrent = tbox == currentTextBox;

			// Screen.Dim doesn't have DTA flags, so we need VirtualToRealCoords
			// handleaspect is false because we've already handled it above

			// border
			Vector2 border = (3, 3);
			let [dimPos, dimSize] = Screen.VirtualToRealCoords(pos - border, size + border*2, resolution, handleaspect:false);
			double alpha = 1.0;
			if (!isCurrent) alpha *= 0.75;
			Screen.Dim(0xCCFF60, alpha, dimPos.x, dimPos.y, dimSize.x, dimSize.y);

			double pulseFreq = TOD_Utils.LinearMap(tbox.typeTics, 0, tbox.startTypeTime, TICRATE*0.25, TICRATE*2);
			double amt = 0.5 + 0.5 * sin(360.0 * level.time / pulseFreq);
			alpha *= TOD_Utils.LinearMap(tbox.typeTics, 0, tbox.startTypeTime, 1.0, 0.0);
			if (!isCurrent) alpha *= 0.75;
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