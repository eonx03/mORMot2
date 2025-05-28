unit TestAllMain;

interface

uses
  mormot.core.base,
  mormot.core.test,
  DDDSelfTests,
  DomConferenceTest,
  ServBookTest;

type
  TTestEkon = class(TSynTestsLogged)
  published
    procedure DDDSharedUnits;
    procedure Infrastructure;
    procedure Domain;
    procedure Applications;
  end;

implementation

{ TTestEkon }

procedure TTestEkon.DDDSharedUnits;
begin
  AddCase([TTestDDDSharedUnits
  ,TTestDDDMultiThread
  ]);
end;

procedure TTestEkon.Infrastructure;
begin

end;

procedure TTestEkon.Domain;
begin
  AddCase([TTestConference]);
end;

procedure TTestEkon.Applications;
begin
  AddCase([TTestBookingApplication]);
end;

end.