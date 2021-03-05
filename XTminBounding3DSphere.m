%% Imaris XTension - Minimun 3D Bounding Sphere
%
% This function evaluates the minimun 3D bounding sphere from 3D
% coordinates placed using spots tool in Imaris. The function incorporates 
% Exact Minimum Bounding Sphere algorithms developed by Anton Semechko in MATLAB code.   
%
% Lloyd Hamilton 2016-07-28
% University Of Edinburgh
% Email : S0973826@sms.ed.ac.uk
% 
% <CustomTools>
%   <Menu>
%       <Submenu name="Custom Scripts">
%       <Item name="Minimun Bounding 3D Sphere" icon="Matlab">
%          <Command>MatlabXT::XTminBounding3DSphere(%i)</Command>
%       </Item>
%       </Submenu>
%   </Menu>
%       <SurpassTab>
%        <SurpassComponent name="bpSpots">
%         <Item name="MinBounding3DSphere" icon="Matlab">
%          <Command>MatlabXT::XTminBounding3DSphere(%i)</Command>
%        </Item>
%       </SurpassComponent>
%      </SurpassTab>
% </CustomTools>
%
%REREFERENCES:
% [1] Welzl, E. (1991), 'Smallest enclosing disks (balls and ellipsoids)',
%     Lecture Notes in Computer Science, Vol. 555, pp. 359-370
%
% [2] Exact Minimum Bounding Sphere algorithm developed by Anton Semechko,
%     11 Dec 2014.
%     Link : https://www.mathworks.com/matlabcentral/fileexchange/48725-exact-minimum-bounding-spheres-circles
% 
%
%

function XTminBounding3DSphere(aImarisApplicationID)
%% Imaris initialisation. 

function anObjectID = GetObjectID
    vServer = vImarisLib.GetServer;
    vNumberOfObjects = vServer.GetNumberOfObjects;
    anObjectID = vServer.GetObjectID(vNumberOfObjects - 1);
end

% Connection to an instance of Imaris.
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
    javaaddpath ImarisLib.jar;
    vImarisLib = ImarisLib;
    vImarisApplication = vImarisLib.GetApplication(GetObjectID);
else
    vImarisApplication = aImarisApplicationID;
end

%% Absent spots error catching.

% Get currently selected spot
vCurrentSurpassSelection = vImarisApplication.GetSurpassSelection;
vSpots = vImarisApplication.GetFactory.ToSpots(vCurrentSurpassSelection);
vSurpassScene = vImarisApplication.GetSurpassScene;
vSpotLogical = 0;

if isequal(vSurpassScene, [])
  errordlg('Please load an image','Error!','modal');
  return;
end

% If no spot was selected request user selection.
if isequal(vCurrentSurpassSelection, [])
    vSpotNames = {};
    vIndexPosition = [];
   
    for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
        vDataItem = vSurpassScene.GetChild(vChildIndex - 1);
        if vImarisApplication.GetFactory.IsSpots(vDataItem)
            vObjectName = vDataItem.GetName;
            % Convert Java string to char.
            vSpotNames = [vSpotNames,{char(vObjectName)}];
            vIndexPosition = [vIndexPosition,vChildIndex];
            vSpotLogical = 1;
        end
    end
    
    if isequal(vSpotLogical, 1)
        [vUserselection,vOk] = listdlg('PromptString','Select spot:',...
                                       'SelectionMode','single',...
                                       'ListSize',[350 100],...
                                       'Name','Evaluate Minimium Bounding Sphere',...
                                       'ListString',vSpotNames);      
        if vOk < 1 || isequal(vUserselection, {})
            return;
        end
        
    end
    
end

% Error diaglog if non spot object was selected.
if ~vImarisApplication.GetFactory.IsSpots(vCurrentSurpassSelection) && vSpotLogical < 1
    errordlg('Please select a spot!','Spot selection error','modal');
    return
end

%% Evaluate XYZ position of ExactMinBoundingSpehere3D
% 
function [Radius, Center] = fGetSpotPositions(vSpot)
    vSpotValue = vSpot.Get;
    waitbar(1/5)
    vPosition = vSpotValue.mPositionsXYZ;
    waitbar(2/5)
    xyzCords = double(vPosition);
    waitbar(3/5)
    [Radius , Center] = ExactMinBoundSphere3D(xyzCords);
end
         
if vImarisApplication.GetFactory.IsSpots(vSpots)
    vProgressDisplay = waitbar(0, 'Please Wait...');
    try
        [R , C] = fGetSpotPositions(vSpots);
    catch ME 
        if (strcmp(ME.identifier,'MATLAB:cgprechecks:NotEnoughPts'))
            errordlg('Not enough unique points, please create more spots!','Error','modal');
            close(vProgressDisplay)
            return
        end
        rethrow(ME)  
        
    end
    waitbar(4/5)
    vOk = 0; %Skip next if statement
end

if isequal(vOk,1)
   vProgressDisplay = waitbar(0, 'Please Wait...');
   %Imaris indexing begins from 0
   vDataItem = vSurpassScene.GetChild(vIndexPosition(1,vUserselection)-1); 
   vSpots = vImarisApplication.GetFactory.ToSpots(vDataItem);
   try
        [R , C] = fGetSpotPositions(vSpots);
    catch ME 
        if (strcmp(ME.identifier,'MATLAB:cgprechecks:NotEnoughPts'))
            errordlg('Not enough unique points, please create more spots!','Error','modal');
            close(vProgressDisplay);
            return
        end
        rethrow(ME);    
    end
   waitbar(4/5);
end 

%% Generate new Spot object in Imaris 
vNewSpot = vImarisApplication.GetFactory.CreateSpots;
vNewSpot.Set(C,0,R);

if vImarisApplication.GetFactory.IsSpots(vCurrentSurpassSelection)    
    vNewSpotName = {char(vCurrentSurpassSelection.GetName),'Min Bounding Sphere'};
end

if ~vImarisApplication.GetFactory.IsSpots(vCurrentSurpassSelection)
    vNewSpotName = {char(vSpots.GetName),'Min Bounding Sphere'};
end

vNewSpot.SetName(strjoin(vNewSpotName));
vImarisApplication.GetSurpassScene.AddChild(vNewSpot,1);
vSelection = vSurpassScene.GetChild(1);
vRed = 0.9;
vGreen = 0.9;
vBlue = 0.0;
vAlpha = 0.5;
vRGBA = [vRed, vGreen, vBlue, vAlpha];
vRGBA = round(vRGBA * 255);
vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
vSelection.SetColorRGBA(vRGBA);
waitbar(5/5);
close(vProgressDisplay);
%% Create dialog box of invasiveness read out
end
