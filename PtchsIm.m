classdef PtchsIm < handle
    im
end
methods
    function obj=get_im_bg(obj)
    end
        if obj.D.bSBS && strcmp(name,'stm')
            obj.rect.sbs=obj.rect_to_sbs('stm',num);
        elseif obj.D.bSBS
            obj.rect.(name)=obj.rect_to_sbs(name,num);
        end
    end
    end
end
end
