class TOD_StringToType : Thinker
{
	PlayerPawn ppawn;
	int playerNumber;
	Actor subject;
	String stringToTypeNow;
	uint stringToTypeLength;
	String typedString;
	int currentPosition;
	String displayCharacter;
	uint displayCharacterTime;
	uint turnTics;
	double angleTurnStep;
	double pitchTurnStep;

	static TOD_StringToType Attach(PlayerPawn ppawn, Actor subject, String stringToTypeNow, bool setCurrent = false)
	{
		if (!ppawn || !ppawn.player || !ppawn.player.mo || ppawn.player.mo != ppawn || !subject || subject.health <= 0) return null;

		let handler = TOD_Handler(EventHandler.Find('TOD_Handler'));
		if (!handler) return null;

		let msg = New('TOD_StringToType');
		msg.ppawn = ppawn;
		msg.subject = subject;
		msg.playerNumber = ppawn.PlayerNumber();
		msg.stringToTypeNow = stringToTypeNow;
		msg.stringToTypeLength = stringToTypeNow.Length();
		msg.currentPosition = -1;

		Vector3 view = level.SphericalCoords((ppawn.pos.xy, ppawn.player.viewz), subject.pos + (0, 0, subject.height*0.5), (ppawn.angle, ppawn.pitch));
		if (abs(view.x) > 45 || abs(view.y) > 15)
		{
			double maxViewDist = max(abs(view.x), abs(view.y));
			msg.turnTics = int(round(ToD_Utils.LinearMap(maxViewDist, 45, 180, TICRATE*0.5, TICRATE)));
			msg.angleTurnStep = -view.x / msg.turnTics;
			msg.pitchTurnStep = -view.y / msg.turnTics;
		}

		handler.type_list.Push(msg);
		handler.isUiProcessor = true;
		if (setCurrent)
		{
			level.SetFrozen(true);
			handler.stringToTypeNow = msg;
		}
		return msg;
	}

	bool AddCharacter(String chr)
	{
		if (!chr) return false;

		currentPosition++;
		String nextChar = stringToTypeNow.CharAt(currentPosition);
		while (nextChar == " ")
		{
			currentPosition++;
			typedString.AppendFormat(" ");
			nextChar = stringToTypeNow.CharAt(currentPosition);
		}
		Console.Printf("Expected character: \cy%s\c-. Trying character: \cd%s\c-", nextChar, chr);
		if (chr ~== nextChar)
		{
			typedString.AppendFormat(nextChar);
			S_StartSound("tod/hit", CHAN_AUTO);
			if (typedString == stringToTypeNow)
			{
				FinishTyping();
			}
			return true;
		}
		S_StartSound("tod/wrong", CHAN_AUTO);
		currentPosition--;
		displayCharacterTime = TICRATE;
		displayCharacter = chr;
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

class TOD_Handler : EventHandler
{
	array<TOD_StringToType> type_list;
	TOD_StringToType stringToTypeNow;

	override void NetworkProcess (ConsoleEvent e)
	{
		Console.Printf("Calling netevent \cd%s\c-", e.name);
		if (e.name.IndexOf("TOD_AddCharacter") >= 0)
		{
			if (!stringToTypeNow) return;
			array<String> str;
			e.name.Split(str, "||");
			if (str.Size() != 2) return;
			if (!stringToTypeNow.AddCharacter(str[1]))
			{
				S_StartSound("tod/wrong", CHAN_AUTO);
			}
		}

		if (!stringToTypeNow && e.name.IndexOf("TOD_Test") >= 0)
		{
			array<String> str;
			e.name.Split(str, "||");
			String toType;
			if (str.Size() > 2) 
			{
				Console.Printf("Invalid command. Expecting \cdTOD_Test||stringToTypeNow\c- got \cg%s\c-", e.name);
				return;
			}
			else if (str.Size() == 2)
			{
				toType = str[1];
			}
			else
			{
				toType = TestEnemyStrings[random(0, TestEnemyStrings.Size()-1)];
				toType = String.Format(toType, "Zombieman");
			}

			let ppawn = players[e.Player].mo;
			Vector2 ofs = Actor.RotateVector((192, 0), ppawn.angle + frandom(-90, 90));
			Vector3 spawnPos = ppawn.Vec3Offset(ofs.x, ofs.y, 0);
			let victim = Actor.Spawn('Zombieman', spawnPos);
			victim.A_Face(ppawn);

			TOD_StringToType.Attach(ppawn, victim, toType, true);
		}
	}

	ui HUDFont typeFont;
	override void RenderOverlay(RenderEvent e)
	{
		if (!stringToTypeNow) return;

		statusbar.BeginHUD(1.0, true, 640, 480);
		if (!typeFont)
		{
			typeFont = HudFont.Create(Font.FindFont('NewConsoleFont'));
		}

		int flags = StatusBarCore.DI_SCREEN_CENTER;
		Vector2 size = (280, 64);
		double indent = 8;
		size.x = typeFont.mFont.StringWidth(stringToTypeNow.stringToTypeNow) + indent*2;
		Vector2 pos = size * -0.5;
		statusbar.Fill(0xCC000000, pos.x, pos.y, size.x, size.y, flags);
		pos +=  (indent, 10);
		statusbar.DrawString(typeFont, stringToTypeNow.stringToTypeNow, pos, flags, Font.CR_White);
		pos.y += 32;
		statusbar.DrawString(typeFont, stringToTypeNow.typedString, pos, flags, Font.CR_Yellow);
		pos.x += typeFont.mFont.StringWidth(stringToTypeNow.typedString);
		statusbar.DrawSTring(typefont, "_", pos, flags, Font.CR_Yellow, alpha: 0.5 + 0.5 * sin(360.0 * level.time / (TICRATE*0.5)));
		if (stringToTypeNow.displayCharacterTime)
		{
			statusbar.DrawSTring(typefont, stringToTypeNow.displayCharacter, pos, flags, Font.CR_Red, alpha: double(stringToTypeNow.displayCharacterTime) / TICRATE);
		}
	}

	override bool UiProcess(UiEvent e)
	{
		if (!stringToTypeNow) return false;

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

	static const String TestEnemyStrings[] =
	{
		"Ha-ha! I'm a %s!",
		"Try and hit me!",
		"Monkey bar",
		"Stress test",
		"%s is the greatest!!",
		"You don't stand a chance",
		"Crazy Ben",
		"I like you",
		"I hate you",
		"No chance",
		"Get me",
		"Get this",
		"Analyze this",
		"Analyze that",
		"Sphinx of black quarts, judge my vow"
	};
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