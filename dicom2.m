function voxelvolume = dicom2(info)

if(~isstruct(info)) info=dicom1(info); end
voxelvolume=dicomread(info.Filenames{1});
nf=length(info.Filenames);
if(nf>1)
    voxelvolume=zeros(info.Dimensions,class(voxelvolume));
    h = waitbar(0,'Please wait while loading the Dicom slices and making the voxel volume...');
    for i=1:nf,
        waitbar(i/nf,h)
		I=dicomread(info.Filenames{i});
        if((size(I,3)*size(I,4))>1)
            voxelvolume=I; break;
        else
            voxelvolume(:,:,i)=I;
        end
    end
    close(h);
end


