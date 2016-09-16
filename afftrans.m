%this file contains the code of affline transformation......it uses the
%interpolation whose code is in the m file InterpoloImage......
function Iout=afftrans(Iin,M,interbound,ImageSize)
if(nargin<4), ImageSize=[size(Iin,1) size(Iin,2)]; end  
[x,y]=ndgrid(0:ImageSize(1)-1,0:ImageSize(2)-1);
mean_out=ImageSize/2;
mean_in=size(Iin)/2;
xd=x-mean_out(1);
yd=y-mean_out(2);
Tlocalx = mean_in(1) + M(1,1) * xd + M(1,2) *yd + M(1,3) * 1;
Tlocaly = mean_in(2) + M(2,1) * xd + M(2,2) *yd + M(2,3) * 1;
switch(interbound)
	case 0
		Interpolation='bilinear';
		Boundary='replicate';
	case 1
		Interpolation='bilinear';
		Boundary='zero';
	case 2
		Interpolation='bicubic';
		Boundary='replicate';
	case 3
		Interpolation='bicubic';
		Boundary='zero';
	case 4
		Interpolation='nearest';
		Boundary='replicate';
	case 5
		Interpolation='nearest';
		Boundary='zero';		
end
Iout=InterpoloImage(Iin,Tlocalx,Tlocaly,Interpolation,Boundary,ImageSize);
