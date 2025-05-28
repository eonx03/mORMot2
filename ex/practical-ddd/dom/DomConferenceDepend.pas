/// Conference Domain dependencies interface definition
unit DomConferenceDepend;

interface

uses
  SysUtils,
  Classes,
  mormot.core.base,
  DomConferenceTypes;

type
  TBookingRepositoryError = (
    brSuccess, brDuplicatedInfo, brWriteFailure);

  IBookingRepository = interface(IInvokable)
    ['{8E121C97-7E53-4208-BE05-1660EAD8AB43}']
    function SaveNewRegistration(const Attendee: TAttendee; const Days: TSessionDays;
      out RegistrationNumber: TAttendeeRegistrationNumber): TBookingRepositoryError;
    function RetrieveRegistration(const Name: TAttendeeName;
      const FirstName: TAttendeeFirstName; out Days: TSessionDays;
      out Attendee: TAttendee): boolean;
  end;

implementation

uses
  mormot.core.interfaces,
  mormot.orm.base;

initialization
  TJSONSerializer.RegisterObjArrayForJSON([
    ]);
  TInterfaceFactory.RegisterInterfaces([
    TypeInfo(IBookingRepository)
    ]);
end.
