program crawl;

uses
	CrawlProject,
	CrawlUser,
	sysutils;

var
	I : Integer;
begin
	I := 1;
	while I < ParamCount do
	begin
		if ParamStr(I) = '--user' then
		begin
			I := I + 1;
			CrawlUserGet(ParamStr(I));
		end
		else if ParamStr(I) = '--directory' then
		begin
			I := I + 1;
			CreateDir(ParamStr(I));
			ChDir(ParamStr(I));
		end
		else
		begin
			CrawlProjectGet(ParamStr(I));
		end;

		I := I + 1;
	end;
end.
