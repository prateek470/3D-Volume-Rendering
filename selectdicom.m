function [id,name] = selectdicom(varargin)
if(strcmp(varargin{1},'press'))
   handles=guihandles;
   id=get(handles.listbox1,'Value');
   setMyData(id);
   uiresume
   return
end

handles.figure1=figure;
c=varargin{1};
set(handles.figure1,'tag','figure1','Position',[520 528 348 273],'MenuBar','none','name',varargin{2});
handles.listbox1=uicontrol('tag','listbox1','Style','listbox','Position',[12 36 319 226],'String', c);
handles.pushbutton1=uicontrol('tag','pushbutton1','Style','pushbutton','Position',[16 12 69 22],'String','Select','Callback','selectdicom(''press'');');
uiwait(handles.figure1);
id=getMyData();
name=c{id};
close(handles.figure1);

function setMyData(data)
% Store data struct in figure
setappdata(gcf,'data3d',data);

function data=getMyData()
% Get data struct stored in figure
data=getappdata(gcf,'data3d');

