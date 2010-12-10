unit KM_UnitTaskAttackHouse;
{$I KaM_Remake.inc}
interface
uses Classes, KM_CommonTypes, KM_Defaults, KM_Utils, KM_Houses, KM_Units, KM_Units_Warrior, KromUtils, SysUtils;

{Attack a house}
type
  TTaskAttackHouse = class(TUnitTask)
    private
      fHouse:TKMHouse;
      fDestroyingHouse:boolean; //House destruction in progress
      fFightType:TFightType;
      LocID:byte; //Current attack location
      CellsW:TKMPointList; //List of cells within
    public
      constructor Create(aWarrior: TKMUnitWarrior; aHouse:TKMHouse);
      constructor Load(LoadStream:TKMemoryStream); override;
      procedure SyncLoad(); override;
      destructor Destroy; override;
      property DestroyingHouse:boolean read fDestroyingHouse;
      function WalkShouldAbandon:boolean; override;
      function Execute():TTaskResult; override;
      procedure Save(SaveStream:TKMemoryStream); override;
    end;


implementation
uses KM_Game, KM_PlayersCollection, KM_Terrain;


{ TTaskAttackHouse }
constructor TTaskAttackHouse.Create(aWarrior: TKMUnitWarrior; aHouse:TKMHouse);
begin
  Inherited Create(aWarrior);
  fTaskName := utn_AttackHouse;
  fHouse := aHouse.GetHousePointer;
  fDestroyingHouse := false;
  fFightType := aWarrior.GetFightType;
  LocID  := 0;
  CellsW  := TKMPointList.Create; //Pass pre-made list to make sure we Free it in the same unit
  if fFightType = ft_Ranged then fHouse.GetListOfCellsWithin(CellsW);
end;


constructor TTaskAttackHouse.Load(LoadStream:TKMemoryStream);
begin
  Inherited;
  LoadStream.Read(fHouse, 4);
  LoadStream.Read(fDestroyingHouse);
  LoadStream.Read(fFightType, SizeOf(fFightType));
  LoadStream.Read(LocID);
  CellsW := TKMPointList.Load(LoadStream);
end;


procedure TTaskAttackHouse.SyncLoad();
begin
  Inherited;
  fHouse := fPlayers.GetHouseByID(cardinal(fHouse));
end;


destructor TTaskAttackHouse.Destroy;
begin
  fPlayers.CleanUpHousePointer(fHouse);
  FreeAndNil(CellsW);
  Inherited;
end;


function TTaskAttackHouse.WalkShouldAbandon:boolean;
begin
  Result := fHouse.IsDestroyed;
end;


function TTaskAttackHouse.Execute():TTaskResult;
begin
  Result := TaskContinues;

  //If the house is destroyed drop the task
  if fHouse.IsDestroyed then
  begin
    Result := TaskDone;
    //Commander should reposition his men after destroying the house
    if TKMUnitWarrior(fUnit).fCommander = nil then
      TKMUnitWarrior(fUnit).PlaceOrder(wo_Walk,fUnit.GetPosition); //Don't use halt because that returns us to fOrderLoc
    exit;
  end;

  with fUnit do
  case fPhase of
    0: begin
         if fFightType=ft_Ranged then
           SetActionWalkToHouse(fHouse, RANGE_BOWMAN div (byte(REDUCE_SHOOTING_RANGE)*2))
         else
           SetActionWalkToHouse(fHouse, 1)
       end;
    1: if fFightType=ft_Ranged then begin
         SetActionLockedStay(Random(8),ua_Work,true); //Pretend to aim
         Direction := KMGetDirection(GetPosition, fHouse.GetEntrance); //Look at house
       end else begin
         SetActionLockedStay(0,ua_Work,false); //@Lewin: Maybe melee units can randomly pause for 1-2 frames as well?
         Direction := KMGetDirection(GetPosition, fHouse.GetEntrance); //Look at house
       end;
    2: begin
         if fFightType=ft_Ranged then begin
           SetActionLockedStay(4,ua_Work,false,0,0); //Start shooting
           fDestroyingHouse := true;
         end else begin
           SetActionLockedStay(6,ua_Work,false,0,0); //Start the hit
           fDestroyingHouse := true;
         end;
       end;
    3: begin
         if fFightType=ft_Ranged then begin //Launch the missile and forget about it
           //Shooting range is not important now, houses don't walk (except Howl's Moving Castle perhaps)
           fGame.fProjectiles.AddItem(PositionF, KMPointF(CellsW.GetRandom), pt_Arrow); //Release arrow/bolt
           SetActionLockedStay(24,ua_Work,false,0,4); //Reload for next attack
           //Bowmen/crossbowmen do 1 damage per shot and occasionally miss altogether
           fPhase := 0; //Go for another shot (will be 1 after inc below)
         end else begin
           SetActionLockedStay(6,ua_Work,false,0,6); //Pause for next attack
           fHouse.AddDamage(2); //All melee units do 2 damage per strike
           fPhase := 1; //Go for another hit (will be 2 after inc below)
         end;
       end;
  end;

  inc(fPhase);
end;


procedure TTaskAttackHouse.Save(SaveStream:TKMemoryStream);
begin
  Inherited;
  if fHouse <> nil then
    SaveStream.Write(fHouse.ID) //Store ID
  else
    SaveStream.Write(Zero);
  SaveStream.Write(fDestroyingHouse);
  SaveStream.Write(fFightType, SizeOf(fFightType));
  SaveStream.Write(LocID);
  CellsW.Save(SaveStream);
end;


end.
