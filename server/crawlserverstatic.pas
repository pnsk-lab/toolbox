unit CrawlServerStatic;

interface
uses
	httpdefs;

procedure CrawlServerStaticRoute(Req : TRequest; Res : TResponse);

implementation
uses
	classes,
	sysutils,
	CrawlServerExtension;

procedure CrawlServerStaticRoute(Req : TRequest; Res : TResponse);
begin
	Res.ContentType := CrawlServerExtensionGet(Req.RouteParams['file']);
	Res.ContentStream := TFileStream.Create('static/' + Req.RouteParams['file'], fmOpenRead or fmShareDenyWrite);
end;

end.
