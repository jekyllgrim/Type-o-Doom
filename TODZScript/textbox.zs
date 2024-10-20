class TOD_TextBox : Thinker
{
	TOD_Handler handler;
	PlayerPawn ppawn;
	int playerNumber;
	Actor subject;
	bool active;
	String stringToType;
	String firstCharacter;
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
		firstCharacter = stringToType.Left(1);
		stringToTypeLength = stringToType.Length();
		currentPosition = -1;
		return true;
	}

	void Activate(bool setCurrent = false)
	{
		PickString();

		Vector3 view = level.SphericalCoords((ppawn.pos.xy, ppawn.player.viewz), subject.pos + (0, 0, subject.height*0.5), (ppawn.angle, ppawn.pitch));
		if (abs(view.x) > 45 || abs(view.y) > 15)
		{
			double maxViewDist = max(abs(view.x), abs(view.y));
			turnTics = int(round(TOD_Utils.LinearMap(maxViewDist, 45, 180, TICRATE*0.5, TICRATE)));
			angleTurnStep = -view.x / turnTics;
			pitchTurnStep = -view.y / turnTics;
		}

		handler.allTextBoxes.Push(self);
		handler.isUiProcessor = true;
		if (setCurrent)
		{
			level.SetFrozen(true);
			handler.currentTextBox = self;
		}
	}

	static TOD_TextBox Attach(PlayerPawn ppawn, Actor subject)
	{
		if (!ppawn || !ppawn.player || !ppawn.player.mo || ppawn.player.mo != ppawn || !subject || subject.health <= 0) return null;

		let handler = TOD_Handler(EventHandler.Find('TOD_Handler'));
		if (!handler) return null;

		let msg = New('TOD_TextBox');
		msg.handler = handler;
		msg.ppawn = ppawn;
		msg.playerNumber = ppawn.PlayerNumber();
		msg.subject = subject;
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
			S_StartSound("TOD/hit", CHAN_AUTO);
			if (typedString == stringToType)
			{
				FinishTyping();
			}
			return true;
		}
		if (chr != " ")
		{
			S_StartSound("TOD/wrong", CHAN_AUTO);
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
		S_StartSound("TOD/finishtyping", CHAN_AUTO);
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