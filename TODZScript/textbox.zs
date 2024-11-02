class TOD_TextBox : Thinker
{
	protected int age;
	TOD_Le_GlScreen projection;

	TOD_Handler handler;
	PlayerPawn ppawn;
	int playerNumber;
	Actor subject;
	State subjectCachedState;
	State sMelee;
	State sMissile;
	protected bool active;

	String stringToType;
	String firstCharacter;
	uint stringToTypeLength;
	uint turnTics;
	double angleTurnStep;
	double pitchTurnStep;

	int typeTics;
	uint startTypeTime;

	const AVGTYPEPERTIC = 4.0 / TICRATE;
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

	virtual bool PickString()
	{
		if (stringToType && handler.activeTextBoxes.Find(self) < handler.activeTextBoxes.Size()) return true;

		array<String> listToUse;
		let glossary = TOD_StaticInfo(StaticEventHandler.Find('TOD_StaticInfo'));
		if (!glossary) return false;

		if (subject.health <= 80)
			listToUse.Copy(glossary.words_1short);
		else if (subject.health <= 200)
			listToUse.Copy(glossary.words_1word);
		else if (subject.health <= 300)
			listToUse.Copy(glossary.words_2words);
		else if (subject.health <= 500)
			listToUse.Copy(glossary.words_3words);
		else if (subject.health <= 1000)
			listToUse.Copy(glossary.words_4words);
		else
			listToUse.Copy(glossary.words_sentences);
		
		if (listToUse.Size() < 1)
		{
			return false;
		}

		if (!stringToType)
		{
			stringToType = listToUse[random[pickstr](0, listToUse.Size()-1)];
			firstCharacter = stringToType.Left(1);
		}
		if (handler.activeTextBoxes.Size() > 1)
		{
			int maxiterations = listToUse.Size();
			while (maxiterations)
			{
				bool isValid = true;
				foreach (tbox : handler.activeTextBoxes)
				{
					if (tbox && tbox != self && tbox.firstCharacter ~== firstCharacter)
					{
						isValid = false;
						break;
					}
				}
				if (isValid)
				{
					break;
				}
				stringToType = listToUse[random[pickstr](0, listToUse.Size()-1)];
				firstCharacter = stringToType.Left(1);
				maxiterations--;
			}
		}

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
		subject.bNoTimeFreeze = true;
		subject.bNoInfighting = true;
		subject.reactiontime = 1;
		subject.speed *= 0.5;
		subject.maxTargetRange = TOD_MAXTYPINGRANGE;
		msg.subject = subject;
		msg.sMelee = subject.FindState("Melee");
		msg.sMissile = subject.FindState("Missile");
		msg.PickString();
		handler.allTextBoxes.Push(msg);
		if (subject.bDormant)
		{
			msg.Deactivate();
		}
		return msg;
	}

	virtual void Activate()
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
	}

	virtual void Deactivate()
	{
		active = false;
		angleTurnStep = 0;
		pitchTurnStep = 0;
		typeTics = startTypeTime;
		if (subject)
		{
			subject.bNoTimeFreeze = (subject.health <= 0 || !IsAttacking());
		}
		int id = handler.activeTextBoxes.Find(self);
		if (id < handler.activeTextBoxes.Size())
		{
			handler.activeTextBoxes.Delete(id);
		}
		if (handler.activeTextBoxes.Size() <= 0)
		{
			level.SetFrozen(false);
		}
	}

	virtual void FinishTyping(bool imperfect = false)
	{
		if (subject && ppawn)
		{
			subject.DamageMobj(ppawn, ppawn,
				imperfect? subject.health : subject.health *  2,
				'Normal',
				DMG_FORCED|DMG_NO_FACTOR|DMG_NO_PROTECT|DMG_NO_ENHANCE);
		}
		if (!imperfect)
		{
			handler.IncrementPerfectCounter();
		}
		else
		{
			handler.ResetPerfectCounter();
		}
		Destroy();
	}

	bool IsVisible()
	{
		if (active && turntics)
		{
			//Console.Printf("\cd%s\c- : visible (active, turning)", stringToType);
			return true;
		}

		if (ppawn.Distance3DSquared(subject) > TOD_MAXTYPINGRANGE**2)
		{
			//Console.Printf("\cd%s\c- : invisible (too far)", stringToType);
			return false;
		}

		if (!projection)
		{
			projection = New("TOD_Le_GlScreen");
		}

		projection.CacheCustomResolution(480 * (Screen.GetAspectRatio(), 1));
		projection.CacheFov(ppawn.player.fov);
		projection.OrientForPlayer(ppawn.player);
		projection.BeginProjection();
		projection.ProjectActorPosPortal(subject, (0, 0, subject.height*0.15));

		if (!projection.IsInScreen())
		{
			//Console.Printf("\cd%s\c- : invisible (not on screen)", stringToType);
			return false;
		}
		
		Vector3 view = level.SphericalCoords((ppawn.pos.xy, ppawn.player.viewz), subject.pos + (0, 0, subject.height*0.15), (ppawn.angle, ppawn.pitch));
		//Console.Printf("angles: %.1f, %.1f / (%.1f, %.1f)", abs(view.x), abs(view.y), ppawn.player.fov * 0.65, 30);
		if (abs(view.x) > ppawn.player.fov * 0.65 || abs(view.y) > 30)
		{
			return false;
		}

		bool sight = ppawn.CheckSight(subject, SF_IGNOREWATERBOUNDARY);
		//Console.Printf("\cd%s\c- : check sight %s", stringToType, sight? "success" : "fail");
		return sight;
	}

	virtual void UpdateVisibility()
	{
		age++;
		int freq = clamp(handler.activeTextBoxes.Size() * 2, 1, 20);
		if (age % freq == 0)// || (!turntics && !active))
		{
			bool visible = IsVisible();
			bool isActive = active;
			if (isActive && !visible)
			{
				//Console.Printf("Deactivating \cd%s\c-", stringToType);
				Deactivate();
			}
			if (!isActive && visible)
			{
				//Console.Printf("Activating \cd%s\c-", stringToType);
				Activate();
			}
		}
	}

	virtual void ShouldFocus()
	{
		if (!handler.isPlayerTyping && (Actor.InStateSequence(subject.curstate, sMelee) || Actor.InStateSequence(subject.curstate, sMissile)))
		{
			if (subject.Distance3D(ppawn) <= TOD_MAXTYPINGRANGE && ppawn.CheckSight(subject, SF_IGNOREWATERBOUNDARY))
			{
				Activate();
				//EventHandler.SendInterfaceEvent(playerNumber, "TOD_FocusTextBox", id);
				handler.ToggleTyping(true);
				Vector3 view = level.SphericalCoords((ppawn.pos.xy, ppawn.player.viewz), subject.pos + (0, 0, subject.height*0.5), (ppawn.angle, ppawn.pitch));
				if (abs(view.x) > 45 || abs(view.y) > 15)
				{
					double maxViewDist = max(abs(view.x), abs(view.y));
					turnTics = int(round(TOD_Utils.LinearMap(maxViewDist, 45, 180, TICRATE*0.5, TICRATE)));
					angleTurnStep = -view.x / turnTics;
					pitchTurnStep = -view.y / turnTics;
				}
			}
			else
			{
				subject.SetState(subject.seestate);
			}
		}
	}

	virtual void ProgressSubjectMovement()
	{
		subject.movecount = min(subject.movecount, 5);

		if (handler.isPlayerTyping)
		{
			if (active)
			{
				if (turnTics)
				{
					ppawn.A_SetAngle(ppawn.angle + angleTurnStep, SPF_INTERPOLATE);
					ppawn.A_SetPitch(ppawn.pitch + pitchTurnStep, SPF_INTERPOLATE);
					turnTics--;
				}
				else
				{
					ProgressSubjectAttack();
				}
			}
			else
			{
				subject.bNoTimeFreeze = false;
			}
		}
	}

	override void Tick()
	{
		if (!ppawn || !subject || subject.health <= 0)
		{
			Destroy();
			return;
		}

		if (subject.bDormant)
		{
			return;
		}

		if (subject.target && subject.Distance3DSquared(subject.target) > TOD_MAXTYPINGRANGE**2)
		{
			subject.A_ClearTarget();
		}

		UpdateVisibility();
		ShouldFocus();
		ProgressSubjectMovement();
	}

	bool IsAttacking()
	{
		if (!sMelee)
			sMelee = subject.FindState("Melee");
		if (!sMissile)
			sMissile = subject.FindState("Missile");

		if ((sMelee && subjectCachedState == sMelee) || (sMissile && subjectCachedState == sMissile))
		{
			return true;
		}

		if ((sMelee && Actor.InStateSequence(subject.curstate, sMelee) && subjectCachedState != sMelee) ||
		    (sMissile && Actor.InStateSequence(subject.curstate, sMissile) && subjectCachedState != sMissile))
		{
			subjectCachedState = sMelee? sMelee : sMissile;
			return true;
		}
		
		return false;
	}

	void ProgressSubjectAttack()
	{
		if (!IsAttacking())
		{
			subject.bNoTimeFreeze = true;
			return;
		}
		else if (typeTics == startTypeTime)
		{
			subject.bNoTimeFreeze = false;
		}

		if (typeTics > 0)
		{
			int freq = clamp(handler.activeTextBoxes.Size() / 2, 1, TICRATE);
			if (level.time % freq == 0)
			{
				typeTics--;
				if (typeTics == 0)
				{
					subject.bNoTimeFreeze = true;
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
				if ((sMelee && subjectCachedState == sMelee) || (sMissile && subjectCachedState == sMissile))
				{
					subject.SetState(subjectCachedState);
				}
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
		if (subject)
		{
			subject.bNoTimeFreeze = true;
			if (subject.health > 0)
				subject.DamageMobj(ppawn, ppawn, subject.health, 'Normal');
		}
		Super.OnDestroy();
	}
}

class TOD_ProjectileTextBox : TOD_TextBox
{
	static TOD_ProjectileTextBox Attach(PlayerPawn ppawn, Actor subject)
	{
		if (!ppawn || !ppawn.player || !ppawn.player.mo || ppawn.player.mo != ppawn ||
			!subject || !subject.bMissile || !subject.target || subject.speed <= 0)
		{
			return null;
		}

		let handler = TOD_Handler(EventHandler.Find('TOD_Handler'));
		if (!handler) return null;

		let msg = New('TOD_ProjectileTextBox');
		msg.handler = handler;
		msg.ppawn = ppawn;
		msg.playerNumber = ppawn.PlayerNumber();
		subject.bNoTimeFreeze = true;
		subject.vel *= TOD_Utils.LinearMap(handler.activeTextBoxes.Size(), 1, 30, 0.2, 0.02, true);
		msg.subject = subject;
		handler.allTextBoxes.Push(msg);
		msg.Activate();
		return msg;
	}

	override bool PickString()
	{
		if (stringToType && handler.activeTextBoxes.Find(self) < handler.activeTextBoxes.Size()) return true;

		stringToType = ""..random[pickstring](0, 9);
		
		firstCharacter = stringToType.Left(1);
		stringToTypeLength = stringToType.Length();
		startTypeTime = int(ceil(stringToTypeLength * AVGTYPEPERTIC)) + REACTIONTICS;
		typeTics = startTypeTime;
		return true;
	}

	override void Activate()
	{
		if (!ppawn || !subject || !subject.bMissile || !PickString())
		{
			Destroy();
			return;
		}

		active = true;

		if (handler.activeTextBoxes.Find(self) == handler.activeTextBoxes.Size())
		{
			handler.activeTextBoxes.Push(self);
		}
	}

	override void Deactivate()
	{
		active = false;
		typeTics = startTypeTime;
		int id = handler.activeTextBoxes.Find(self);
		if (id < handler.activeTextBoxes.Size())
		{
			handler.activeTextBoxes.Delete(id);
		}
	}

	override void FinishTyping(bool imperfect)
	{
		if (subject)
		{
			subject.ExplodeMissile();
			subject.bNoTimeFreeze = true;
		}
		Destroy();
	}

	override void OnDestroy()
	{
		Deactivate();
		int id = handler.allTextBoxes.Find(self);
		if (id != handler.allTextBoxes.Size())
		{
			handler.allTextBoxes.Delete(id);
		}
		if (subject && subject.bMissile)
		{
			subject.Destroy();
		}
		Super.OnDestroy();
	}

	override void Tick()
	{
		if (!ppawn || !subject || !subject.bMissile)
		{
			Destroy();
			return;
		}

		UpdateVisibility();
		if (!active)
		{
			Destroy();
		}
	}
}