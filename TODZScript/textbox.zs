class TOD_TextBox : Thinker
{
	TOD_Handler handler;
	PlayerPawn ppawn;
	int playerNumber;
	Actor subject;
	State subjectAttackState;
	protected bool active;

	String stringToType;
	String firstCharacter;
	uint stringToTypeLength;
	uint turnTics;
	double angleTurnStep;
	double pitchTurnStep;

	int typeTics;
	uint startTypeTime;

	const AVGTYPEPERTIC = 3.5 / TICRATE;
	const REACTIONTICS = TICRATE * 3;

	clearscope bool isActive()
	{
		return active;
	}

	int GetStateSeqDuration(State atkst)
	{
		int tics;
		State st = atkst;
		array<State> cachedStates;
		while (st && Actor.InStateSequence(st, atkst))
		{
			tics += st.tics;
			cachedStates.Push(st);
			if (!st.nextstate || st.nextstate == st || cachedStates.Find(st.nextstate) != cachedStates.Size())
			{
				break;
			}
			st = st.nextstate;
		}
		return tics;
	}

	bool PickString()
	{
		if (stringToType) return true;

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
		startTypeTime = int(ceil(stringToTypeLength * AVGTYPEPERTIC)) + REACTIONTICS;
		typeTics = startTypeTime;
		return true;
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
		msg.PickString();
		handler.allTextBoxes.Push(msg);
		return msg;
	}

	void Activate(bool setCurrent = false)
	{
		if (!ppawn || !subject || subject.health <= 0 || !handler || !PickString())
		{
			Destroy();
			return;
		}

		active = true;

		if (handler.activeTextBoxes.Find(self) == handler.activeTextBoxes.Size())
		{
			handler.activeTextBoxes.Push(self);
		}

		if (setCurrent)
		{
			level.SetFrozen(true);
			ppawn.A_Stop();
			Vector3 view = level.SphericalCoords((ppawn.pos.xy, ppawn.player.viewz), subject.pos + (0, 0, subject.height*0.5), (ppawn.angle, ppawn.pitch));
			if (abs(view.x) > 45 || abs(view.y) > 15)
			{
				double maxViewDist = max(abs(view.x), abs(view.y));
				turnTics = int(round(TOD_Utils.LinearMap(maxViewDist, 45, 180, TICRATE*0.5, TICRATE)));
				angleTurnStep = -view.x / turnTics;
				pitchTurnStep = -view.y / turnTics;
			}
			handler.isUiProcessor = true;
			if (handler.allTextBoxes.Find(self) == handler.allTextBoxes.Size())
			{
				handler.allTextBoxes.Push(self);
			}
			EventHandler.SendInterfaceEvent(playerNumber, "TOD_NewTextbox");
		}
	}

	void Deactivate()
	{
		active = false;
		angleTurnStep = 0;
		pitchTurnStep = 0;
		if (subject && subject.health > 0)
		{
			subject.bNoTimeFreeze = false;
		}
		int id = handler.activeTextBoxes.Find(self);
		if (id < handler.activeTextBoxes.Size())
		{
			handler.activeTextBoxes.Delete(id);
		}
	}

	void FinishTyping(bool imperfect = false)
	{
		if (subject && ppawn)
		{
			subject.DamageMobj(ppawn, ppawn,
				imperfect? subject.health : subject.health *  2,
				'Normal',
				DMG_FORCED|DMG_NO_FACTOR|DMG_NO_PROTECT|DMG_NO_ENHANCE);
		}
		S_StartSound("TOD/finishtyping", CHAN_AUTO);
		Destroy();
	}

	bool IsVisible()
	{
		if (subject.Distance3DSquared(ppawn) >= 2048**2) return false;

		Vector3 view = level.SphericalCoords((ppawn.pos.xy, ppawn.player.viewz), subject.pos + (0, 0, subject.height*0.5), (ppawn.angle, ppawn.pitch));
		if (abs(view.x) > ppawn.player.fov || abs(view.y) > 45)
		{
			return false;
		}

		return ppawn.CheckSight(subject, SF_IGNOREWATERBOUNDARY);
	}

	override void Tick()
	{
		if (!ppawn || !subject || subject.health <= 0)
		{
			Destroy();
			return;
		}

		if (level.time % 4 == 0)
		{
			int id = handler.activeTextBoxes.Find(self);
			int size = handler.activeTextBoxes.Size();
			bool inArray = (id != size);
			if (inArray && !IsVisible())
			{
				handler.activeTextBoxes.Delete(id);
			}
			else if (!inArray && IsVisible())
			{
				handler.activeTextBoxes.Push(self);
			}
		}

		/*if (active && turnTics)
		{
			ppawn.A_SetAngle(ppawn.angle + angleTurnStep, SPF_INTERPOLATE);
			ppawn.A_SetPitch(ppawn.pitch + pitchTurnStep, SPF_INTERPOLATE);
			turnTics--;
		}

		if (!active && (Actor.InStateSequence(subject.curstate, subject.FindState("Missile")) || Actor.InStateSequence(subject.curstate, subject.FindState("Melee"))))
		{
			Activate();
			subjectAttackState = subject.curstate;
		}

		ProgressSubjectStates();*/
	}

	void ProgressSubjectStates()
	{
		if (!active) return;

		if (typeTics > 0)
		{
			int freq = int(TOD_Utils.LinearMap(handler.activeTextBoxes.Size(), 1, 50, 1, 10));
			/*if (handler.currentTextBox != self)
			{
				freq *= 2;
			}*/
			//Console.Printf("freq: \cd%d\c- | level.time mod freq: \cd%d\c-", freq, (level.time % freq));
			if (level.time % freq == 0)
			{
				typeTics--;
				if (typeTics == 0)
				{
					subject.bNoTimeFreeze = true;
					subject.speed = 0;
					typeTics = GetStateSeqDuration(subject.curstate) * -1;
				}
			}
		}
		else if (typeTics < 0)
		{
			typeTics++;
			if (typeTics == 0)
			{
				subject.bNoTimeFreeze = false;
				typeTics = int(round(startTypeTime * 0.7));
				subject.SetState(subjectAttackState);
			}
		}
	}

	override void OnDestroy()
	{
		Deactivate();
		int id = handler.allTextBoxes.Find(self);
		if (id != handler.allTextBoxes.Size())
		{
			handler.allTextBoxes.Delete(id);
		}
		if (subject && subject.health > 0)
		{
			subject.DamageMobj(ppawn, ppawn, subject.health, 'Normal');
		}
		Super.OnDestroy();
	}
}