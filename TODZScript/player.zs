class TOD_Player : DoomPlayer
{
	uint damageTics;

	Default
	{
		Health 5;
		+NOTIMEFREEZE
	}

	override bool CanReceive(Inventory item)
	{
		return !(item && item is 'Health');
	}

	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (damageTics) return 0;
		
		if (mod == 'hitscan' || (inflictor && inflictor.bIsPuff))
		{
			if (inflictor.bIsPuff && inflictor.DamageSource)
			{
				inflictor.DamageSource.A_SpawnProjectile('TOD_HitscanProjectile');
				inflictor.Destroy();
			}
			bNoBlood = true;
			return 0;
		}

		let dmgsource = inflictor? inflictor : source;
		if (!inflictor && !source) return 0;
		/*if (AbsAngle(angle, AngleTo(dmgsource)) > player.fov*0.5)
		{
			return 0;
		}*/
	
		if (damage > 0)
		{
			bNoBlood = false;
		}

		int ret = Super.DamageMobj(inflictor, source, min(damage, 1), mod, flags, angle);
		if (ret > 0)
		{
			damageTics = TICRATE;
			EventHandler.SendInterfaceEvent(PlayerNumber(), "TOD_PlayerDamaged");
			//Console.Printf("angle to source: %.1f, fov: %.1f", DeltaAngle(angle, AngleTo(dmgsource)), player.fov);
		}
		return ret;
	}

	override void Tick()
	{
		Super.Tick();
		if (damageTics && player && player.mo && player.mo == self)
		{
			damageTics--;
		}
	}
}