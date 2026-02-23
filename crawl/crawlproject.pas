unit CrawlProject;

interface
procedure CrawlProjectGet(ID : String; Token: String);
procedure CrawlProjectGet(ID : String);

implementation
uses
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	sysutils,
	classes;

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

procedure CrawlProjectGet(ID : String; Token: String);
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

	CreateDir(ID);

	AssignFile(ProjectJSON, ID + '/project.json');
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
	JData, JToken : TJSONData;
	JObj : TJSONObject;
	JStr : String;
	MetaJSON : TextFile;
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
	JObj := JData as TJSONObject;

	JToken := JObj.FindPath('project_token');
	if Assigned(JToken) then
	begin
		CreateDir(ID);

		AssignFile(MetaJSON, ID + '/meta.json');
		Rewrite(MetaJSON);
		Write(MetaJSON, JStr);
		CloseFile(MetaJSON);

		WriteLn('[' + ID + '] Got projcet token');
		CrawlProjectGet(ID, JToken.AsString);
	end;
	
	JData.Free();
end;

end.
