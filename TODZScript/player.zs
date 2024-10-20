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