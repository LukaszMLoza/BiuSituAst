program ast_rest_server;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  fphttpserver, httpdefs,
  ast_parser, manual_ast_parser, ast_server;

//procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
//  var AResponse: TFPHTTPConnectionResponse);
//var
//  FileName: string;
//begin
//  if ARequest.URI = '/parse' then
//  begin
//    FileName := ARequest.QueryFields.Values['file'];
//
//    if (FileName = '') or (not FileExists(FileName)) then
//    begin
//      AResponse.Code := 400;
//      AResponse.Content := '{"error":"invalid file"}';
//      Exit;
//    end;
//
//    AResponse.ContentType := 'application/json';
//    // tymczasowo wylączone
//    AResponse.Content := ParseUnitToJson(FileName);
//    Exit;
//  end;
//
//  AResponse.Code := 404;
//end;

//var
//  Server: TFPHTTPServer;
//
//begin
//  //RunAst('C:\Praca\IR1\Project\a.pas');
//
//  Server := TFPHTTPServer.Create(nil);
//  try
//    Server.Port := 8010;
//    Server.Threaded := True;
//    Server.OnRequest := @HandleRequest;
//    Server.Active := True;
//
//    Writeln('AST REST server running on http://localhost:8080');
//    Readln;
//  finally
//    Server.Free;
//  end;
//end.

var
  Server: TFPHTTPServer;
  AstServer: TAstServer;

begin
  AstServer := TAstServer.Create;
  Server := TFPHTTPServer.Create(nil);
  try
    Server.Port := 8010;
    Server.Threaded := True;
    Server.OnRequest := @AstServer.HandleRequest;
    Server.Active := True;

    Writeln('AST REST server running on http://localhost:8010');
    Readln;
  finally
    Server.Free;
    AstServer.Free;
  end;
end.

