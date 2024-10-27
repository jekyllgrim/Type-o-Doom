/*class TOD_AltHud : AltHud
{
	override void DrawHealth(PlayerInfo CPlayer, int x, int y)
	{}

	override void DrawArmor(BasicArmor barmor, HexenArmor harmor, int x, int y)
	{}

	override int DrawAmmo(PlayerInfo CPlayer, int x, int y)
	{}

	override void DrawWeapons(PlayerInfo CPlayer, int x, int y)
	{}
}*/

class TOD_Hud : BaseStatusBar
{
	TOD_Handler handler;
	HUDFont hBigUpper;
	bool justLostHealth;
	uint healthTexFrame;
	uint healthTexFrameLost;
	const HEALTHTEX_LOOPFRAME = 13;
	const HEALTHTEX_LASTFRAME = 19;

	LinearValueInterpolator perfectIntr;
	int starTics;
	Vector2 starPos;
	double starScale;
	double starAngle;
	double starAlpha;
	const STARTIME = TICRATE;
	bool displayStar;
	array<TOD_PerfectStar> stars;

	override void Init()
	{
		Super.Init();
		hBigUpper = HUDFont.Create(Font.FindFont('BigUpper'));
		healthTexFrame = 1;
		perfectIntr = LinearValueInterpolator.Create(0, 1);
	}

	override void Draw(int state, double TicFrac)
	{
		Super.Draw(state, ticfrac);

		if (state == HUD_None) return;

		if (!handler)
		{
			handler = TOD_Handler(EventHandler.Find('TOD_Handler'));
		}
		else
		{
			BeginHUD(1.0, true, 320, 200);
			DrawPerfectionIndicator();
			DrawHealth();
		}
	}

	override void Tick()
	{
		Super.Tick();
		if (level.time % 2 == 0)
		{
			if (++healthTexFrame > HEALTHTEX_LOOPFRAME)
			{
				healthTexFrame = 1;
			}
			if (justLostHealth && ++healthTexFrameLost > HEALTHTEX_LASTFRAME)
			{
				justLostHealth = false;
			}
		}
		if (!handler) return;

		if (handler.perfectWords == 0)
		{
			perfectIntr.Reset(0);
		}
		else
		{
			perfectIntr.Update(handler.perfectWords * 10);
		}

		if (displayStar)
		{
			starAngle -= 10;
			starPos.y += 2;
			starPos.x = 32 + 25 * sin(360.0 * level.time / 40) * (double(starTics) / STARTIME);
			double fac = double(starTics) / STARTIME;
			starAlpha = 1.0 - fac;
			starScale =  4 / fac;
			if (++starTics > STARTIME)
			{
				PerfectLevelComplete(false);
			}
			else
			{
				foreach (st : stars)
				{
					if (st)
						st.Update();
				}
				let star = TOD_PerfectStar.Create(starPos, angle: starAngle, alpha: starAlpha, scale: starScale);
				stars.Push(star);
			}
		}
	}

	void PlayerDamaged()
	{
		justLostHealth = true;
		healthTexFrameLost = HEALTHTEX_LOOPFRAME;
	}

	void DrawHealth()
	{
		int flags = DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER_BOTTOM;
		Vector2 pos = (16, -4);
		double dist = 18;
		for (int i = min(CPlayer.mo.health, CPlayer.mo.GetMaxHealth()); i > 0; i--)
		{
			DrawImage(String.Format("TODHP%02d", healthTexFrame), pos, flags, scale: (0.75, 0.75));
			pos.x += dist;
		}
		if (justLostHealth)
		{
			DrawImage(String.Format("TODHP%02d", healthTexFrameLost), pos, flags, scale: (0.75, 0.75));
		}
	}

	void PerfectLevelComplete(bool enable = true)
	{
		starTics = 0;
		starPos = (0, 30);
		starAngle = 0;
		stars.Clear();
		displayStar = enable;
	}

	void DrawPerfectionIndicator(Vector2 pos = (16, 30), Vector2 size = (92, 10), double border = 2, double indent = 0.5)
	{
		int flags = DI_SCREEN_LEFT_TOP;

		Fill(0xff101010, pos.x, pos.y, size.x, size.y, flags); //inside

		double amt = double(handler.perfectWords) / handler.PERFECT_WordsPerLevel;
		Fill(0xffe1ac1b, pos.x + indent, pos.y + indent, (size.x - indent*2) * amt, size.y - indent*2, flags); //underbar

		amt = perfectIntr.GetValue() / (handler.PERFECT_WordsPerLevel * 10.0);
		Fill(0xff3eff74, pos.x + indent, pos.y + indent, (size.x - indent*2) * amt, size.y - indent*2, flags); //bar

		Fill(0xff545454, pos.x, pos.y + indent, size.x, border, flags); //bottom border
		Fill(0xff545454, pos.x, pos.y + size.y - border - indent, size.x, border, flags); //top border

		DrawString(hBigUpper, 
			String.Format("PERFECT %02d", handler.perfectLevels),
			pos + (0, size.y + 2),
			flags,
			Font.CR_Gold,
			scale: (0.5, 0.5));
		
		if (displayStar)
		{
			if (starTics <= STARTIME*0.3)
			{
				DrawImage("TODPERFT", pos + (16, 0), flags|DI_ITEM_CENTER, scale: (0.25, 0.25) * TOD_Utils.LinearMap(starTics, 0, STARTIME*0.3, 1.0, 0.0));
			}
			foreach (st : stars)
			{
				if (st)
				{
					DrawImageRotated("TODPERFT",
						st.pos,
						flags: flags,
						angle: st.angle,
						alpha: st.alpha,
						scale: (st.scale, st.scale));
				}
			}
		}
	}
}

class TOD_PerfectStar
{
	double alpha;
	double scale;
	double angle;
	Vector2 pos;

	static TOD_PerfectStar Create(Vector2 pos, double angle = 0, double alpha = 1.0, double scale = 1.0)
	{
		let s = new('TOD_PerfectStar');
		s.pos = pos;
		s.angle = angle;
		s.alpha = alpha;
		s.scale = scale;
		return s;
	}

	void Update(double fadestep = 0.05, double scalestep = 0.1)
	{
		alpha -= fadestep;
		scalestep -= scalestep;
		if (alpha <= 0 || scale <= 0)
		{
			Destroy();
		}
	}
}