unit DDDSelfTests;

{$I mormot.defines.inc}

interface

uses
  mormot.core.base,
  mormot.core.test,
  mormot.core.threads,
  mormot.orm.core,
  mormot.rest.core,
  mormot.rest.sqlite3,
  mormot.rest.http.server,
  mormot.rest.http.client,                    j
  mORMotDDD2;

type
  // This is our simple Test data class. Will be mapped to TSQLRecordDDDTest.
  TDDDTest = class(TSynPersistent)
  private
    fDescription: RawUTF8;
  published
    property Description: RawUTF8 read fDescription write fDescription;
  end;

  TDDDTestObjArray = array of TDDDTest;

  // The corresponding TSQLRecord for TDDDTest.
  TSQLRecordDDDTest = class(TSQLRecord)
  private
    fDescription: RawUTF8;
  published
    property Description: RawUTF8 read fDescription write fDescription;
  end;

  // CQRS Query Interface fo TTest
  IDDDThreadsQuery = interface(ICQRSService)
    ['{DD402806-39C2-4921-98AA-A575DD1117D6}']
    function SelectByDescription(const aDescription: RawUTF8): TCQRSResult;
    function SelectAll: TCQRSResult;
    function Get(out aAggregate: TDDDTest): TCQRSResult;
    function GetAll(out aAggregates: TDDDTestObjArray): TCQRSResult;
    function GetNext(out aAggregate: TDDDTest): TCQRSResult;
    function GetCount: integer;
  end;

  // CQRS Command Interface for TTest
  IDDDThreadsCommand = interface(IDDDThreadsQuery)
    ['{F0E4C64C-B43A-491B-85E9-FD136843BFCB}']
    function Add(const aAggregate: TDDDTest): TCQRSResult;
    function Update(const aUpdatedAggregate: TDDDTest): TCQRSResult;
    function Delete: TCQRSResult;
    function DeleteAll: TCQRSResult;
    function Commit: TCQRSResult;
    function Rollback: TCQRSResult;
  end;

  /// a test case for all shared DDD types and services
  TTestDDDSharedUnits = class(TSynTestCase)
  protected
  published
    /// test the User modelization types, including e.g. Address
    procedure UserModel;
    /// test the Authentication modelization types, and implementation
    procedure AuthenticationModel;
    /// test the Email validation process
    procedure EmailValidationProcess;
    /// test the CQRS Repository for TUser persistence
    procedure UserCQRSRepository;
  end;

  /// a test case for aggressive multi-threaded DDD ORM test
  TTestDDDMultiThread = class(TSynTestCase)
  private
    // Rest server
    fRestServer: TRestServerDB;
    // Http server
    fHttpServer: TSQLHttpServer;
    /// will create as many Clients as specified by aClient.
    // - each client will perform as many Requests as specified by aRequests.
    // - this function will wait for all Clients until finished.
    function ClientTest(const aClients, aRequests: integer): boolean;
  protected
    /// cleaning up the test
    procedure CleanUp; override;
  published
    /// delete any old Test database on start
    procedure DeleteOldDatabase;
    /// start the whole DDD Server (http and rest)
    procedure StartServer;
    /// test straight-forward access using 1 thread and 1 client
    procedure SingleClientTest;
    /// test concurrent access with multiple clients
    procedure MultiThreadedClientsTest;
  end;

implementation

uses Windows, SysUtils,
  mormot.core.os,
  mormot.core.interfaces,
  mormot.core.text,
  mormot.db.raw.sqlite3,
  mormot.soa.core,
  test.core.base,
  dddDomCountry,
  dddDomUserTypes,
  dddInfraAuthRest,
  dddInfraRepoUser,
  dddInfraEmailer;

{ TTestDDDSharedUnits }

procedure TTestDDDSharedUnits.AuthenticationModel;
begin
  TDDDAuthenticationSHA256.RegressionTests(self);
  TDDDAuthenticationMD5.RegressionTests(self);
end;

procedure TTestDDDSharedUnits.EmailValidationProcess;
begin
  TestDddInfraEmailer(TSQLRestServerDB,self);
end;

procedure TTestDDDSharedUnits.UserModel;
begin
  TCountry.RegressionTests(self);
  TPersonContactable.RegressionTests(self);
end;

procedure TTestDDDSharedUnits.UserCQRSRepository;
begin
  TInfraRepoUserFactory.RegressionTests(self);
end;

type
  // The infratructure REST class implementing the Query and Command Interfaces for TTest
  TDDDThreadsTestRest = class(TDDDRepositoryRestCommand, IDDDThreadsCommand)
  public
    function SelectByDescription(const aDescription: RawUTF8): TCQRSResult;
    function SelectAll: TCQRSResult;
    function Get(out aAggregate: TDDDTest): TCQRSResult;
    function GetAll(out aAggregates: TDDDTestObjArray): TCQRSResult;
    function GetNext(out aAggregate: TDDDTest): TCQRSResult;
    function Add(const aAggregate: TDDDTest): TCQRSResult;
    function Update(const aUpdatedAggregate: TDDDTest): TCQRSResult;
  end;

  // REST Factory for TDDDThreadsTestRest instances
  TDDDThreadsTestRestFactory = class(TDDDRepositoryRestFactory)
  public
    constructor Create(aRest: TSQLRest; aOwner: TDDDRepositoryRestManager = nil); reintroduce;
  end;

  // Custom TSQLHttpClient encapsulating the remote IDDDThreadsCommand interface.
  TDDDThreadsHttpClient = class(TRestHttpClient)
  private
    // Internal Model
//    fModel: TSQLModel;
    // IDDDThreadsCommand interface. Will be assigned inside SetUser
    fMyCommand: IDDDThreadsCommand;
  public
//    constructor Create(const aServer, aPort: AnsiString); reintroduce;
    destructor Destroy; override;
//    function SetUser(const aUserName, aPassword: RawUTF8; aHashedPassword: Boolean = false): boolean; reintroduce;
    property MyCommand: IDDDThreadsCommand read fMyCommand;
  end;

  // The thread used by TTestDDDMultiThread.ClientTest
  TDDDThreadsThread = class(TSynThread)
  private
    fHttpClient: TDDDThreadsHttpClient;
    fRequestCount: integer;
    fId: integer;
    fIsError: boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const aId, aRequestCount: integer); reintroduce;
    destructor Destroy; override;
    property IsError: boolean read fIsError;
  end;

{ TDDDThreadsTestRest }

{$ifndef DELPHI5OROLDER}

function TDDDThreadsTestRest.SelectByDescription(const aDescription: RawUTF8): TCQRSResult;
begin
  result := ORMSelectOne('Description=?', [aDescription], (aDescription = ''));
end;

function TDDDThreadsTestRest.SelectAll: TCQRSResult;
begin
  result := ORMSelectAll('', []);
end;

function TDDDThreadsTestRest.Get(out aAggregate: TDDDTest): TCQRSResult;
begin
  result := ORMGetAggregate(aAggregate);
end;

function TDDDThreadsTestRest.GetAll(out aAggregates: TDDDTestObjArray): TCQRSResult;
begin
  result := ORMGetAllAggregates(aAggregates);
end;

function TDDDThreadsTestRest.GetNext(out aAggregate: TDDDTest): TCQRSResult;
begin
  result := ORMGetNextAggregate(aAggregate);
end;

function TDDDThreadsTestRest.Add(const aAggregate: TDDDTest): TCQRSResult;
begin
  result := ORMAdd(aAggregate);
end;

function TDDDThreadsTestRest.Update(const aUpdatedAggregate: TDDDTest): TCQRSResult;
begin
  result := ORMUpdate(aUpdatedAggregate);
end;

{ TInfraRepoUserFactory }

constructor TDDDThreadsTestRestFactory.Create(aRest: TSQLRest; aOwner: TDDDRepositoryRestManager);
begin
  inherited Create(IDDDThreadsCommand, TDDDThreadsTestRest, TDDDTest, aRest, TSQLRecordDDDTest, aOwner);
end;


{ TTestDDDMultiThread }

procedure TTestDDDMultiThread.CleanUp;
begin
  if Assigned(fHttpServer) then
    FreeAndNil(fHttpServer);
  if Assigned(fRestServer) then
    FreeAndNil(fRestServer);
end;

procedure TTestDDDMultiThread.DeleteOldDatabase;
begin
  if FileExists(ChangeFileExt(ParamStr(0), '.db3')) then
    SysUtils.DeleteFile(ChangeFileExt(ParamStr(0), '.db3'));
  CheckNot(FileExists(ChangeFileExt(ParamStr(0), '.db3')));
end;

procedure TTestDDDMultiThread.StartServer;
begin
  fRestServer := TRestServerDB.CreateWithOwnModel([TSQLRecordDDDTest], ChangeFileExt(ParamStr(0), '.db3'), true);
  with fRestServer do begin
    DB.Synchronous := smNormal;
    DB.LockingMode := lmExclusive;
    CreateMissingTables();
//    TInterfaceFactory.RegisterInterfaces([TypeInfo(IDDDThreadsQuery), TypeInfo(IDDDThreadsCommand)]);
    ServiceContainer.InjectResolver([TDDDThreadsTestRestFactory.Create(fRestServer)], true);
    ServiceDefine(TDDDThreadsTestRest, [IDDDThreadsCommand], sicClientDriven);
  end;
  fHttpServer := TSQLHttpServer.Create(HTTP_DEFAULTPORT, fRestServer, '+',
    {$ifdef ONLYUSEHTTPSOCKET}useHttpSocket{$else}useHttpApiRegisteringURI{$endif});
  Check(fHttpServer.DBServerCount>0);
end;

procedure TTestDDDMultiThread.MultiThreadedClientsTest;
begin
  // TODO: This test still needs to be converted from version 1.18
  //ClientTest(20, 50);
end;

procedure TTestDDDMultiThread.SingleClientTest;
var
  HttpClient: TDDDThreadsHttpClient;
  test: TDDDTest;
  i: integer;
  MyCommand: IDDDThreadsCommand;
  Model: TSQLModel;
const
  MAX = 1000;
begin
  Model := TSQLModel.Create([TSQLRecordDDDTest]);
  Model.Owner := self;
  HttpClient := TDDDThreadsHttpClient.Create('127.0.0.1', HTTP_DEFAULTPORT, Model);
  try
    Check(HttpClient.SetUser('User', 'synopse'));
    Check(HttpClient.ServiceDefine([IDDDThreadsCommand], sicClientDriven));
    HttpClient.Services.Resolve(IDDDThreadsCommand, MyCommand);
    HttpClient.fMyCommand := MyCommand;
    test := TDDDTest.Create;
    try
      for i := 0 to MAX - 1 do begin
        test.Description := FormatUTF8('test-%', [i]);
        Check(HttpClient.MyCommand.Add(test) = cqrsSuccess);
      end;
      Check(HttpClient.MyCommand.Commit = cqrsSuccess);
      MyCommand := nil;
    finally
      test.Free;
    end;
  finally
    HttpClient.Free;
  end;
  Model.Free;
end;

function TTestDDDMultiThread.ClientTest(const aClients, aRequests: integer): boolean;
var
  i,count: integer;
  arrThreads: array of TDDDThreadsThread;
  {$ifdef MSWINDOWS}
  arrHandles: array of THandle;
  {$endif}
  rWait: Cardinal;
begin
  result := false;
  count := fRestServer.TableRowCount(TSQLRecordDDDTest);
  SetLength(arrThreads, aClients);
  {$ifdef MSWINDOWS}
  SetLength(arrHandles, aClients);
  {$endif}
  for i := Low(arrThreads) to High(arrThreads) do begin
    arrThreads[i] := TDDDThreadsThread.Create(i, aRequests);
    {$ifdef MSWINDOWS}
    arrHandles[i] := arrThreads[i].Handle;
    {$endif}
    arrThreads[i].Start;
  end;
  try
    {$ifdef MSWINDOWS}
    repeat
      rWait := WaitForMultipleObjects(aClients, @arrHandles[0], True, INFINITE);
    until rWait <> WAIT_TIMEOUT;
    {$else}
    repeat
      Sleep(10);
      rWait := 0;
      for i := Low(arrThreads) to High(arrThreads) do
        if not arrThreads[i].Terminated then
          inc(rWait);
    until rWait=0;
    {$endif}
  finally
    for i := Low(arrThreads) to High(arrThreads) do begin
      CheckNot(arrThreads[i].IsError);
      arrThreads[i].Free;
    end;
    Check(fRestServer.TableRowCount(TSQLRecordDDDTest)=count+aClients*aRequests);
  end;
end;

{ TDDDThreadsHttpClient }

(*
constructor TDDDThreadsHttpClient.Create(const aServer, aPort: AnsiString);
begin
  fModel := TSQLModel.Create([TSQLRecordDDDTest]);
  fModel.Owner := self;
  inherited Create(aServer, aPort, fModel);
end;
*)

destructor TDDDThreadsHttpClient.Destroy;
begin
  fMyCommand := nil;
  inherited;
end;

(*
function TDDDThreadsHttpClient.SetUser(const aUserName, aPassword: RawUTF8; aHashedPassword: Boolean = false): boolean;
begin
  result := inherited SetUser(aUserName, aPassword, aHashedPassword);
  if result then begin
    ServiceDefine([IDDDThreadsCommand], sicClientDriven);
    Services.Resolve(IDDDThreadsCommand, fMyCommand);
  end;
end;
*)

{ TDDDThreadsThread }

constructor TDDDThreadsThread.Create(const aID, aRequestCount: integer);
var
  Model: TSQLModel;
begin
  inherited Create(true);
  fRequestCount := aRequestCount;
  fId := aId;
  fIsError := false;
  Model := TSQLModel.Create([TSQLRecordDDDTest]);
  Model.Owner := self;
  fHttpClient := TDDDThreadsHttpClient.Create('127.0.0.1', HTTP_DEFAULTPORT, Model);
end;

destructor TDDDThreadsThread.Destroy;
begin
  fHttpClient.Free;
  inherited;
end;

procedure TDDDThreadsThread.Execute;
var
  i: integer;
  test: TDDDTest;
  success: boolean;
begin
  fHttpClient.SetUser('Admin', 'synopse');
  for i := 1 to 150 {15000} do
    fHttpClient.ServerTimestampSynchronize; // calls root/timestamp
  test := TDDDTest.Create;
  try
    success := true;
    i := fRequestCount; // circumvent weird FPC bug on ARM
    while i>0 do begin
      test.Description := FormatUTF8('test-%-%', [fID, i]);
      success := success and (fHttpClient.MyCommand.Add(test) = cqrsSuccess);
      if not success then
        break;
      dec(i);
    end;
    if success then
      success := fHttpClient.MyCommand.Commit = cqrsSuccess;
    if not success then begin
      fIsError := true;
      raise Exception.Create('Something went wrong!');
    end;
  finally
    test.Free;
    Terminate;
  end;
end;


{$endif DELPHI5OROLDER}

initialization
  TInterfaceFactory.RegisterInterfaces([TypeInfo(IDDDThreadsQuery)]);
  TInterfaceFactory.RegisterInterfaces([TypeInfo(IDDDThreadsCommand)]);

end.
