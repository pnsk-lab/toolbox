unit CrawlProject;

interface
procedure CrawlProjectGet(ID : String; DT : String; Token: String);
procedure CrawlProjectGet(ID : String);

implementation
uses
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	sysutils,
	classes,
	dateutils;

procedure ProjectTargetIteration(ID : String; JTarget : TJSONData; IterationName : String);
var
	JIterations, JIteration, JMD5Ext : TJSONData;
	I : Integer;
	FS : TFileStream;
begin
	JIterations := JTarget.FindPath(IterationName);

	if Assigned(JIterations) then
	begin
		CreateDir('assets');
	
		for I := 0 to JIterations.Count - 1 do
		begin
			JIteration := JIterations.Items[I];

			JMD5Ext := JIteration.FindPath('md5ext');
			if Assigned(JMD5Ext) then
			begin
				while true do
				begin
					if FileExists('assets/' + JMD5Ext.AsString) then
					begin
						WriteLn('[' + ID + '] Skipped ' + JMD5Ext.AsString);
						break;
					end;

					FS := TFileStream.Create('assets/' + JMD5Ext.AsString, fmCreate or fmOpenWrite);
					try TFPHttpClient.SimpleGet('https://cdn.assets.scratch.mit.edu/internalapi/asset/' + JMD5Ext.AsString + '/get', FS);
					except
						WriteLn('[' + ID + '] Failed to get ' + JMD5Ext.AsString + ' - retrying');
						FS.Free();
						continue;	
					end;
					FS.Free();
					break;
				end;
				WriteLn('[' + ID + '] Got ' + Copy(IterationName, 0, Length(IterationName) - 1) + ' ' + JMD5Ext.AsString);
			end;
		end;
	end;
end;

procedure ProjectTarget(ID : String; JTarget : TJSONData);
begin
	ProjectTargetIteration(ID, JTarget, 'costumes');
	ProjectTargetIteration(ID, JTarget, 'sounds');
end;

procedure CrawlProjectGet(ID : String; DT : String; Token: String);
var
	JStr : String;
	JData, JTargets, JTarget : TJSONData;
	ProjectJSON : TextFile;
	I : Integer;
begin
	while true do
	begin
		try JStr := TFPHttpClient.SimpleGet('https://projects.scratch.mit.edu/' + ID + '?token=' + Token);
		except
			WriteLn('[' + ID + '] Failed to get project.json - retrying');
			continue;	
		end;
		break;
	end;
	JData := GetJSON(JStr);

	WriteLn('[' + ID + '] Got project.json');

	CreateDir('projects');
	CreateDir('projects/' + ID);
	CreateDir('projects/' + ID + '/' + DT);

	AssignFile(ProjectJSON, 'projects/' + ID + '/' + DT + '/project.json');
	Rewrite(ProjectJSON);
	Write(ProjectJSON, JStr);
	CloseFile(ProjectJSON);

	JTargets := JData.FindPath('targets');
	if Assigned(JTargets) then
	begin
		for I := 0 to JTargets.Count - 1 do
		begin
			JTarget := JTargets.Items[I];
			
			ProjectTarget(ID, JTarget);
		end;
	end;
	
	JData.Free();
end;

procedure CrawlProjectGet(ID : String);
var
	JData, JToken, JDate, JMeta, JMetaFound : TJSONData;
	JStr : String;
	MetaJSON, InfoJSON : TextFile;
	DT : TDateTime;
	BadDT : TDateTime;
	JObj : TJSONObject;
	FS : TFileStream;
	Skip : Boolean;
begin
	while true do
	begin
		try JStr := TFPHttpClient.SimpleGet('https://api.scratch.mit.edu/projects/' + ID);
		except
			WriteLn('[' + ID + '] Failed to get project token - retrying');
			continue;
		end;
		break;
	end;
	JData := GetJSON(JStr);

	TryISOStrToDateTime('2026-01-22T00:00Z', BadDT);

	JToken := JData.FindPath('project_token');
	if Assigned(JToken) then
	begin
		JDate := JData.FindPath('history.modified');
		if Assigned(JDate) then
		begin
			TryISOStrToDateTime(JDate.AsString, DT);
			if CompareDateTime(DT, BadDT) <= 0 then
			begin
				CreateDir('projects');
				CreateDir('projects/' + ID);
				CreateDir('projects/' + ID + '/' + JDate.AsString);

				Skip := false;

				if FileExists('projects/' + ID + '/' + JDate.AsString + '/metadata.json') then
				begin
					FS := TFileStream.Create('projects/' + ID + '/' + JDate.AsString + '/metadata.json', fmOpenRead);

					JMeta := GetJSON(FS);
					JMetaFound := JMeta.FindPath('notFound');

					Skip := true;
					if Assigned(JMetaFound) then
					begin
						if not(JMetaFound.AsBoolean) then Skip := false;
					end;

					if Skip then WriteLn('[' + ID + '] Project has been scraped already - ignoring');
						
					FS.Free();
				end;

				if not(Skip) then
				begin
					AssignFile(MetaJSON, 'projects/' + ID + '/' + JDate.AsString + '/info.json');
					Rewrite(MetaJSON);
					Write(MetaJSON, JStr);
					CloseFile(MetaJSON);

					WriteLn('[' + ID + '] Got project token');
					CrawlProjectGet(ID, JDate.AsString, JToken.AsString);

					JMeta := GetJSON('{}');
					JObj := JMeta as TJSONObject;
					JObj.Add('scrapedAt', DateToISO8601(Now()));

					AssignFile(InfoJSON, 'projects/' + ID + '/' + JDate.AsString + '/metadata.json');
					Rewrite(InfoJSON);
					Write(InfoJSON, JObj.AsJSON);
					CloseFile(InfoJSON);

					JMeta.Free();
				end;
			end
			else
			begin
				WriteLn('[' + ID + '] Project is too new - ignoring');
			end;
		end;
	end;
	
	JData.Free();
end;

end.
