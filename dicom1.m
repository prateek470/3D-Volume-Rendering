function info=dicom2(filename)
% if folder is called
if(exist('filename','var')==0)
    dirname=''; 
    [filename, dirname] = uigetfile( {'*.dcm;*.dicom', 'Dicom Files'; '*.*', 'All Files (*.*)'}, 'Select a dicom file',dirname);
    if(filename==0), return; end
    filename=[dirname filename];
end
% Read directory for Dicom File Series......dicominformation is used here
% 
datasets=dicominformation(filename,false);
if(isempty(datasets))
    datasets=dicominformation(filename,true);
end

if(length(datasets)>1)
    c=cell(1,length(datasets));
    for i=1:length(datasets)
        c{i}=datasets(i).Filenames{1};
    end
    id=selectdicom(c,'Select a Dicom Dataset');
    datasets=datasets(id);
end

info=datasets.DicomInfo;
info.Filenames=datasets.Filenames;
info.PixelDimensions=datasets.Scales;
info.Dimensions=datasets.Sizes;
