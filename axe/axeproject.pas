unit AxeProject;

interface
function AxeProjectGet(ID : String; DT : String; Token: String) : Integer;
procedure AxeProjectGet(ID : String);

implementation
uses
	fphttpclient,
	opensslsockets,
	fpjson,
	jsonparser,
	sysutils,
	classes,
	dateutils,
	AxeDatabase,
	AxeUtility;

{
	1 means it's ok
	2 means it should be aborted
}
function ProjectTargetIteration(ID : String; JTarget : TJSONData; IterationName : String) : Integer;
var
	JIterations, JIteration, JMD5Ext : TJSONData;
	I : Integer;
	FS : TFileStream;
begin
	ProjectTargetIteration := 1;

	if AxeUtilityShutdown then
	begin
		ProjectTargetIteration := 2;
		exit;
	end;

	JIterations := JTarget.FindPath(IterationName);

	if Assigned(JIterations) then
	begin
		CreateDir('assets');
	
		for I := 0 to JIterations.Count - 1 do
		begin
			JIteration := JIterations.Items[I];

			JMD5Ext := JIteration.FindPath('md5ext');
			if not(Assigned(JMD5Ext)) then JMD5Ext := JIteration.FindPath('md5');
			if not(Assigned(JMD5Ext)) then JMD5Ext := JIteration.FindPath('baseLayerMD5');

			if Assigned(JMD5Ext) then
			begin
				while true do
				begin
					if FileExists('assets/' + JMD5Ext.AsString) then
					begin
						WriteLn(StdErr, '[' + ID + '] Skipped ' + JMD5Ext.AsString);
						break;
					end;

					while true do
					begin
						try FS := TFileStream.Create('assets/' + JMD5Ext.AsString, fmCreate or fmOpenWrite or fmShareExclusive);
						except
							continue;
						end;
						break;
					end;
					try TFPHTTPClient.SimpleGet('https://cdn.assets.scratch.mit.edu/internalapi/asset/' + JMD5Ext.AsString + '/get', FS);
					except
						WriteLn(StdErr, '[' + ID + '] Failed to get ' + JMD5Ext.AsString + ' - retrying');
						FS.Free();
						DeleteFile('assets/' + JMD5Ext.AsString);
						continue;
					end;
					FS.Free();

					WriteLn(StdErr, '[' + ID + '] Got ' + Copy(IterationName, 0, Length(IterationName) - 1) + ' ' + JMD5Ext.AsString);
					break;
				end;

				if AxeUtilityShutdown then
				begin
					ProjectTargetIteration := 2;
					exit;
				end;
			end;
		end;
	end;
end;

{
	1 means it's ok
	2 means it should be aborted
}
function ProjectTarget(ID : String; JTarget : TJSONData) : Integer;
begin
	ProjectTarget := 1;

	if (ProjectTarget = 1) and (ProjectTargetIteration(ID, JTarget, 'costumes') = 2) then ProjectTarget := 2;
	if (ProjectTarget = 1) and (ProjectTargetIteration(ID, JTarget, 'sounds') = 2) then ProjectTarget := 2;
end;

{
	1 means it's ok
	2 means it should be aborted
}
function Recursive(ID : String; JData : TJSONData) : Integer;
var
	Children : TJSONArray;
	I : Integer;
begin
	Recursive := 1;

	if ProjectTarget(ID, JData) = 2 then
	begin
		Recursive := 2;
		exit;
	end;

	Children := JData.FindPath('children') as TJSONArray;
	if Assigned(Children) then
	begin
		for I := 0 to Children.Count - 1 do
		begin
			Recursive(ID, Children.Items[I]);
		end;
	end;
end;

{
	0 means it got error project
	1 means it's ok
	2 means token should be refetched
	3 means it should be aborted
}
function AxeProjectGet(ID : String; DT : String; Token: String) : Integer;
var
	JStr : String;
	JData, JTargets, JTarget : TJSONData;
	ProjectJSON, ProjectSB : TextFile;
	I : Integer;
begin
	AxeProjectGet := 1;
	while true do
	begin
		try JStr := TFPHTTPClient.SimpleGet('https://projects.scratch.mit.edu/' + ID + '?token=' + Token);
		except
			on E : EHTTPClient do
			begin
				if AxeUtilityShutdown then
				begin
					AxeProjectGet := 3;
					exit;
				end;
				if E.StatusCode = 403 then
				begin
					WriteLn(StdErr, '[' + ID + '] Failed to get project.json - getting token again...');
					AxeProjectGet := 2;
					exit;
				end
				else
				begin
					WriteLn(StdErr, '[' + ID + '] Failed to get project.json - retrying');
					continue;
				end;
			end;
			on E : Exception do
			begin
				continue;
			end;
		end;
		break;
	end;
	try
		JData := GetJSON(JStr, false);
	except
		if Copy(JStr, 1, 10) = 'ScratchV02' then
		begin
			AxeProjectGet := 1;

			WriteLn(StdErr, '[' + ID + '] Got project.sb');

			AssignFile(ProjectSB, 'projects/' + ID + '/' + DT + '/project.sb');
			Rewrite(ProjectSB);
			Write(ProjectSB, JStr);
			CloseFile(ProjectSB);

			exit;
		end;

		AxeProjectGet := 0;
		exit;
	end;

	WriteLn(StdErr, '[' + ID + '] Got project.json');

	CreateDir('projects');
	CreateDir('projects/' + ID);
	CreateDir('projects/' + ID + '/' + DT);

	AssignFile(ProjectJSON, 'projects/' + ID + '/' + DT + '/project.json');
	Rewrite(ProjectJSON);
	Write(ProjectJSON, JStr);
	CloseFile(ProjectJSON);

	if AxeUtilityShutdown then
	begin
		AxeProjectGet := 3;
		JData.Free();
		exit;
	end;

	JTargets := JData.FindPath('targets');
	if Assigned(JTargets) then
	begin
		for I := 0 to JTargets.Count - 1 do
		begin
			JTarget := JTargets.Items[I];
			
			if ProjectTarget(ID, JTarget) = 2 then
			begin
				AxeProjectGet := 3;
				JData.Free();
				exit;
			end;
		end;
	end
	else
	begin
		{ Probably Scratch 2.x }

		if Recursive(ID, JData) = 2 then
		begin
			AxeProjectGet := 3;
			JData.Free();
			exit;
		end;
	end;
	
	JData.Free();
end;

procedure GetThumbnail(ID : String; Dest : String; URL : String);
var
	HTTP : TFPHTTPClient;
	FS : TFileStream;
begin
	while true do
	begin
		while true do
		begin
			try FS := TFileStream.Create(Dest, fmCreate or fmOpenWrite or fmShareExclusive);
			except
				continue;
			end;
			break;
		end;
		HTTP := TFPHTTPClient.Create(nil);
		HTTP.AllowRedirect := true;
		try HTTP.Get(URL, FS);
		except
			WriteLn(StdErr, '[' + ID + '] Failed to get thumbnail - retrying');
			HTTP.Free();
			FS.Free();

			if AxeUtilityShutdown then
			begin
				DeleteFile(Dest);
				exit;
			end;
			continue;
		end;
		HTTP.Free();
		FS.Free();
		WriteLn(StdErr, '[' + ID + '] Got thumbnail');
		break;
	end;
end;

procedure AxeProjectGet(ID : String);
var
	JData, JToken, JDate, JMeta, JMetaFound, JImage : TJSONData;
	JStr : String;
	MetaJSON, InfoJSON : TextFile;
	DT : TDateTime;
	BadDT : TDateTime;
	JObj : TJSONObject;
	FS : TFileStream;
	Skip : Boolean;
	Entry : TAxeDatabaseEntry;
	N : Integer;
	RetValue : Integer;
	ThumbnailExtension : String;
begin
	TryISOStrToDateTime('2026-01-22T00:00Z', BadDT);

	while true do
	begin
		while true do
		begin
			try JStr := TFPHTTPClient.SimpleGet('https://api.scratch.mit.edu/projects/' + ID);
			except
				WriteLn(StdErr, '[' + ID + '] Failed to get project token - retrying');
				if AxeUtilityShutdown then
				begin
					exit;
				end;
				continue;
			end;
			break;
		end;
		JData := GetJSON(JStr, false);

		if AxeUtilityShutdown then
		begin
			JData.Free();
			exit;
		end;
	
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
					CreateDir('projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]));
	
					JObj := JData as TJSONObject;
	
					N := 0;
					if Assigned(JObj.FindPath('id')) then
					begin
						Entry.ProjectID := JObj.Integers['id'];
						N := N + 1;
					end;
					if Assigned(JObj.FindPath('title')) then
					begin
						Entry.Title := JObj.Strings['title'];
						N := N + 1;
					end;
					if Assigned(JObj.FindPath('description')) then
					begin
						Entry.Description := JObj.Strings['description'];
						N := N + 1;
					end;
					if Assigned(JObj.FindPath('instructions')) then
					begin
						Entry.Instructions := JObj.Strings['instructions'];
						N := N + 1;
					end;
					if Assigned(JObj.FindPath('author.id')) then
					begin
						Entry.AuthorID := JObj.Objects['author'].Integers['id'];
						N := N + 1;
					end;
					if Assigned(JObj.FindPath('author.username')) then
					begin
						Entry.AuthorName := JObj.Objects['author'].Strings['username'];
						N := N + 1;
					end;
					if Assigned(JObj.FindPath('history.modified')) then
					begin
						Entry.Timestamp := JObj.Objects['history'].Strings['modified'];
						N := N + 1;
					end;
					if Assigned(JObj.FindPath('history.shared')) then
					begin
						Entry.SharedTimestamp := JObj.Objects['history'].Strings['shared'];
						N := N + 1;
					end;
	
					Skip := false;

					if AxeUtilityShutdown then
					begin
						JData.Free();
						exit;
					end;
	
					JImage := JObj.FindPath('images.282x218');
					if Assigned(JImage) then
					begin
						ThumbnailExtension := AxeUtilityGetExtension(JImage.AsString);
						if not(FileExists('projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]) + '/thumbnail.' + ThumbnailExtension)) then
						begin
							GetThumbnail(ID, 'projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]) + '/thumbnail.' + ThumbnailExtension, JImage.AsString);
						end;
					end;

					if FileExists('projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]) + '/metadata.json') then
					begin
						FS := TFileStream.Create('projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]) + '/metadata.json', fmOpenRead);
	
						JMeta := GetJSON(FS);
						JMetaFound := JMeta.FindPath('notFound');
	
						Skip := true;
						if Assigned(JMetaFound) then
						begin
							if not(JMetaFound.AsBoolean) then Skip := false;
						end;
	
						if Skip then
						begin
							if N = 8 then
							begin
								AxeDatabaseAdd(Entry, False);
							end;
							WriteLn(StdErr, '[' + ID + '] Project has been scraped already - ignoring');
						end;
							
						FS.Free();
					end;
	
					if not(Skip) then
					begin
						if N = 7 then
						begin
							AxeDatabaseAdd(Entry, True);
						end;
	
						AssignFile(MetaJSON, 'projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]) + '/info.json');
						Rewrite(MetaJSON);
						Write(MetaJSON, JStr);
						CloseFile(MetaJSON);
	
						WriteLn(StdErr, '[' + ID + '] Got project token');
						RetValue := AxeProjectGet(ID, StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]), JToken.AsString);
						if RetValue = 1 then
						begin
							JMeta := GetJSON('{}');
							JObj := JMeta as TJSONObject;
							JObj.Add('scrapedAt', DateToISO8601(Now()));
	
							AssignFile(InfoJSON, 'projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]) + '/metadata.json');
							Rewrite(InfoJSON);
							Write(InfoJSON, JObj.AsJSON);
							CloseFile(InfoJSON);
						end
						else if RetValue = 0 then
						begin
							JMeta := GetJSON('{}');
							JObj := JMeta as TJSONObject;
							JObj.Add('notFound', true);
	
							AssignFile(InfoJSON, 'projects/' + ID + '/' + StringReplace(JDate.AsString, ':', '-', [rfReplaceAll]) + '/metadata.json');
							Rewrite(InfoJSON);
							Write(InfoJSON, JObj.AsJSON);
							CloseFile(InfoJSON);
						end
						else if RetValue = 2 then
						begin
							JData.Free();
							continue;
						end
						else if RetValue = 3 then
						begin
							JData.Free();
							exit;
						end;
	
						JMeta.Free();
					end;
				end
				else
				begin
					WriteLn(StdErr, '[' + ID + '] Project is too new - ignoring');
				end;
			end;
		end;
		
		JData.Free();
		break;
	end;
end;

end.
