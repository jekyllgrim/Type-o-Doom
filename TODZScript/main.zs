class TOD_StringToType : Thinker
{
	PlayerPawn ppawn;
	int playerNumber;
	Actor subject;
	String stringToType;
	uint stringToTypeLength;
	String typedString;
	int currentPosition;
	String displayCharacter;
	uint displayCharacterTime;
	uint turnTics;
	double angleTurnStep;
	double pitchTurnStep;

	bool PickString()
	{
		array<String> listToUse;
		let handler = TOD_StaticInfo(StaticEventHandler.Find('TOD_StaticInfo'));
		if (!handler) return false;

		if (subject.health <= 80)
			listToUse.Copy(handler.words_1short);
		else if (subject.health <= 200)
			listToUse.Copy(handler.words_1word);
		else if (subject.health <= 300)
			listToUse.Copy(handler.words_2words);
		else if (subject.health <= 500)
			listToUse.Copy(handler.words_3words);
		else if (subject.health <= 1000)
			listToUse.Copy(handler.words_4words);
		else
			listToUse.Copy(handler.words_sentences);
		
		if (listToUse.Size() < 1)
		{
			return false;
		}
		
		stringToType = listToUse[random[pickstr](0, listToUse.Size()-1)];
		stringToTypeLength = stringToType.Length();
		currentPosition = -1;
		return true;
	}

	static TOD_StringToType Attach(PlayerPawn ppawn, Actor subject, bool setCurrent = false)
	{
		if (!ppawn || !ppawn.player || !ppawn.player.mo || ppawn.player.mo != ppawn || !subject || subject.health <= 0) return null;

		let handler = TOD_Handler(EventHandler.Find('TOD_Handler'));
		if (!handler) return null;

		let msg = New('TOD_StringToType');
		msg.ppawn = ppawn;
		msg.playerNumber = ppawn.PlayerNumber();
		msg.subject = subject;
		if (!msg.PickString())
		{
			msg.Destroy();
			return null;
		}

		Vector3 view = level.SphericalCoords((ppawn.pos.xy, ppawn.player.viewz), subject.pos + (0, 0, subject.height*0.5), (ppawn.angle, ppawn.pitch));
		if (abs(view.x) > 45 || abs(view.y) > 15)
		{
			double maxViewDist = max(abs(view.x), abs(view.y));
			msg.turnTics = int(round(ToD_Utils.LinearMap(maxViewDist, 45, 180, TICRATE*0.5, TICRATE)));
			msg.angleTurnStep = -view.x / msg.turnTics;
			msg.pitchTurnStep = -view.y / msg.turnTics;
		}

		handler.allTextBoxes.Push(msg);
		handler.isUiProcessor = true;
		if (setCurrent)
		{
			level.SetFrozen(true);
			handler.currentTextBox = msg;
		}
		return msg;
	}

	bool AddCharacter(String chr)
	{
		if (!chr) return false;

		currentPosition++;
		String nextChar = stringToType.CharAt(currentPosition);
		while (nextChar == " ")
		{
			currentPosition++;
			typedString.AppendFormat(" ");
			nextChar = stringToType.CharAt(currentPosition);
		}
		Console.Printf("Expected character: \cy%s\c-. Trying character: \cd%s\c-", nextChar, chr);
		if (chr ~== nextChar)
		{
			typedString.AppendFormat(nextChar);
			S_StartSound("tod/hit", CHAN_AUTO);
			if (typedString == stringToType)
			{
				FinishTyping();
			}
			return true;
		}
		if (chr != " ")
		{
			S_StartSound("tod/wrong", CHAN_AUTO);
			displayCharacterTime = TICRATE;
			displayCharacter = chr;
		}
		currentPosition--;
		return false;
	}

	void FinishTyping()
	{
		level.SetFrozen(false);
		if (subject && ppawn)
		{
			subject.DamageMobj(ppawn, ppawn, subject.health, 'Normal', DMG_FORCED|DMG_NO_PROTECT|DMG_NO_ENHANCE);
		}
		let handler = TOD_Handler(EventHandler.Find('TOD_Handler'));
		if (handler)
		{
			handler.isUiProcessor = false;
		}
		S_StartSound("tod/finishtyping", CHAN_AUTO);
		Destroy();
	}

	override void Tick()
	{
		Super.Tick();
		if (displayCharacterTime)
		{
			displayCharacterTime--;
			if (displayCharacterTime == 0)
			{
				displayCharacter = "";
			}
		}

		if (turnTics)
		{
			ppawn.A_SetAngle(ppawn.angle + angleTurnStep, SPF_INTERPOLATE);
			ppawn.A_SetPitch(ppawn.pitch + pitchTurnStep, SPF_INTERPOLATE);
			turnTics--;
		}
	}
}

class TOD_Player : DoomPlayer
{
	Default
	{
		Health 10;
	}

	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (flags & DMG_EXPLOSION)
		{
			return 0;
		}
		return min(damage, 1);
	}
}

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
		ParseGlossary("words_1short", words_1short);
		ParseGlossary("words_1word", words_1word);
		ParseGlossary("words_2words", words_2words);
		ParseGlossary("words_3words", words_3words);
		ParseGlossary("words_4words", words_4words);
		ParseGlossary("words_sentences", words_sentences);

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
			RemoveComments(lumpdata);
			CleanWhiteSpace(lumpdata);
			int fileEnd = lumpdata.Length();
			int searchpos = 0;
			while (searchPos >= 0 && searchPos < fileEnd)
			{
				int lineEnd = lumpdata.IndexOf("\n", searchPos);
				if (lineEnd < 0)
				{
					lineEnd = fileEnd + 1;
				}
				String textline = lumpdata.Mid(searchPos, lineEnd - searchPos - 1);
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

	static String RemoveComments(string stringToType)
	{
		int commentPos = stringToType.IndexOf("//");
		while (commentpos >= 0)
		{
			int lineEnd = stringToType.IndexOf("\n", commentPos) - 1;
			stringToType.Remove(commentPos, lineEnd - commentPos);
			commentPos = stringToType.IndexOf("//");
		}
		commentPos = stringToType.IndexOf("/*");
		while (commentpos >= 0)
		{
			int lineEnd = stringToType.IndexOf("*/", commentPos) - 1;
			stringToType.Remove(commentPos, lineEnd - commentPos);
			commentPos = stringToType.IndexOf("/*");
		}
		return stringToType;
	}

	static String CleanWhiteSpace(string workstring, bool removeSpaces = false)
	{
		// Strip tabs, carraige returns, "clearlocks",
		// add linebreaks before "{" and "}":
		workstring.Replace("\t", "");
		workstring.Replace("\r", "");
		// Unite duplicate linebreaks, if any:
		while (workstring.IndexOf("\n\n") >= 0)
		{
			workstring.Replace("\n\n", "\n");
		}
		// Remove all spaces, if removeSpaces is true:
		if (removeSpaces)
		{
			workstring.Replace(" ", "");
		}
		// Otherwise clean spaces:
		else
		{
			// Unite duplicate spaces, if any:
			while (workstring.IndexOf("  ") >= 0)
			{
				workstring.Replace("  ", " ");
			}
			// Remove spaces next to linebreaks:
			workstring.Replace("\n ", "\n");
			workstring.Replace(" \n", "\n");
		}
		return workstring;
	}
}

class TOD_Handler : EventHandler
{
	array<TOD_StringToType> allTextBoxes;
	TOD_StringToType currentTextBox;

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

	override void NetworkProcess (ConsoleEvent e)
	{
		Console.Printf("Calling netevent \cd%s\c-", e.name);
		if (e.name.IndexOf("TOD_AddCharacter") >= 0)
		{
			if (!currentTextBox) return;
			array<String> str;
			e.name.Split(str, "||");
			if (str.Size() != 2) return;
			currentTextBox.AddCharacter(str[1]);
		}

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

			let stt = TOD_StringToType.Attach(ppawn, victim, true);
			if (!stt && victim)
			{
				victim.Destroy();
			}
		}
	}

	ui HUDFont typeFont;
	override void RenderOverlay(RenderEvent e)
	{
		if (!currentTextBox) return;

		statusbar.BeginHUD(1.0, true, 640, 480);
		if (!typeFont)
		{
			typeFont = HudFont.Create(Font.FindFont('NewConsoleFont'));
		}

		int flags = StatusBarCore.DI_SCREEN_CENTER;
		Vector2 size = (280, 64);
		double indent = 8;
		size.x = typeFont.mFont.StringWidth(currentTextBox.stringToType) + indent*2;
		Vector2 pos = size * -0.5;
		statusbar.Fill(0xCC000000, pos.x, pos.y, size.x, size.y, flags);
		pos +=  (indent, 10);
		statusbar.DrawString(typeFont, currentTextBox.stringToType, pos, flags, Font.CR_White);
		pos.y += 32;
		statusbar.DrawString(typeFont, currentTextBox.typedString, pos, flags, Font.CR_Yellow);
		pos.x += typeFont.mFont.StringWidth(currentTextBox.typedString);
		statusbar.DrawSTring(typefont, "_", pos, flags, Font.CR_Yellow, alpha: 0.5 + 0.5 * sin(360.0 * level.time / (TICRATE*0.5)));
		if (currentTextBox.displayCharacterTime)
		{
			statusbar.DrawSTring(typefont, currentTextBox.displayCharacter, pos, flags, Font.CR_Red, alpha: double(currentTextBox.displayCharacterTime) / TICRATE);
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
}

class ToD_Utils
{
	static clearscope double LinearMap(double val, double source_min, double source_max, double out_min, double out_max, bool clampit = false) 
	{
		double sourceDiff = source_max - source_min;
		if (sourceDiff == 0)
		{
			return 0;
		}
		double d = (val - source_min) * (out_max - out_min) / sourceDiff + out_min;
		if (clampit)
		{
			double truemax = out_max > out_min ? out_max : out_min;
			double truemin = out_max > out_min ? out_min : out_max;
			d = Clamp(d, truemin, truemax);
		}
		return d;
	}
}