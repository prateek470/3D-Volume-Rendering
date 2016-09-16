% ECiitkgpMatlab3Dview make Axial, Sagitaal and coronal views of the Dicom
% slices as well as a 3D view is shown...........pseudo color image
% processing is also included for better visualization......it uses
% shear-warp algorithm as it is fast but the image quality is little
% low.......as matlab is not a very fast software this algo is decided to
% get implemented.
function varargout = ECiitkgpMatlab3DView(varargin)
gui_Singleton = 0;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ECiitkgpMatlab3DView_OpeningFcn, ...
                   'gui_OutputFcn',  @ECiitkgpMatlab3DView_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% as soon as gui opens the below function gets executed :)
function ECiitkgpMatlab3DView_OpeningFcn(hObject, eventdata, handles, varargin)
handles.output = hObject;
guidata(hObject, handles);
% finction directory will give the information where the main files are
% located
fcndirectory=mainfiles();
% in the menu see the first line of GUI
data.Menu=firstlineofgui(hObject);
for i=1:length(data.Menu)
    z2=data.Menu(i);
    data.handles.(z2.Tag)=z2.Handle;
    if(isfield(z2,'Children')&&~isempty(z2.Children))
        for j=1:length(z2.Children)
            z3=z2.Children(j);
            data.handles.(z3.Tag)=z3.Handle;
        end
    end
end
data.handles.figure1=hObject;
data.mouse.pressed=false;
data.mouse.button='arrow';
 data.mouse.action='';
filename_config=[fcndirectory '/default_config.mat'];
if(exist(filename_config,'file'))
    load(filename_config,'config')
    data.config=config;
else
    data.config.VolumeScaling=100;
    data.config.VolumeSize=50;
    data.config.ImageSizeRender=300;
    data.config.PreviewVolumeSize=32;
    data.config.ShearInterpolation= 'bilinear';
    data.config.WarpInterpolation= 'bilinear';
    data.config.PreRender= 0;
    data.config.StoreXYZ=0;
end
% child processes of the GUI after volume rendering........remove low contrast 3D view after
% showing it to Sir
data.rendertypes(1).label='Axial View';
data.rendertypes(1).type='slicez';
data.rendertypes(2).label='Sagittal View';
data.rendertypes(2).type='slicey';
data.rendertypes(3).label='Coronal View';
data.rendertypes(3).type='slicex';
% data.rendertypes(4).label='Low contrast 3D view';
% data.rendertypes(4).type='volume rendering';
data.rendertypes(4).label='3D View';
data.rendertypes(4).type='volumerendering';

data.figurehandles.ECiitkgpMatlab3DView=gcf;
 data.figurehandles.graylevel=[];
 data.figurehandles.console=[];
 data.figurehandles.voxelsize=[];
 data.figurehandles.speed=[];
data.volumes=[];
data.substorage=[];
data.axes_select=[];
data.volume_select=[];
data.subwindow=[];
data.MenuVolume=[];

data.NumberWindows=1;
data=addWindows(data);
setMyData(data);
allshow3d(false,true);

if (~isempty(varargin)), 
    if(ndims(varargin{1})>=2)
        for i=1:length(varargin);
            V=varargin{i};
            volumemax=double(max(V(:))); volumemin=double(min(V(:)));
            info=struct;
            info.WindowWidth=volumemax-volumemin;
            info.WindowLevel=0.5*(volumemax+volumemin);     

            if(isnumeric(V)), addVolume(V,[1 1 1],info); end
        end
    else
        error('ECiitkgpMatlab3DView:inputs', 'Input image not 3 dimensional');
    end
end

function addVolume(V,Scales,Info,Editable)
if(nargin<2), Scales=[1 1 1]; end
if(nargin<3), Info=[]; end
if(nargin<4), Editable=false; end
data=getMyData(); if(isempty(data)), return, end
for i=1:size(V,4)
    data=addOneVolume(data,V(:,:,:,i),Scales,Info,Editable);
end
data=menulineadding(data);
setMyData(data);
function data=addOneVolume(data,V,Scales,Info,Editable)
nv=length(data.volumes)+1;
data.volumes(nv).Editable=Editable; 
data.volumes(nv).WindowWidth=1; 
data.volumes(nv).WindowLevel=0.5; 
data.volumes(nv).volume_original=V;
data.volumes(nv).volume_scales=[1 1 1];
data.volumes(nv).info=Info;
data.volumes(nv).id=rand;
data.volumes(nv).Scales=Scales;
if(ndims(V)==2)
    data.volumes(nv).Size_original=[size(V) 1];
else
    data.volumes(nv).Size_original=size(V);
end

name=['Volume ' num2str(nv)];
while(~isempty(searchthestructure(data.volumes,'name',name)))
    name=['Volume ' num2str(round(rand*10000))];
end
data.volumes(nv).name=name;

data.volumes(nv).MeasureList=[];
data.volumes(nv).graylevel_pointselected=[];
data=checkvolumetype(data,nv);

data=makeVolumeXY(data,nv);
data=computeNormals(data,nv);
data=makePreviewVolume(data,nv);
data=makeRenderVolume(data,nv);
if(~isempty(Info)),
    if(isfield(Info,'WindowWidth'));
        data.volumes(nv).WindowWidth=Info.WindowWidth;
    end
    if (isfield(Info,'WindowCenter'));
        data.volumes(nv).WindowLevel=Info.WindowCenter;
    end
    if (isfield(Info,'WindowLevel'));
        data.volumes(nv).WindowLevel=Info.WindowLevel;
    end
end
data=grayscalepseudocolor(nv,data);
        


function data=makePreviewVolume(data,dvs)
if(data.config.PreviewVolumeSize==100)
    data.volumes(dvs).volume_preview=data.volumes(dvs).volume_original;
else
    t=data.config.PreviewVolumeSize;
    data.volumes(dvs).volume_preview=imresize3d(data.volumes(dvs).volume_original,[],[t t t],'linear');
end

if(ndims(data.volumes(dvs).volume_preview)==2)
    data.volumes(dvs).Size_preview=[size(data.volumes(dvs).volume_preview) 1];
else
    data.volumes(dvs).Size_preview=size(data.volumes(dvs).volume_preview);
end

% information where the main files are present or the functions directory
function fcndirectory=mainfiles()
functionname='ECiitkgpMatlab3DView.m';
fcndirectory=which(functionname);
fcndirectory=fcndirectory(1:end-length(functionname));

function data=makeRenderVolume(data,dvs)
if(data.config.VolumeScaling==100)
    data.volumes(dvs).volume=data.volumes(dvs).volume_original;
else
    data.volumes(dvs).volume=imresize3d(data.volumes(dvs).volume_original,data.config.VolumeScaling/100,[],'linear');
end
if(ndims(data.volumes(dvs).volume)==2)
    data.volumes(dvs).Size=[size(data.volumes(dvs).volume) 1];
else
    data.volumes(dvs).Size=size(data.volumes(dvs).volume);
end



function data=grayscalepseudocolor(i,data)
% This function creates a Matlab colormap and alphamap from the markers
if(nargin<2)
    data=getMyData(); if(isempty(data)), return, end
end
if(nargin>0), 
    dvs=i; 
else
    dvs=data.volume_select;
end
    check=~isfield(data.volumes(dvs),'graylevel_positions');
    if(~check), check=isempty(data.volumes(dvs).graylevel_positions); end
    if(check)
%         graylevel position normalized values
        data.volumes(dvs).graylevel_positions = [0 0.2 0.4 0.6 1];
        data.volumes(dvs).graylevel_positions= data.volumes(dvs).graylevel_positions*(data.volumes(dvs).volumemax-data.volumes(dvs).volumemin)+data.volumes(dvs).volumemin;
        data.volumes(dvs).graylevel_alpha = [0 0.03 0.1 0.35 1]; 
%         change the matrix to change the RGB values .......theory of
%         graylevel is covered in the report...........100-red
% 010 is green and 001 is blue
        data.volumes(dvs).graylevel_colors= [0 0 0; 1 1 1; 0 0 1; 1 0 0; 0 1 0];
        setMyData(data);
    end

    graylevel_positions=data.volumes(dvs).graylevel_positions;

    data.volumes(dvs).colortable=zeros(1000,3); 
    data.volumes(dvs).alphatable=zeros(1000,1);
    % Loop through all 256 color/alpha indexes
    
    i=linspace(data.volumes(dvs).volumemin,data.volumes(dvs).volumemax,1000);
    for j=1:1000
        if    (i(j)< graylevel_positions(1)),   alpha=0;                         color=data.volumes(dvs).graylevel_colors(1,:);
        elseif(i(j)> graylevel_positions(end)), alpha=0;                         color=data.volumes(dvs).graylevel_colors(end,:);
        elseif(i(j)==graylevel_positions(1)),   alpha=data.volumes(dvs).graylevel_alpha(1);   color=data.volumes(dvs).graylevel_colors(1,:);
        elseif(i(j)==graylevel_positions(end)), alpha=data.volumes(dvs).graylevel_alpha(end); color=data.volumes(dvs).graylevel_colors(end,:);
        else
            % Linear interpolate the color and alpha between markers
            index_down=find(graylevel_positions<=i(j)); index_down=index_down(end);
            index_up  =find(graylevel_positions>i(j) ); index_up=index_up(1);
            perc= (i(j)-graylevel_positions(index_down)) / (graylevel_positions(index_up) - graylevel_positions(index_down));
            color=(1-perc)*data.volumes(dvs).graylevel_colors(index_down,:)+perc*data.volumes(dvs).graylevel_colors(index_up,:);
            alpha=(1-perc)*data.volumes(dvs).graylevel_alpha(index_down)+perc*data.volumes(dvs).graylevel_alpha(index_up);
        end
        data.volumes(dvs).colortable(j,:)=color;
        data.volumes(dvs).alphatable(j)=alpha;
    end
if(nargin<2)
    setMyData(data);
end

function allshow3d(preview,render_new_image)
data=getMyData(); if(isempty(data)), return, end
for i=1:data.NumberWindows
    show3d(preview,render_new_image,i);
end

function show3d(preview,render_new_image,wsel)
data=getMyData(); if(isempty(data)), return, end
tic;
if(nargin<3)
    wsel=data.axes_select;
else
    data.axes_select=wsel;
end

dvss=searchthestructure(data.volumes,'id',data.subwindow(wsel).volume_id_select(1));
nvolumes=length(data.subwindow(wsel).volume_id_select);
if(isempty(dvss)), 
    data.subwindow(wsel).render_type='Red';
    datarender.RenderType='Red';
    datarender.ImageSize=[data.config.ImageSizeRender data.config.ImageSizeRender];
    datarender.imin=0; datarender.imax=1;
    renderimage = render(zeros(3,3,3),datarender);
    data.subwindow(wsel).render_image(1).image=renderimage;
else     
    if(render_new_image)
        for i=1:nvolumes
            dvss=searchthestructure(data.volumes,'id',data.subwindow(wsel).volume_id_select(i));
            data.subwindow(wsel).render_image(i).image=imageshow(data,dvss,wsel,preview);
        end
    end
    if(nvolumes==1), combine='trans'; else combine=data.subwindow(wsel).combine; end
    for i=1:nvolumes
         dvss=searchthestructure(data.volumes,'id',data.subwindow(wsel).volume_id_select(i));
         renderimage1=LevelRenderImage(data.subwindow(wsel).render_image(i).image,data,dvss,wsel);
         if(i==1)
             switch(combine)
                 case 'trans'
                    renderimage=renderimage1;
                 case 'rgb'
                    renderimage=zeros([size(renderimage1,1) size(renderimage1,2) 3]);
                    renderimage(:,:,i)=mean(renderimage1,3);
             end
         else
              switch(combine)
                 case 'trans'
                    renderimage=renderimage+renderimage1;
                 case 'rgb'
                    renderimage(:,:,i)=mean(renderimage1,3);
             end

         end
    end
    switch(combine)
        case 'trans'
         if(nvolumes>1), renderimage=renderimage*(1/nvolumes); end    
    end
end

    
data.subwindow(wsel).total_image=renderimage;

% Add slice number to the axial sagittal and coronal  image
% To range
data.subwindow(wsel).total_image(data.subwindow(wsel).total_image<0)=0;
data.subwindow(wsel).total_image(data.subwindow(wsel).total_image>1)=1;

if(data.subwindow(wsel).first_render)
    data.subwindow(wsel).imshow_handle=imshow(data.subwindow(wsel).total_image,'Parent',data.subwindow(wsel).handles.axes); drawnow('expose')
    data.subwindow(wsel).first_render=false;
else
    set(data.subwindow(wsel).imshow_handle,'Cdata',data.subwindow(wsel).total_image);
end

data.subwindow(wsel).axes_size=get(data.subwindow(wsel).handles.axes,'PlotBoxAspectRatio');

set(get(data.subwindow(wsel).handles.axes,'Children'),'ButtonDownFcn','ECiitkgpMatlab3DView(''axes_ButtonDownFcn'',gcbo,[],guidata(gcbo))');
data=console_addline(data,['Render Time : ' num2str(toc)]);

setMyData(data);

function renderimage=imageshow(data,dvss,wsel,preview)
datarender=struct();
datarender.ImageSize=[data.config.ImageSizeRender data.config.ImageSizeRender];
datarender.imin=data.volumes(dvss).volumemin;
datarender.imax=data.volumes(dvss).volumemax;
switch data.subwindow(wsel).render_type
% case 'volumerendering'
%     datarender.RenderType='blackandwhite';
%     datarender.AlphaTable=data.volumes(dvss).alphatable;
%     datarender.ShearInterp=data.config.ShearInterpolation;
%     datarender.WarpInterp=data.config.WarpInterpolation;
case 'volumerendering'
    datarender.RenderType='color';
    datarender.AlphaTable=data.volumes(dvss).alphatable;
    datarender.ColorTable=data.volumes(dvss).colortable;
    datarender.ShearInterp=data.config.ShearInterpolation;
    datarender.WarpInterp=data.config.WarpInterpolation;
case 'slicex'
    datarender.RenderType='slicex';
    datarender.ColorTable=data.volumes(dvss).colortable;
    datarender.SliceSelected=data.subwindow(wsel).SliceSelected(1);
    datarender.WarpInterp='bicubic';   
    datarender.ColorSlice=data.subwindow(data.axes_select).ColorSlice;
case 'slicey'
    datarender.RenderType='slicey';
    datarender.ColorTable=data.volumes(dvss).colortable;
    datarender.SliceSelected=data.subwindow(wsel).SliceSelected(2);
    datarender.WarpInterp='bicubic';  
    datarender.ColorSlice=data.subwindow(data.axes_select).ColorSlice;
case 'slicez'
    datarender.RenderType='slicez';
    datarender.ColorTable=data.volumes(dvss).colortable;
    datarender.SliceSelected=data.subwindow(wsel).SliceSelected(3);
    datarender.WarpInterp='bicubic'; 
    datarender.ColorSlice=data.subwindow(data.axes_select).ColorSlice;
case 'Red'
    datarender.RenderType='Red';
end

if(preview)
    switch data.subwindow(wsel).render_type
        case {'slicex','slicey','slicez'}
            datarender.WarpInterp='nearest';
            datarender.Mview=data.subwindow(wsel).viewer_matrix;
            renderimage = render(data.volumes(dvss).volume_original, datarender);
        otherwise
            R=ResizeMatrix(data.volumes(dvss).Size_preview./data.volumes(dvss).Size_original);
            datarender.Mview=data.subwindow(wsel).viewer_matrix*R;
            renderimage = render(data.volumes(dvss).volume_preview,datarender);
    end
else
    mouse_button_old=data.mouse.button;
    switch data.subwindow(wsel).render_type
        case {'slicex','slicey','slicez'}
            datarender.Mview=data.subwindow(wsel).viewer_matrix;
            renderimage = render(data.volumes(dvss).volume_original, datarender);
        case 'Red'
            renderimage = render(data.volumes(dvss).volume, datarender);
        otherwise
            datarender.Mview=data.subwindow(wsel).viewer_matrix*ResizeMatrix(data.volumes(dvss).Size./data.volumes(dvss).Size_original);
            datarender.VolumeX=data.volumes(dvss).volumex;
            datarender.VolumeY=data.volumes(dvss).volumey;
            datarender.Normals=data.volumes(dvss).normals;
            renderimage = render(data.volumes(dvss).volume, datarender);
    end
end


function renderimage=LevelRenderImage(renderimage,data,dvss,wsel)
if(~isempty(dvss))
    switch data.subwindow(wsel).render_type
        case {'mip','slicex', 'slicey', 'slicez'}
         
            if ((ndims(renderimage)==2)&&(data.volumes(dvss).WindowWidth~=0||data.volumes(dvss).WindowLevel~=0))
                m=(data.volumes(dvss).volumemax-data.volumes(dvss).volumemin)*(1/data.volumes(dvss).WindowWidth);
                o=(data.volumes(dvss).volumemin-data.volumes(dvss).WindowLevel)*(1/data.volumes(dvss).WindowWidth)+0.5;
                renderimage=renderimage*m+o;
            end
    end
end
    
function data=set_initial_view_matrix(data)
dvss=searchthestructure(data.volumes,'id',data.subwindow(data.axes_select).volume_id_select(1));

switch data.subwindow(data.axes_select).render_type
    case 'slicex'
        data.subwindow(data.axes_select).viewer_matrix=[data.volumes(dvss).Scales(1)*data.subwindow(data.axes_select).Zoom 0 0 0; 0 data.volumes(dvss).Scales(2)*data.subwindow(data.axes_select).Zoom 0 0; 0 0 data.volumes(dvss).Scales(3)*data.subwindow(data.axes_select).Zoom 0; 0 0 0 1];
        data.subwindow(data.axes_select).viewer_matrix=[0 0 1 0;0 1 0 0; -1 0 0 0;0 0 0 1]*data.subwindow(data.axes_select).viewer_matrix;
    case 'slicey'
        data.subwindow(data.axes_select).viewer_matrix=[data.volumes(dvss).Scales(1)*data.subwindow(data.axes_select).Zoom 0 0 0; 0 data.volumes(dvss).Scales(2)*data.subwindow(data.axes_select).Zoom 0 0; 0 0 data.volumes(dvss).Scales(3)*data.subwindow(data.axes_select).Zoom 0; 0 0 0 1];
        data.subwindow(data.axes_select).viewer_matrix=[1 0 0 0;0 0 -1 0; 0 1 0 0;0 0 0 1]*data.subwindow(data.axes_select).viewer_matrix;
    case 'slicez'
        data.subwindow(data.axes_select).viewer_matrix=[data.volumes(dvss).Scales(1)*data.subwindow(data.axes_select).Zoom 0 0 0; 0 data.volumes(dvss).Scales(2)*data.subwindow(data.axes_select).Zoom 0 0; 0 0 data.volumes(dvss).Scales(3)*data.subwindow(data.axes_select).Zoom 0; 0 0 0 1];
        data.subwindow(data.axes_select).viewer_matrix=data.subwindow(data.axes_select).viewer_matrix*[1 0 0 0;0 1 0 0; 0 0 1 0;0 0 0 1];
    otherwise
        data.subwindow(data.axes_select).viewer_matrix=[data.volumes(dvss).Scales(1)*data.subwindow(data.axes_select).Zoom 0 0 0; 0 data.volumes(dvss).Scales(2)*data.subwindow(data.axes_select).Zoom 0 0; 0 0 data.volumes(dvss).Scales(3)*data.subwindow(data.axes_select).Zoom 0; 0 0 0 1];
end

function varargout = ECiitkgpMatlab3DView_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;
function figure1_WindowButtonMotionFcn(hObject, eventdata, handles)
showthewindow('MotionFcn',gcf);
 
cursor_position_in_axes(hObject,handles);
data=getMyData(); if(isempty(data)), return, end
if(isempty(data.axes_select)), return, end
if(strcmp(data.subwindow(data.axes_select).render_type,'Red')), return; end

if((length(data.subwindow(data.axes_select).render_type)>5)&&strcmp(data.subwindow(data.axes_select).render_type(1:5),'slice'))
    data=mouseposition_to_voxelposition(data);
    setMyData(data);
end

if(data.mouse.pressed)
    switch(data.mouse.button)
    case 'rotate1'
        r1=-360*(data.subwindow(data.axes_select).mouse_position_last(1)-data.subwindow(data.axes_select).mouse_position(1));
        r2=360*(data.subwindow(data.axes_select).mouse_position_last(2)-data.subwindow(data.axes_select).mouse_position(2));
        R=RotationMatrix([r1 r2 0]);
        data.subwindow(data.axes_select).viewer_matrix=R*data.subwindow(data.axes_select).viewer_matrix;
        setMyData(data);
        show3d(true,true)
    case 'rotate2'
        r1=100*(data.subwindow(data.axes_select).mouse_position_last(1)-data.subwindow(data.axes_select).mouse_position(1));
        r2=100*(data.subwindow(data.axes_select).mouse_position_last(2)-data.subwindow(data.axes_select).mouse_position(2));
        if(data.subwindow(data.axes_select).mouse_position(2)>0.5), r1=-r1; end
        if(data.subwindow(data.axes_select).mouse_position(1)<0.5), r2=-r2; end
        r3=r1+r2;
        R=RotationMatrix([0 0 r3]);
        data.subwindow(data.axes_select).viewer_matrix=R*data.subwindow(data.axes_select).viewer_matrix;
        setMyData(data);
        show3d(true,true)
    case 'pan'
        t2=200*(data.subwindow(data.axes_select).mouse_position_last(1)-data.subwindow(data.axes_select).mouse_position(1));
        t1=200*(data.subwindow(data.axes_select).mouse_position_last(2)-data.subwindow(data.axes_select).mouse_position(2));
        M=TranslateMatrix([t1 t2 0]);
        data.subwindow(data.axes_select).viewer_matrix=M*data.subwindow(data.axes_select).viewer_matrix;
        setMyData(data);
        show3d(true,true)      
    case 'zoom'
        z1=1+2*(data.subwindow(data.axes_select).mouse_position_last(1)-data.subwindow(data.axes_select).mouse_position(1));
        z2=1+2*(data.subwindow(data.axes_select).mouse_position_last(2)-data.subwindow(data.axes_select).mouse_position(2));
        z=0.5*(z1+z2); 
        R=ResizeMatrix([z z z]); 
        data.subwindow(data.axes_select).Zoom=data.subwindow(data.axes_select).Zoom*(1/z);
        data.subwindow(data.axes_select).viewer_matrix=R*data.subwindow(data.axes_select).viewer_matrix;
        setMyData(data);
        show3d(true,true)       
    case 'drag'
        id=data.subwindow(data.axes_select).object_id_select;
        dvs=searchthestructure(data.volumes,'id',data.subwindow(data.axes_select).volume_id_select(1));
        n=searchthestructure(data.volumes(dvs).MeasureList,'id',id(1));
        object=data.volumes(dvs).MeasureList(n);
        s=round(id(3)*length(object.x));
        if(s==0)
            object.x=object.x-mean(object.x(:))+ data.subwindow(data.axes_select).VoxelLocation(1);
            object.y=object.y-mean(object.y(:))+ data.subwindow(data.axes_select).VoxelLocation(2);
            object.z=object.z-mean(object.z(:))+ data.subwindow(data.axes_select).VoxelLocation(3);
        else
            
            object.x(s)=data.subwindow(data.axes_select).VoxelLocation(1);
            object.y(s)=data.subwindow(data.axes_select).VoxelLocation(2);
            object.z(s)=data.subwindow(data.axes_select).VoxelLocation(3);
        end
        switch object.type
            case 'd'
                dx=data.volumes(dvs).Scales(1)*(object.x(1)-object.x(2));
                dy=data.volumes(dvs).Scales(2)*(object.y(1)-object.y(2));
                dz=data.volumes(dvs).Scales(3)*(object.z(1)-object.z(2));
                distance=sqrt(dx.^2+dy.^2+dz.^2);
                object.varmm=distance;
            otherwise
        end
        data.volumes(dvs).MeasureList(n)=object;
        setMyData(data);
        show3d(false,false)
    otherwise
    end
end

function R=RotationMatrix(r)
% Determine the rotation matrix (View matrix) for rotation angles xyz ...
    Rx=[1 0 0 0; 0 cosd(r(1)) -sind(r(1)) 0; 0 sind(r(1)) cosd(r(1)) 0; 0 0 0 1];
    Ry=[cosd(r(2)) 0 sind(r(2)) 0; 0 1 0 0; -sind(r(2)) 0 cosd(r(2)) 0; 0 0 0 1];
    Rz=[cosd(r(3)) -sind(r(3)) 0 0; sind(r(3)) cosd(r(3)) 0 0; 0 0 1 0; 0 0 0 1];
    R=Rx*Ry*Rz;
%     Resize the window..........
function M=ResizeMatrix(s)
	M=[1/s(1) 0 0 0;
	   0 1/s(2) 0 0;
	   0 0 1/s(3) 0;
	   0 0 0 1];
% for the translation of a point to origin....as written in the report
function M=TranslateMatrix(t)
	M=[1 0 0 -t(1);
	   0 1 0 -t(2);
	   0 0 1 -t(3);
	   0 0 0 1];
%  it will read the cursor position so that it can calculate that is the
%  measurement or how must the object is rotated
function cursor_position_in_axes(hObject,handles)
data=getMyData(); if(isempty(data)), return, end;
if(isempty(data.axes_select)), return, end
data.subwindow(data.axes_select).mouse_position_last=data.subwindow(data.axes_select).mouse_position;
h=data.subwindow(data.axes_select).handles.axes;
if(~ishandle(h)), return; end
p = get(h, 'CurrentPoint');
if (~isempty(p))
    data.subwindow(data.axes_select).mouse_position=[p(1, 1) p(1, 2)]./data.subwindow(data.axes_select).axes_size(1:2);
end
setMyData(data);

function setMyData(data,handle)
if(nargin<2), handle=gcf; end
setappdata(handle,'data3d',data);
function data=getMyData(handle)
if(nargin<1), handle=gcf; end
data=getappdata(handle,'data3d');

function axes_ButtonDownFcn(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
dvs=searchthestructure(data.volumes,'id',data.subwindow(data.axes_select).volume_id_select(1));

ha=zeros(1,data.NumberWindows);
for i=1:data.NumberWindows, ha(i)=data.subwindow(i).handles.axes; end
data.axes_select=find(ha==gca);
data.mouse.pressed=true;
data.mouse.button=get(handles.figure1,'SelectionType');
data.subwindow(data.axes_select).mouse_position_pressed=data.subwindow(data.axes_select).mouse_position;
if(strcmp(data.mouse.button,'normal'))
    sr=strcmp(data.subwindow(data.axes_select).render_type(1:min(end,5)),'slice');
    if(sr)
        switch(data.mouse.action)
%             to check the 3d rotation
            case 'measure_distance'
                if(getnumberofpoints(data)==0)
                    % Do measurement
                    data=addMeasureList('p',data.subwindow(data.axes_select).VoxelLocation(1),data.subwindow(data.axes_select).VoxelLocation(2),data.subwindow(data.axes_select).VoxelLocation(3),0,data);
                    data.mouse.button='select_distance';
                    data.mouse.pressed=false;
                    setMyData(data);
                    show3d(false,false);
                    return
                elseif(getnumberofpoints(data)>0)
                    VoxelLocation1=[data.volumes(dvs).MeasureList(end).x data.volumes(dvs).MeasureList(end).y data.volumes(dvs).MeasureList(end).z];
                    VoxelLocation2=data.subwindow(data.axes_select).VoxelLocation;
                    % First remove the point (will be replaced by distance)
                    data=rmvMeasureList(data.volumes(dvs).MeasureList(end).id,data);
                    % Do measurement
                    x=[VoxelLocation1(1) VoxelLocation2(1)];
                    y=[VoxelLocation1(2) VoxelLocation2(2)];
                    z=[VoxelLocation1(3) VoxelLocation2(3)];
                    dx=data.volumes(dvs).Scales(1)*(x(1)-x(2));
                    dy=data.volumes(dvs).Scales(2)*(y(1)-y(2));
                    dz=data.volumes(dvs).Scales(3)*(z(1)-z(2));
                    distance=sqrt(dx.^2+dy.^2+dz.^2);
                    data=addMeasureList('d',x,y,z,distance,data);
                    data.mouse.action='';
                    data.mouse.pressed=false;
                    setMyData(data);
                    show3d(false,false);
                    return
                end

            case 'measure_roi'
                % Do measurement
                data=addMeasureList('p',data.subwindow(data.axes_select).VoxelLocation(1),data.subwindow(data.axes_select).VoxelLocation(2),data.subwindow(data.axes_select).VoxelLocation(3),0,data);
                data.mouse.button='select_roi';
                data.mouse.pressed=false;
                setMyData(data);
                show3d(false,false);
                return

            otherwise
                 id_detect=getHitMapClick(data);
                 if(id_detect(1)>0)
                     data.subwindow(data.axes_select).object_id_select=id_detect;
                     data.mouse.button='drag';
                     setMyData(data);
                     return;
                 end
        end
        
    end
    
    
    distance_center=sum((data.subwindow(data.axes_select).mouse_position-[0.5 0.5]).^2);
    if((distance_center<0.15)&&data.subwindow(data.axes_select).render_type(1)~='s')
        data.mouse.button='rotate1';
    else
        data.mouse.button='rotate2';
    end
end
if(strcmp(data.mouse.button,'open'))
    switch(data.mouse.action)
        case 'measure_roi'
            data=addMeasureList('p',data.subwindow(data.axes_select).VoxelLocation(1),data.subwindow(data.axes_select).VoxelLocation(2),data.subwindow(data.axes_select).VoxelLocation(3),0,data);
            data=points2roi(data,false);

            data.mouse.action='';
            data.mouse.pressed=false;
            setMyData(data);
            show3d(false,false);
            return            
         
        otherwise
    end
end

if(strcmp(data.mouse.button,'extend'))
    data.mouse.button='pan';
end
if(strcmp(data.mouse.button,'alt'))
    if(data.subwindow(data.axes_select).render_type(1)=='s')
        id_detect=getHitMapClick(data);
        if(id_detect(1)>0)
            data=rmvMeasureList(id_detect(1),data);
            setMyData(data);
            show3d(false,false);
            return;
        end
    end
        data.mouse.button='zoom';
end
setMyData(data);

function figure1_WindowButtonUpFcn(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
if(isempty(data.axes_select)), return, end
if(data.mouse.pressed)
    data.mouse.pressed=false;
    setMyData(data);
    show3d(false,true)
end
function A=imresize3d(V,scale,tsize,ntype,npad)
if(exist('ntype', 'var') == 0), ntype='nearest'; end
if(exist('npad', 'var') == 0), npad='bound'; end
if(exist('scale', 'var')&&~isempty(scale)), tsize=round(size(V)*scale); end
if(ndims(V)>2)
    if(exist('tsize', 'var')&&~isempty(tsize)),  scale=(tsize./size(V)); end
    vmin=min(V(:));
    vmax=max(V(:));

    % Make transformation structure   
    T = makehgtform('scale',scale);
    tform = maketform('affine', T);
    % Specify resampler
    R = makeresampler(ntype, npad);
    % Resize the image volueme
    A = tformarray(V, tform, R, [1 2 3], [1 2 3], tsize, [], 0);
    % Limit to range
    A(A<vmin)=vmin; A(A>vmax)=vmax;
else
    if(exist('tsize', 'var')&&~isempty(tsize)),  
        tsize=tsize(1:2);
        scale=(tsize./size(V)); 
    end
    vmin=min(V(:));
    vmax=max(V(:));

    switch(ntype(1))
        case 'n'
            ntype2='nearest';
        case 'l'
            ntype2='bilinear';
        otherwise
            ntype2='bicubic';
    end
    
    % Transform the image
    A=imresize(V,scale.*size(V),ntype2);
    % Limit to range
    A(A<vmin)=vmin; A(A>vmax)=vmax;
end
function load_view(filename)
dataold=getMyData();
if(exist(filename,'file'))
    load(filename);
else
    ECiitkgpMatlab3DView_error({'File Not Found'}); return    
end
if(exist('data','var'))
      % Remove current Windows and VolumeMenu's
      dataold.NumberWindows=0;
      dataold=deleteWindows(dataold);
      for i=1:length(dataold.volumes)
        delete(dataold.MenuVolume(i).Handle);
      end
      
      % Temporary store the loaded data in a new variable
      datanew=data;
      
      % Make an empty data-structure 
      data=struct;
      % Add the current figure handles and other information about the
      % current render figure.
      data.Menu=dataold.Menu;
      data.handles=dataold.handles;
      data.mouse=dataold.mouse;
      data.config=dataold.config;
      data.rendertypes=dataold.rendertypes;
      data.figurehandles=dataold.figurehandles;
      data.volumes=[];
      data.axes_select=[];
      data.volume_select=[];
      data.subwindow=[];
      data.NumberWindows=0;
      data.MenuVolume=[];
      data.icons=dataold.icons; 
      % Add the loaded volumes
      data.volumes=datanew.volumes;
      for nv=1:length(data.volumes)
        data=makeVolumeXY(data,nv);
        data=computeNormals(data,nv);
        data=makePreviewVolume(data,nv);
        data=makeRenderVolume(data,nv);
        data=grayscalepseudocolor(nv,data);
      end
      
      data.NumberWindows=datanew.NumberWindows;
      data=addWindows(data);
     
 cfield={'tVolumemm', ...
 'VoxelLocation','mouse_position_pressed','mouse_position','mouse_position_last','shading_material', ...
 'ColorSlice','render_type','ViewerVector','volume_id_select','object_id_select' ...
 'render_image','total_image','hitmap','axes_size','Zoom','viewer_matrix','SliceSelected','Mview','combine'};
      
      for i=1:data.NumberWindows
        for j=1:length(cfield);
            if(isfield(datanew.subwindow(i),cfield{j}))
                data.subwindow(i).(cfield{j})=datanew.subwindow(i).(cfield{j});
            else
            	data.subwindow(i).(cfield{j})=dataold.subwindow(1).(cfield{j});
            end
        end
      end
      
      data.substorage=datanew.substorage;
      data.axes_select=datanew.axes_select;
      data.volume_select=datanew.volume_select;
      setMyData(data);
      allshow3d(false,true);
else
    ECiitkgpMatlab3DView_error({'Matlab File does not contain','data from "Save View"'})
end
function menu_load_data_Callback(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
if(ishandle(data.figurehandles.graylevel)), close(data.figurehandles.graylevel); end
[volume,info]=ReadDicom;
% Make the volume nD -> 4D
V=reshape(volume,size(volume,1),size(volume,2),size(volume,3),[]);
if(isempty(info)),return; end
scales=info.PixelDimensions;
if(nnz(scales)<3)
	ECiitkgpMatlab3DView_error({'Pixel Scaling Unknown using [1, 1, 1]'})
	scales=[1 1 1];
end

if(exist('volume','var'))
    addVolume(V,scales,info)
else
    ECiitkgpMatlab3DView_error({'Matlab Data Load Error'})
end
function menu_render_Callback(hObject, eventdata, handles)
function menu_info_Callback(hObject, eventdata, handles)
function figure1_CloseRequestFcn(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), delete(hObject); return, end
try 
if(ishandle(data.figurehandles.graylevel)), delete(data.figurehandles.graylevel); end
if(ishandle(data.figurehandles.speed)), delete(data.figurehandles.speed); end
if(ishandle(data.figurehandles.console)), delete(data.figurehandles.console);  end

    disp(me.message);
end

try rmappdata(gcf,'data3d'); catch end
delete(hObject);
function data=console_addline(data,newline)
if(ishandle(data.figurehandles.console)),
    data.subwindow(data.axes_select).consolelines=data.subwindow(data.axes_select).consolelines+1;
    data.subwindow(data.axes_select).consoletext{data.subwindow(data.axes_select).consolelines}=newline;
    if(data.subwindow(data.axes_select).consolelines>14), 
        data.subwindow(data.axes_select).consolelines=14; 
        data.subwindow(data.axes_select).consoletext={data.subwindow(data.axes_select).consoletext{2:end}}; 
    end
    set(data.figurehandles.console_edit,'String',data.subwindow(data.axes_select).consoletext);
end
function speed_pushbutton_applyconfig_Callback(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
handles_speed=guidata(data.figurehandles.speed);

VolumeScaling=get(get(handles_speed.uipanel_VolumeScaling,'SelectedObject'),'Tag');
PreviewVolumeSize=get(get(handles_speed.uipanel_PreviewVolumeSize,'SelectedObject'),'Tag');
ShearInterpolation=get(get(handles_speed.uipanel_ShearInterpolation,'SelectedObject'),'Tag');
WarpInterpolation=get(get(handles_speed.uipanel_WarpInterpolation,'SelectedObject'),'Tag');
ImageSizeRender=get(get(handles_speed.uipanel_ImageSizeRender,'SelectedObject'),'Tag');

VolumeScaling=str2double(VolumeScaling(20:end));
ImageSizeRender=str2double(ImageSizeRender(23:end));

PreviewVolumeSize=str2double(PreviewVolumeSize(21:end));
data.config.ShearInterpolation=ShearInterpolation(23:end);
data.config.WarpInterpolation=WarpInterpolation(22:end);
data.config.PreRender=get(handles_speed.checkbox_prerender,'Value');
data.config.StoreXYZ=get(handles_speed.checkbox_storexyz,'Value');

if(ImageSizeRender~=data.config.ImageSizeRender)
    s=data.config.ImageSizeRender/ImageSizeRender;
    data.subwindow(data.axes_select).viewer_matrix=data.subwindow(data.axes_select).viewer_matrix*ResizeMatrix([s s s]);
    data.config.ImageSizeRender=ImageSizeRender;
end

scale_change=data.config.VolumeScaling~=VolumeScaling;
if(scale_change)
      data.config.VolumeScaling=VolumeScaling;
      for dvs=1:length(data.volumes)
          data=makeRenderVolume(data,dvs);
      end
end

if(data.config.PreviewVolumeSize~=PreviewVolumeSize)
    data.config.PreviewVolumeSize=PreviewVolumeSize;
    for dvs=1:length(data.volumes)
        data=makePreviewVolume(data,dvs);
    end
end
for dvs=1:length(data.volumes)
    data.volume_id_select(1)=data.volumes(dvs).id;
    if((isempty(data.volumes(dvs).volumey)||scale_change)&&data.config.StoreXYZ)
        data=makeVolumeXY(data);
    end
    if(~data.config.StoreXYZ)
        data.volumes(dvs).volumex=[]; data.volumes(dvs).volumey=[];
    end
end


if((isempty(data.volumes(dvs).normals)||scale_change)&&data.config.PreRender)
    % Make normals
    for dvs=1:length(data.volumes)
        data=computeNormals(data,dvs);
    end
end
if(~data.config.PreRender)
    data.volumes(dvs).normals=[];
end

data.subwindow(data.axes_select).first_render=true;
setMyData(data);
show3d(false,true);
function data=makeVolumeXY(data,dvs)
if(data.config.StoreXYZ)
    data.volumes(dvs).volumex=shiftdim(data.volumes(dvs).volume,1);
    data.volumes(dvs).volumey=shiftdim(data.volumes(dvs).volume,2);
else
    data.volumes(dvs).volumex=[];
    data.volumes(dvs).volumey=[];
end
function data=computeNormals(data,dvs)
if(data.config.PreRender)
    % Pre computer Normals for faster shading rendering.
    [fy,fx,fz]=gradient(imgaussian(double(data.volumes(dvs).volume),1/2));
    flength=sqrt(fx.^2+fy.^2+fz.^2)+1e-6;
    data.volumes(dvs).normals=zeros([size(fx) 3]);
    data.volumes(dvs).normals(:,:,:,1)=fx./flength;
    data.volumes(dvs).normals(:,:,:,2)=fy./flength;
    data.volumes(dvs).normals(:,:,:,3)=fz./flength;
else
    data.volumes(dvs).normals=[];
end
function I=imgaussian(I,sigma,siz)
if(~exist('siz','var')), siz=sigma*6; end
% Make 1D gaussian kernel
x=-(siz/2)+0.5:siz/2;
H = exp(-(x.^2/(2*sigma^2))); 
H = H/sum(H(:));
% Filter each dimension with the 1D gaussian kernels
if(ndims(I)==1)
    I=imfilter(I,H);
elseif(ndims(I)==2)
    Hx=reshape(H,[length(H) 1]); 
    Hy=reshape(H,[1 length(H)]); 
    I=imfilter(imfilter(I,Hx),Hy);
elseif(ndims(I)==3)
    Hx=reshape(H,[length(H) 1 1]); 
    Hy=reshape(H,[1 length(H) 1]); 
    Hz=reshape(H,[1 1 length(H)]);
    I=imfilter(imfilter(imfilter(I,Hx),Hy),Hz);
else
    error('imgaussian:input','unsupported input dimension');
end
function speed_pushbutton_saveconfig_Callback(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
handles_speed=guidata(data.figurehandles.speed);
VolumeScaling=get(get(handles_speed.uipanel_VolumeScaling,'SelectedObject'),'Tag');
PreviewVolumeSize=get(get(handles_speed.uipanel_PreviewVolumeSize,'SelectedObject'),'Tag');
ShearInterpolation=get(get(handles_speed.uipanel_ShearInterpolation,'SelectedObject'),'Tag');
WarpInterpolation=get(get(handles_speed.uipanel_WarpInterpolation,'SelectedObject'),'Tag');
ImageSizeRender=get(get(handles_speed.uipanel_ImageSizeRender,'SelectedObject'),'Tag');
VolumeScaling=str2double(VolumeScaling(20:end));
PreviewVolumeSize=str2double(PreviewVolumeSize(21:end));
data.config.ImageSizeRender=str2double(ImageSizeRender(23:end));
data.config.ShearInterpolation=ShearInterpolation(23:end);
data.config.WarpInterpolation=WarpInterpolation(22:end);
data.config.PreRender=get(handles_speed.checkbox_prerender,'Value');
data.config.StoreXYZ=get(handles_speed.checkbox_storexyz,'Value');
data.config.VolumeScaling=VolumeScaling;
data.config.PreviewVolumeSize=PreviewVolumeSize;
config=data.config;
fcndirectory=which('ECiitkgpMatlab3DView.m'); fcndirectory=fcndirectory(1:end-length('ECiitkgpMatlab3DView.m'));
save([fcndirectory '/default_config.mat'],'config')

function menu_measure_Callback(hObject, eventdata, handles)

function data=checkvolumetype(data,nv)
if(nargin<2), s=1; e=length(data.volumes); else s=nv; e=nv; end
for i=s:e
     data.volumes(i).volumemin=double(min(data.volumes(i).volume_original(:)));
     data.volumes(i).volumemax=double(max(data.volumes(i).volume_original(:)));
     if( data.volumes(i).volumemax==0),  data.volumes(i).volumemax=1; end
     switch(class(data.volumes(i).volume_original))
     case {'uint8','uint16','uint32','int8','int16','int32','single','double'}
     otherwise
        ECiitkgpMatlab3DView_error({'Unsupported input datatype converted to double'});
        data.volumes(i).volume_original=double(data.volumes(i).volume_original);
     end
     data.volumes(i).WindowWidth=data.volumes(i).volumemax-data.volumes(i).volumemin;
     data.volumes(i).WindowLevel=0.5*(data.volumes(i).volumemax+data.volumes(i).volumemin);     
end
function figure1_WindowScrollWheelFcn(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
if(isempty(data.axes_select)), return, end
switch data.subwindow(data.axes_select).render_type
    case {'slicex','slicey','slicez'}
        handles=guidata(hObject);
        data=changeslice(eventdata.VerticalScrollCount,handles,data);
        setMyData(data);
        show3d(false,true);
end
function figure1_KeyPressFcn(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
if(strcmp(eventdata.Key,'uparrow')), eventdata.Character='+'; end
if(strcmp(eventdata.Key,'downarrow')), eventdata.Character='-'; end
    
switch data.subwindow(data.axes_select).render_type
    case {'slicex','slicey','slicez'}
        handles=guidata(hObject);
        switch(eventdata.Character)
            case '+'
                data=changeslice(1,handles,data);
                setMyData(data); show3d(true,true);
            case '-'
                data=changeslice(-1,handles,data);
                setMyData(data); show3d(true,true);
            otherwise
        end
     otherwise        
end
function data=changeslice(updown,handles,data)
dvss=searchthestructure(data.volumes,'id',data.subwindow(data.axes_select).volume_id_select(1));
switch data.subwindow(data.axes_select).render_type
case 'slicex'
    data.subwindow(data.axes_select).SliceSelected(1)=data.subwindow(data.axes_select).SliceSelected(1)+updown;
    if(data.subwindow(data.axes_select).SliceSelected(1)>size(data.volumes(dvss).volume_original,1)),  data.subwindow(data.axes_select).SliceSelected(1)=size(data.volumes(dvss).volume_original,1); end
case 'slicey'
    data.subwindow(data.axes_select).SliceSelected(2)=data.subwindow(data.axes_select).SliceSelected(2)+updown;
    if(data.subwindow(data.axes_select).SliceSelected(2)>size(data.volumes(dvss).volume_original,2)),  data.subwindow(data.axes_select).SliceSelected(2)=size(data.volumes(dvss).volume_original,2); end
case 'slicez'
    data.subwindow(data.axes_select).SliceSelected(3)=data.subwindow(data.axes_select).SliceSelected(3)+updown;
    if(data.subwindow(data.axes_select).SliceSelected(3)>size(data.volumes(dvss).volume_original,3)),  data.subwindow(data.axes_select).SliceSelected(3)=size(data.volumes(dvss).volume_original,3); end
end
% Boundary limit
data.subwindow(data.axes_select).SliceSelected(data.subwindow(data.axes_select).SliceSelected<1)=1;
% Stop measurement
data.mouse.action='';
function figure1_KeyReleaseFcn(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
switch data.subwindow(data.axes_select).render_type
    case {'slicex','slicey','slicez'}
        show3d(false,true);
end

% position...................shear-warp yoo
function [x_2d,y_2d]=voxelposition_to_imageposition(x,y,z,data)
dvs=searchthestructure(data.volumes,'id',data.subwindow(data.axes_select).volume_id_select(1));

data.subwindow(data.axes_select).Mview=data.subwindow(data.axes_select).viewer_matrix;
switch (data.subwindow(data.axes_select).render_type)
    case {'slicex'}
        sizeIin=[size(data.volumes(dvs).volume_original,2) size(data.volumes(dvs).volume_original,3)];
        M=[data.subwindow(data.axes_select).Mview(1,2) data.subwindow(data.axes_select).Mview(1,3) data.subwindow(data.axes_select).Mview(1,4); data.subwindow(data.axes_select).Mview(2,2) data.subwindow(data.axes_select).Mview(2,3) data.subwindow(data.axes_select).Mview(2,4); 0 0 1];
    case {'slicey'}
        sizeIin=[size(data.volumes(dvs).volume_original,1) size(data.volumes(dvs).volume_original,3)];
        M=[data.subwindow(data.axes_select).Mview(1,1) data.subwindow(data.axes_select).Mview(1,3) data.subwindow(data.axes_select).Mview(1,4); data.subwindow(data.axes_select).Mview(2,1) data.subwindow(data.axes_select).Mview(2,3) data.subwindow(data.axes_select).Mview(2,4); 0 0 1];     % Rotate 90
    case {'slicez'}
        sizeIin=[size(data.volumes(dvs).volume_original,1) size(data.volumes(dvs).volume_original,2)];
        M=[data.subwindow(data.axes_select).Mview(1,1) data.subwindow(data.axes_select).Mview(1,2) data.subwindow(data.axes_select).Mview(1,4); data.subwindow(data.axes_select).Mview(2,1) data.subwindow(data.axes_select).Mview(2,2) data.subwindow(data.axes_select).Mview(2,4); 0 0 1];
end

switch (data.subwindow(data.axes_select).render_type)
    case {'slicex'}
        Tlocalx=y; Tlocaly=z;
    case {'slicey'}
        Tlocalx=x; Tlocaly=z;
    case {'slicez'}
        Tlocalx=x; Tlocaly=y;
end

% Calculate center of the input image
mean_in=sizeIin/2;
x_2d=zeros(1,length(Tlocalx)); y_2d=zeros(1,length(Tlocalx));

Tlocalx=Tlocalx-mean_in(1);
Tlocaly=Tlocaly-mean_in(2);

for i=1:length(x)
    vector=M*[Tlocalx(i);Tlocaly(i);1];
    x_2d(i)=vector(1);
    y_2d(i)=vector(2);
end

% Calculate center of the output image
mean_out=[data.config.ImageSizeRender data.config.ImageSizeRender]/2;

% Make center of the image coordinates 0,0
x_2d=x_2d+mean_out(1); 
y_2d=y_2d+mean_out(2);
function data=mouseposition_to_voxelposition(data)
dvs=searchthestructure(data.volumes,'id',data.subwindow(data.axes_select).volume_id_select(1));
if(isempty(dvs)), return; end
data.subwindow(data.axes_select).Mview=data.subwindow(data.axes_select).viewer_matrix;
switch (data.subwindow(data.axes_select).render_type)
    case {'slicex'}
        sizeIin=[size(data.volumes(dvs).volume_original,2) size(data.volumes(dvs).volume_original,3)];
        M=[data.subwindow(data.axes_select).Mview(1,2) data.subwindow(data.axes_select).Mview(1,3) data.subwindow(data.axes_select).Mview(1,4); data.subwindow(data.axes_select).Mview(2,2) data.subwindow(data.axes_select).Mview(2,3) data.subwindow(data.axes_select).Mview(2,4); 0 0 1];
    case {'slicey'}
        sizeIin=[size(data.volumes(dvs).volume_original,1) size(data.volumes(dvs).volume_original,3)];
        M=[data.subwindow(data.axes_select).Mview(1,1) data.subwindow(data.axes_select).Mview(1,3) data.subwindow(data.axes_select).Mview(1,4); data.subwindow(data.axes_select).Mview(2,1) data.subwindow(data.axes_select).Mview(2,3) data.subwindow(data.axes_select).Mview(2,4); 0 0 1];     % Rotate 90
    case {'slicez'}
        sizeIin=[size(data.volumes(dvs).volume_original,1) size(data.volumes(dvs).volume_original,2)];
        M=[data.subwindow(data.axes_select).Mview(1,1) data.subwindow(data.axes_select).Mview(1,2) data.subwindow(data.axes_select).Mview(1,4); data.subwindow(data.axes_select).Mview(2,1) data.subwindow(data.axes_select).Mview(2,2) data.subwindow(data.axes_select).Mview(2,4); 0 0 1];
end
M=inv(M);
    
% Get the mouse position
x_2d=data.subwindow(data.axes_select).mouse_position(2);
y_2d=data.subwindow(data.axes_select).mouse_position(1); 
% To rendered image position
x_2d=x_2d*data.config.ImageSizeRender; y_2d=y_2d*data.config.ImageSizeRender;
% Calculate center of the input image
mean_in=sizeIin/2;
% Calculate center of the output image
mean_out=[data.config.ImageSizeRender data.config.ImageSizeRender]/2;
% Calculate the Transformed coordinates
x_2d=x_2d - mean_out(1); 
y_2d=y_2d - mean_out(2);
location(1)= mean_in(1) + M(1,1) * x_2d + M(1,2) *y_2d + M(1,3) * 1;
location(2)= mean_in(2) + M(2,1) * x_2d + M(2,2) *y_2d + M(2,3) * 1;

switch (data.subwindow(data.axes_select).render_type)
    case {'slicex'}
        data.subwindow(data.axes_select).VoxelLocation=[data.subwindow(data.axes_select).SliceSelected(1) location(1) location(2)];
    case {'slicey'}
        data.subwindow(data.axes_select).VoxelLocation=[location(1) data.subwindow(data.axes_select).SliceSelected(2) location(2)];
    case {'slicez'}
        data.subwindow(data.axes_select).VoxelLocation=[location(1) location(2) data.subwindow(data.axes_select).SliceSelected(3)];
end
data.subwindow(data.axes_select).VoxelLocation=round(data.subwindow(data.axes_select).VoxelLocation);

data.subwindow(data.axes_select).VoxelLocation(data.subwindow(data.axes_select).VoxelLocation<1)=1;
if(data.subwindow(data.axes_select).VoxelLocation(1)>size(data.volumes(dvs).volume_original,1)), data.subwindow(data.axes_select).VoxelLocation(1)=size(data.volumes(dvs).volume_original,1); end
if(data.subwindow(data.axes_select).VoxelLocation(2)>size(data.volumes(dvs).volume_original,2)), data.subwindow(data.axes_select).VoxelLocation(2)=size(data.volumes(dvs).volume_original,2); end
if(data.subwindow(data.axes_select).VoxelLocation(3)>size(data.volumes(dvs).volume_original,3)), data.subwindow(data.axes_select).VoxelLocation(3)=size(data.volumes(dvs).volume_original,3); end
function menu_config_slicescolor_Callback(hObject, eventdata, handles)
data=getMyData();
data.axes_select=eventdata;
if(data.subwindow(data.axes_select).ColorSlice)
    data.subwindow(data.axes_select).ColorSlice=false;
else
    data.subwindow(data.axes_select).ColorSlice=true;
end    
setMyData(data);
show3d(false,true);
function menu_ChangeVolume_Callback(hObject, eventdata, handles)
data=getMyData(); if(isempty(data)), return, end
s=eventdata(2);
if(s>0);
    switch length(eventdata)
        case 2
            data.subwindow(eventdata(1)).volume_id_select=data.volumes(eventdata(2)).id;
        case 3
            data.subwindow(eventdata(1)).volume_id_select=[data.volumes(eventdata(2)).id; data.volumes(eventdata(3)).id];
        case 4
            data.subwindow(eventdata(1)).volume_id_select=[data.volumes(eventdata(2)).id; data.volumes(eventdata(3)).id; data.volumes(eventdata(4)).id];
    end
else
    data.subwindow(eventdata(1)).volume_id_select=0;
    data.subwindow(eventdata(1)).render_type='Blue';
end
data.axes_select=eventdata(1);
  
if(s>0)
    data.subwindow(eventdata(1)).Zoom=(sqrt(3)./sqrt(sum(data.volumes(s).Scales.^2)));
    data=set_initial_view_matrix(data);
    data.subwindow(data.axes_select).SliceSelected=round(data.volumes(s).Size/2);
end
setMyData(data);
show3d(false,true);
function menu_ChangeRender_Callback(hObject, eventdata, handles) 
data=getMyData(); if(isempty(data)), return, end
if(data.subwindow(eventdata(1)).volume_id_select(1)>0)
    data.axes_select=eventdata(1);

    data.subwindow(data.axes_select).render_type=data.rendertypes(eventdata(2)).type;
    switch data.rendertypes(eventdata(2)).type
        case {'slicex','slicey','slicez'}
        data=set_initial_view_matrix(data);
    end
    data.subwindow(data.axes_select).first_render=true;
    setMyData(data);
    show3d(false,true);
end
function data=deleteWindows(data)
for i=(data.NumberWindows+1):length(data.subwindow)
    h=data.subwindow(i).handles.axes;
    if(~isempty(h)), 
        delete(data.subwindow(i).handles.axes), 
        set(data.subwindow(i).handles.uipanelmenu,'UIContextMenu',uicontextmenu);
        showthewindow
        delete(data.subwindow(i).handles.uipanelmenu), 
    end
    data.subwindow(i).handles.axes=[];
end 
function data=addWindows(data)
for i=1:data.NumberWindows
    if(length(data.subwindow)>=i), h=data.subwindow(i).handles.axes; else h=[]; end
    if(isempty(h)),
        data.subwindow(i).click_roi=false;
        data.subwindow(i).tVolumemm=0;
        data.subwindow(i).VoxelLocation=[1 1 1];
        data.subwindow(i).first_render=true;
        data.subwindow(i).mouse_position_pressed=[0 0];
        data.subwindow(i).mouse_position=[0 0];
        data.subwindow(i).mouse_position_last=[0 0];
        data.subwindow(i).shading_material='slicescolor';
        data.subwindow(i).volume_id_select=0;
        data.subwindow(i).object_id_select=0;
        data.subwindow(i).first_render=true;
        data.subwindow(i).ColorSlice=false;
        data.subwindow(i).render_type='Red';
        data.subwindow(i).ViewerVector = [0 0 1];
        data.subwindow(i).handles.uipanelmenu=uipanel('units','normalized');
        data.subwindow(i).handles.axes=axes;
        set(data.subwindow(i).handles.axes,'units','normalized');
        data.subwindow(i).menu.Handle=[];
    end
end   
data=menulineadding(data);
switch(data.NumberWindows)
    case 1
        w=1; h=1;
        makeWindow(data,1,0,0,w,h);
    
end
showthewindow
function data=makeWindow(data,id,x,y,w,h)
a=0.01;
set(data.subwindow(id).handles.axes,  'position', [(x+a/2) (y+a/2) (w-a) (h-0.07-a) ]);
set(data.subwindow(id).handles.uipanelmenu,  'position', [x y w h]);

function data=menulineadding(data)
for i=1:data.NumberWindows
    if(ishandle(data.subwindow(i).menu.Handle))
        delete(data.subwindow(i).menu.Handle);
        data.subwindow(i).menu=[];
    end
    
    Menu(1).Label='Volume Rendering';
    Menu(1).Tag='menu_render';
    Menu(1).Callback='';
    
    for f=1:length(data.rendertypes)
        Menu(1).Children(f).Label=data.rendertypes(f).label;
        Menu(1).Children(f).Callback=['ECiitkgpMatlab3DView(''menu_ChangeRender_Callback'',gcbo,[' num2str(i) ' ' num2str(f) '],guidata(gcbo))'];
    end

    Menu(2).Label='Volume';

    hn=0;
    for f=0:length(data.volumes)
        if(f==0), 
            name='None'; 
            g=[];
        else
            name=data.volumes(f).name; 
            g=searchthestructure(data.volumes(f+1:end),'Size_original',data.volumes(f).Size_original);
            if(~isempty(g)); g=g+f; g=g(1:min(end,2)); end
        end

        hn=hn+1; 
        Menu(2).Children(hn).Callback=['ECiitkgpMatlab3DView(''menu_ChangeVolume_Callback'',gcbo,[' num2str(i) ' ' num2str(f) '],guidata(gcbo))'];
        Menu(2).Children(hn).Label=name;
        Menu(2).Children(hn).Tag=['wmenu-' num2str(i) '-' num2str(f)];

        if(~isempty(g))
            hn=hn+1; 
            Menu(2).Children(hn).Callback=['ECiitkgpMatlab3DView(''menu_ChangeVolume_Callback'',gcbo,[' num2str(i) ' ' num2str(f)  ' ' num2str(g(1)) '],guidata(gcbo))'];
            Menu(2).Children(hn).Label=[name ' & ' data.volumes(g(1)).name];
            Menu(2).Children(hn).Tag=['wmenu-' num2str(i) '-' num2str(f) '-' num2str(g(1))];
            
            if(length(g)>1)
                hn=hn+1; 
                Menu(2).Children(hn).Callback=['ECiitkgpMatlab3DView(''menu_ChangeVolume_Callback'',gcbo,[' num2str(i) ' ' num2str(f)  ' ' num2str(g(1)) ' ' num2str(g(2)) '],guidata(gcbo))'];
                Menu(2).Children(hn).Label=[name ' & ' data.volumes(g(1)).name ' & ' data.volumes(g(2)).name];
                Menu(2).Children(hn).Tag=['wmenu-' num2str(i) '-' num2str(f) '-' num2str(g(1)) '-' num2str(g(2)) ];
            end
        end
        
    end
   
    Menu(3).Label='Show View';
    Menu(3).Tag='menu_config_slicescolor';
    Menu(3).Callback=['ECiitkgpMatlab3DView(''menu_config_slicescolor_Callback'',gcbo,' num2str(i) ',guidata(gcbo))'];
%     childrens can also be included for showing more processes while
%     showing a window
%     Menu(3).Children(1).Label='Red Slice';
%     Menu(3).Children(1).Tag='menu_config_slicescolor';
%     Menu(3).Children(1).Callback=['ECiitkgpMatlab3DView(''menu_config_slicescolor_Callback'',gcbo,' num2str(i) ',guidata(gcbo))'];
% 

    handle_menu=uicontextmenu;
    Menu=addMenu(handle_menu,Menu);
    data.subwindow(i).menu.Handle=handle_menu;
    data.subwindow(i).menu.Children=Menu;
    
    set(data.subwindow(i).handles.uipanelmenu,'UIContextMenu',data.subwindow(i).menu.Handle);
end
showthewindow

% load dicom image is showm in the first line of the window........it
% has a callback to show another gui readdicom......so that the program can
% load the dicom files present anywhere in the computer
function Menu=firstlineofgui(handle_figure)
Menu(1).Label='Load Dicom Image';
Menu(1).Tag='menu_load_data';
Menu(1).Callback='ECiitkgpMatlab3DView(''menu_load_data_Callback'',gcbo,[],guidata(gcbo))';
Menu=addMenu(handle_figure,Menu);
function Menu=addMenu(handle_figure,Menu)
Properties={'Label','Callback','Separator','Checked','Enable','ForegroundColor','Position','ButtonDownFcn','Selected','SelectionHighlight','Visible','UserData'};
for i=1:length(Menu)
    z2=Menu(i);
    z2.Handle=uimenu(handle_figure, 'Label',z2.Label);
    for j=1:length(Properties)
            Pr=Properties{j};
            if(isfield(z2,Pr))
                val=z2.(Pr);
                if(~isempty(val)), set(z2.Handle ,Pr,val); end
            end
    end
    if(isfield(z2,'Children')&&~isempty(z2.Children))
        Menu(i).Children=addMenu(z2.Handle,z2.Children);
    end
    Menu(i).Handle=z2.Handle;
end
function figure1_ResizeFcn(hObject, eventdata, handles)
showthewindow('ResizeFcn',gcf);

% this function is used to see the structure and find or search its
% value.........if the value is not present in the struct then give error
% message otherwise provide the value
function index=searchthestructure(a,field,value)

if(isstruct(value)), 
    error('searchthestructure:inputs','the value searched is not present in the structure');
end

if(~isfield(a,field))
    index=find(arrayfun(@(x)(cmp(x,field,value)),a,'uniformoutput',true));
else
    index=find(arrayfun(@(x)(cmp(x,field,value)),a,'uniformoutput',true));
end
function check=cmp(x,field,value)
check=false;
if(isfield(x,field))
   
    x=x.(field); 
else
    in=find(field=='.');
    s=[1 in+1]; e=[in-1 length(field)];
    for i=1:length(s)
        fieldt=field(s(i):e(i));
        if(isfield(x,fieldt)), x=x.(fieldt);  else return; end
    end
end

if(isstruct(x)), return; end

if(length(x)==length(value)), 
    if((~iscell(x))&&(~iscell(value))&&any(isnan(value))), 
        checkv=isnan(value); checkx=isnan(x);
        if(~all(checkx==checkv)), return; end
        x(checkx)=0; value(checkv)=0;
    end
    if(iscell(x)||iscell(value))
        check=all(strcmp(x,value)); 
    else
        check=all(x==value); 
    end
end
