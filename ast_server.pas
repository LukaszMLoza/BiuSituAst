unit ast_server;

{$mode Delphi}

interface

uses
  Classes, SysUtils, fphttpserver, httpdefs,
  manual_ast_parser;

type
  TAstServer = class
  public
    procedure HandleRequest(Sender: TObject;
      var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  end;

implementation

procedure TAstServer.HandleRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  FileName: string;
begin
  if ARequest.PathInfo = '/parse' then
  begin
    FileName := ARequest.QueryFields.Values['file'];

    if (FileName = '') or (not FileExists(FileName)) then
    begin
      AResponse.Code := 400;
      AResponse.Content := '{"error":"invalid file"}';
      Exit;
    end;

    AResponse.ContentType := 'application/json';
    AResponse.CacheControl := 'no-store';
    AResponse.Content := ParseUnitToJson(FileName);
    Exit;
  end;

  AResponse.Code := 404;
end;

end.

