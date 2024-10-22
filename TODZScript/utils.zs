class TOD_Utils
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

	static clearscope String RemoveComments(String workstring)
	{
		int commentPos = workstring.IndexOf("//");
		while (commentpos >= 0)
		{
			int lineEnd = workstring.IndexOf("\n", commentPos) - 1;
			workstring.Remove(commentPos, lineEnd - commentPos);
			commentPos = workstring.IndexOf("//");
		}
		commentPos = workstring.IndexOf("/*");
		while (commentpos >= 0)
		{
			int lineEnd = workstring.IndexOf("*/", commentPos) - 1;
			workstring.Remove(commentPos, lineEnd - commentPos);
			commentPos = workstring.IndexOf("/*");
		}
		return workstring;
	}

	static clearscope String CleanWhiteSpace(String workstring, bool removeSpaces = false)
	{
		// Strip tabs, carraige returns, "clearlocks",
		// add linebreaks before "{" and "}":
		workstring.Replace("\t", "");
		workstring.Replace("\r", "");
		// Unite duplicate linebreaks, if any:
		while (workstring.IndexOf("\n\n") >= 0)
		{
			workstring.Replace("\n\n", "\n");
		}
		// Remove all spaces, if removeSpaces is true:
		if (removeSpaces)
		{
			workstring.Replace(" ", "");
		}
		// Otherwise clean spaces:
		else
		{
			// Unite duplicate spaces, if any:
			while (workstring.IndexOf("  ") >= 0)
			{
				workstring.Replace("  ", " ");
			}
			// Remove spaces next to linebreaks:
			workstring.Replace("\n ", "\n");
			workstring.Replace(" \n", "\n");
		}
		return workstring;
	}

	static clearscope String CleanQuotes(String workstring)
	{
		// single quotation marks / apostrophes:
		workstring.Replace("’", "'");
		workstring.Replace("‘", "'");
		workstring.Replace("‚", "'");
		workstring.Replace("‛", "'");
		workstring.Replace("`", "'");

		// double quotation marks:
		workstring.Replace("“", "\"");
		workstring.Replace("”", "\"");
		workstring.Replace("„", "\"");
		workstring.Replace("«", "\"");
		workstring.Replace("»", "\"");

		return workstring;
	}

	static clearscope String CleanDashes(String workstring)
	{
		workstring.Replace("—", "-"); //em dash
		workstring.Replace("–", "-"); //en dash
		workstring.Replace("--", "-"); //double hyphen

		return workstring;
	}
}