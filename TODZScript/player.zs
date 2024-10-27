class TOD_Player : DoomPlayer
{
	Default
	{
		Health 10;
		+NOTIMEFREEZE
	}

	override bool CanReceive(Inventory item)
	{
		return !(item && item is 'Health');
	}

	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (flags & DMG_EXPLOSION)
		{
			return 0;
		}
		
		let dmgsource = inflictor? inflictor : source;
		if (!dmgsource)
		{
			return 0;
		}

		/*if (AbsAngle(angle, AngleTo(dmgsource)) > player.fov*0.5)
		{
			return 0;
		}*/
	
		if (damage > 0)
		{
			EventHandler.SendInterfaceEvent(PlayerNumber(), "TOD_PlayerDamaged");
		}
		return Super.DamageMobj(inflictor, source, min(damage, 1), mod, flags, angle);
	}
}