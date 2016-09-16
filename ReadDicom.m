function varargout = ReadDicom(varargin)
gui_Singleton = 0;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @ReadDicom_OpeningFcn, ...
    'gui_OutputFcn',  @ReadDicom_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if (nargin>2) && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end

function ReadDicom_OpeningFcn(hObject, eventdata, handles, varargin)
handles.output = hObject;
guidata(hObject, handles);
% DICOM format is supported for viewing the dicom lung images
data.fileformat(1).ext='*.dcm';
data.fileformat(1).type='DICOM';
data.fileformat(1).folder='dicom image support';
data.fileformat(1).functioninfo='dicom1';
data.fileformat(1).functionread='dicom2';
% Get path of ReadDicom
functionname='ReadDicom.m';
functiondir=which(functionname);
functiondir=functiondir(1:end-length(functionname));
% Add the file-reader functions also to the matlab path
addpath([functiondir '/subfunctions']);
for i=1:length(data.fileformat), addpath([functiondir '/' data.fileformat(i).folder]); end
% Make popuplist file formats
fileformatcell=cell(1,length(data.fileformat));
for i=1:length(data.fileformat), fileformatcell{i}=[data.fileformat(i).type '   (' data.fileformat(i).ext ')']; end
% set(handles.popupmenu_format,'String',fileformatcell);
% Check if last filename is present from a previous time
data.configfile=[functiondir '/lastfile.mat'];
filename='';
fileformatid=1;
if(exist(data.configfile,'file')), load(data.configfile); end
data.handles=handles;
data.lastfilename=[];
data.volume=[];
data.info=[];
% If filename is selected, look if the extention is known
found=0;
if(~isempty(varargin))
    filename=varargin{1}; [pathstr,name,ext]=fileparts(filename);
    for i=1:length(data.fileformat)
        if(strcmp(data.fileformat(i).ext(2:end),ext)), found=1; fileformatid=i; end
    end
end
% Rescale the databack to original units.
if(length(varargin)>1), real=varargin{2}; else real=true; end
  
data.real=real;
data.filename=filename;
data.fileformatid=fileformatid;
% set(handles.checkbox_real,'Value',data.real);
set(handles.edit_filename,'String',data.filename)
% set(handles.popupmenu_format,'Value',data.fileformatid);
% Store all data
setMyData(data);
if(found==0)
    % Show Dialog File selection
    uiwait(handles.figure1);
else
    % Load the File directly
    loaddata();
end
% --- Outputs from this function are returned to the command line.
function varargout = ReadDicom_OutputFcn(hObject, eventdata, handles)
if(ishandle(hObject))
    data=getMyData();
else
    data=[];
end
if(~isempty(data))
    varargout{1} = data.volume;
    varargout{2} = data.info;
else
    varargout{1}=[];
    varargout{2}=[];
end
if(ishandle(hObject))
    close(hObject)
end
function edit_filename_Callback(hObject, eventdata, handles)
function edit_filename_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','Blue');
end
function pushbutton_browse_Callback(hObject, eventdata, handles)
data=getMyData();
[extlist extlistid]=FileDialogExtentionList(data);
[filename, dirname,filterindex] = uigetfile(extlist, 'Select a dicom file',fileparts(data.filename));
if(filterindex>0)
    if(extlistid(filterindex)~=0)
        data.fileformatid=extlistid(filterindex);
%         set( handles.popupmenu_format,'Value',data.fileformatid);
    end
    if(filename==0), return; end
    filename=[dirname filename];
    data.filename=filename;
    setMyData(data);
    set(handles.edit_filename,'String',data.filename)
end

function [extlist extlistid]=FileDialogExtentionList(data)
extlist=cell(length(data.fileformat)+1,2);
extlistid=zeros(length(data.fileformat)+1,1);
ext=data.fileformat(data.fileformatid).ext;
type=data.fileformat(data.fileformatid).type;
extlistid(1)=data.fileformatid;
extlist{1,1}=ext; extlist{1,2}=[type ' (' ext ')'];
j=1;
for i=1:length(data.fileformat);
    if(i~=data.fileformatid)
        j=j+1;
        ext=data.fileformat(i).ext;
        type=data.fileformat(i).type;
        extlistid(j)=i;
        extlist{j,1}=ext; extlist{j,2}=[type ' (' ext ')'];
    end
end
extlist{end,1}='*.*';
extlist{end,2}='All Files (*.*)';

function setMyData(data)
% Store data struct in figure
setappdata(gcf,'dataload3d',data);
function data=getMyData()
% Get data struct stored in figure
data=getappdata(gcf,'dataload3d');
function pushbutton_cancel_Callback(hObject, eventdata, handles)
setMyData([]);
uiresume;
function pushbutton_load_Callback(hObject, eventdata, handles)
data=getMyData();
data.filename=get(handles.edit_filename,'string');
loaddata();
pause(0.1);
uiresume
function loaddata()
data=getMyData();
set(data.handles.figure1,'Pointer','watch'); drawnow('expose');
if(~strcmp(data.lastfilename,data.filename))
    fhandle = str2func( data.fileformat(data.fileformatid).functioninfo);
    data.info=feval(fhandle,data.filename);
    data.lastfilename=data.filename;
end
fhandle = str2func( data.fileformat(data.fileformatid).functionread);
data.volume=feval(fhandle,data.info);
if(data.real)
    data.volume=single(data.volume);
    if(isfield(data.info,'RescaleSlope')), 
        data.volume=data.volume*data.info.RescaleSlope;
    else
        disp('RescaleSlope not available, assuming 1')
    end
    if(isfield(data.info,'RescaleIntercept')), 
        data.volume=data.volume+data.info.RescaleIntercept; 
    else
        disp('RescaleIntercept not available, assuming 0')
    end
end
setMyData(data);
set(data.handles.figure1,'Pointer','arrow')
filename=data.filename; fileformatid=data.fileformatid;
try save(data.configfile,'filename','fileformatid'); catch ME; disp(ME.message); end
function pushbutton_load_DeleteFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function text1_CreateFcn(hObject, eventdata, handles)
