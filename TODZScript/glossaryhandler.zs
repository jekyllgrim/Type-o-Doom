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
		ParseGlossary("TODG_sh", words_1short);
		ParseGlossary("TODG_1w", words_1word);
		ParseGlossary("TODG_2w", words_2words);
		ParseGlossary("TODG_3w", words_3words);
		ParseGlossary("TODG_4w", words_4words);
		ParseGlossary("TODG_sen", words_sentences);
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
			lumpdata = TOD_Utils.RemoveComments(lumpdata);
			lumpdata = TOD_Utils.CleanWhiteSpace(lumpdata);
			lumpdata = TOD_Utils.CleanQuotes(lumpdata);
			lumpdata = TOD_Utils.CleanDashes(lumpdata);
			int fileEnd = lumpdata.Length();
			int searchpos = 0;
			while (searchPos >= 0 && searchPos < fileEnd)
			{
				int lineEnd = lumpdata.IndexOf("\n", searchPos);
				if (lineEnd < 0)
				{
					lineEnd = fileEnd;
				}
				String textline = lumpdata.Mid(searchPos, lineEnd - searchPos);
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
}