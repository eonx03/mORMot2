program TestAll_d28;

uses
  mormot.core.base,
  mormot.core.log,
  mormot.core.test,
  mormot.db.raw.sqlite3.static,
  mORMotDDD2 in '..\fwrk\mORMotDDD2.pas',
  dddInfraAuthRest in '..\infra\dddInfraAuthRest.pas',
  dddInfraEmailer in '..\infra\dddInfraEmailer.pas',
  dddInfraEmail in '..\infra\dddInfraEmail.pas',
  dddInfraRepoUser in '..\infra\dddInfraRepoUser.pas',
  dddDomAuthInterfaces in '..\dom\dddDomAuthInterfaces.pas',
  dddDomCountry in '..\dom\dddDomCountry.pas',
  dddDomUserTypes in '..\dom\dddDomUserTypes.pas',
  dddDomUserInterfaces in '..\dom\dddDomUserInterfaces.pas',
  dddDomUserCQRS in '..\dom\dddDomUserCQRS.pas',
  DDDSelfTests in 'DDDSelfTests.pas',
  DomConferenceTypes in '..\dom\DomConferenceTypes.pas',
  DomConferenceInterfaces in '..\dom\DomConferenceInterfaces.pas',
  DomConferenceDepend in '..\dom\DomConferenceDepend.pas',
  DomConferenceServices in '..\dom\DomConferenceServices.pas',
  DomConferenceTest in '..\dom\DomConferenceTest.pas',
  InfraConferenceRepository in '..\infra\InfraConferenceRepository.pas',
  ServBookMain in '..\serv\ServBookMain.pas',
  ServBookTest in '..\serv\ServBookTest.pas',
  TestAllMain in 'TestAllMain.pas';

begin
//  TSynLogTestLog := TSQLLog; // share the same log file with the whole mORMot
  TTestEKON.RunAsConsole('EKON Automated Tests', LOG_VERBOSE);
end.
