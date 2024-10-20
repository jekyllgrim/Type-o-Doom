class TOD_StaticInfo : StaticEventHandler
{
	array<String> words_1short;
	array<String> words_1word;
	array<String> words_2words;
	array<String> words_3words;
	array<String> words_4words;
	array<String> words_sentences;

	override void OnRegister()
	{
		ParseGlossary("TODG_sh", words_1short);
		ParseGlossary("TODG_1w", words_1word);
		ParseGlossary("TODG_2w", words_2words);
		ParseGlossary("TODG_3w", words_3words);
		ParseGlossary("TODG_4w", words_4words);
		ParseGlossary("TODG_sen", words_sentences);

		/*String info = String.Format("Short words (\cy%d\c-): ", words_1short.Size());
		foreach (str : words_1short)
		{
			info.AppendFormat("\cd%s\c-,", str);
		}
		Console.Printf(info);

		info = String.Format("Words (\cy%d\c-): ", words_1word.Size());
		foreach (str : words_1word)
		{
			info.AppendFormat("\cd%s\c-,", str);
		}
		Console.Printf(info);

		info = String.Format("2-word groups (\cy%d\c-): ", words_2words.Size());
		foreach (str : words_2words)
		{
			info.AppendFormat("\cd%s\c-,", str);
		}
		Console.Printf(info);
		
		info = String.Format("3-word groups (\cy%d\c-): ", words_3words.Size());
		foreach (str : words_3words)
		{
			info.AppendFormat("\cd%s\c-,", str);
		}
		Console.Printf(info);
		
		info = String.Format("4-word groups (\cy%d\c-): ", words_4words.Size());
		foreach (str : words_4words)
		{
			info.AppendFormat("\cd%s\c-,", str);
		}
		Console.Printf(info);
		
		info = String.Format("Sentences (\cy%d\c-): ", words_sentences.Size());
		foreach (str : words_sentences)
		{
			info.AppendFormat("\cd%s\c-,", str);
		}
		Console.Printf(info);*/
	}

	void ParseGlossary(String glossaryName, out array<String> stringList)
	{
		int lump = Wads.FindLump(glossaryName, 0);
		if (lump < 0)
		{
			Console.Printf("\cgTOD error: glossary \cd%s\cg not found", glossaryName);
		}
		while (lump != -1)
		{
			String lumpdata = Wads.ReadLump(lump);
			lumpdata = TOD_Utils.RemoveComments(lumpdata);
			lumpdata = TOD_Utils.CleanWhiteSpace(lumpdata);
			lumpdata = TOD_Utils.CleanQuotes(lumpdata);
			int fileEnd = lumpdata.Length();
			int searchpos = 0;
			while (searchPos >= 0 && searchPos < fileEnd)
			{
				int lineEnd = lumpdata.IndexOf("\n", searchPos);
				if (lineEnd < 0)
				{
					lineEnd = fileEnd;
				}
				String textline = lumpdata.Mid(searchPos, lineEnd - searchPos);
				if (!textline)
				{
					break;
				}
				stringList.Push(textline);
				searchPos = lineEnd + 1;
			}
			lump = Wads.FindLump(glossaryName, lump + 1);
		}
		if (stringList.Size() == 0)
		{
			Console.Printf("\cgTOD error: No words parsed from glossary \cd%s", glossaryName);
		}
	}
}

class TOD_Handler : EventHandler
{
	array<TOD_TextBox> allTextBoxes;
	TOD_TextBox currentTextBox;
	//ui HUDFont typeFont;
	ui Font typeFont;
	protected TOD_Le_GlScreen gl_proj;
	protected TOD_Le_Viewport viewport;

	override void OnRegister()
	{
		gl_proj = New("TOD_Le_GlScreen");
	}

	override void NetworkProcess (ConsoleEvent e)
	{
		if (e.name.IndexOf("TOD_AddCharacter") >= 0)
		{
			if (!currentTextBox) return;
			array<String> str;
			e.name.Split(str, "||");
			if (str.Size() != 2) return;
			currentTextBox.AddCharacter(str[1]);
		}

		// test event that spawns a random monster:
		if (!currentTextBox && e.name ~== "TOD_Test")
		{
			array<String> str;
			e.name.Split(str, "||");
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
			else
			{
				stt.Activate(true);
			}
		}
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (!currentTextBox || !currentTextBox.isActive()) return;

		if (!gl_proj) return;
	
		let window_aspect = 1.0 * Screen.GetWidth() / Screen.GetHeight();
		let resolution = 480 * (window_aspect, 1);
		let t = e.fractic;
		let mo = currentTextBox.subject;

		gl_proj.CacheCustomResolution(resolution);
		gl_proj.CacheFov(players[consoleplayer].fov);
		gl_proj.OrientForRenderOverlay(e);
		gl_proj.BeginProjection();
		gl_proj.ProjectActorPosPortal(mo, (0, 0, mo.height*0.2), t);

		if (!gl_proj.IsInFront()) return;

		viewport.FromHUD();
		Vector2 pos = viewport.SceneToCustom(gl_proj.ProjectToNormal(), resolution);
		if (!typeFont)
		{
			typeFont = Font.FindFont('NewConsoleFont');
		}

		// Size of the box and indentation:
		Vector2 size = (280, 64);
		double indent = 8;
		// Change size and position based on current string width:
		size.x = typeFont.StringWidth(currentTextBox.stringToType) + indent*2;
		pos += size * -0.5;

		// Why doesn't Screen.Dim have DTA flags? Well, we need to scale it to
		// our virtual resolution too (handleaspect is false because we've
		// already handled it above):
		let [dimPos, dimSize] = Screen.VirtualToRealCoords(pos, size, resolution, handleaspect:false);
		Screen.Dim(0x000000, 0.85, dimPos.x, dimPos.y, dimSize.x, dimSize.y);
		
		// String to type (top):
		pos += (indent, 10);
		Screen.DrawText(typeFont,
			Font.CR_Yellow,
			pos.x,
			pos.y,
			currentTextBox.stringToType,
			DTA_VirtualWidthF, resolution.x,
			DTA_VirtualHeightF, resolution.y,
			DTA_KeepRatio, true);

		// String typed so far (below):
		pos.y += 32;
		Screen.DrawText(typeFont,
			Font.CR_White,
			pos.x,
			pos.y,
			currentTextBox.typedString,
			DTA_VirtualWidthF, resolution.x,
			DTA_VirtualHeightF, resolution.y,
			DTA_KeepRatio, true);

		// Blinking text cursor:
		pos.x += typeFont.StringWidth(currentTextBox.typedString);
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
		if (currentTextBox.displayCharacterTime)
		{
			pos.y += TOD_Utils.LinearMap(currentTextBox.displayCharacterTime, 1, TICRATE, 8, 0);
			Screen.DrawText(typeFont,
				Font.CR_Red,
				pos.x,
				pos.y,
				currentTextBox.displayCharacter,
				DTA_VirtualWidthF, resolution.x,
				DTA_VirtualHeightF, resolution.y,
				DTA_KeepRatio, true,
				DTA_Alpha, currentTextBox.displayCharacterTime / double(TICRATE));
		}
	}

	override bool UiProcess(UiEvent e)
	{
		if (!currentTextBox) return false;

		if (e.KeyChar == UiEvent.Key_ESCAPE) return false;

		if (e.Type == UiEvent.Type_Char)
		{
			String chr = String.Format("%c", e.keyChar);
			Console.Printf("UiProcess captured character \cd%s\c-", chr);
			EventHandler.SendNetworkEvent(String.Format("TOD_AddCharacter||%s", chr));
			return true;
		}

		return false;
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