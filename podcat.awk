/^=pod$/	{pod=1}
		{if (pod) print}
/^=cut$/	{pod=0; print ""}
