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

		if (abs(DeltaAngle(angle, AngleTo(dmgsource))) > player.fov*0.5)
		{
			return 0;
		}
		
		return Super.DamageMobj(inflictor, source, min(damage, 1), mod, flags, angle);
	}
}