    function flag_update(obj,dest,comp)
        obj.bUp.cmd=true;
        switch dest
        case 'go'
            obj.bUp.Filter=true;
            obj.bUp.patch=true;
            obj.bUp.Flags=true;
            obj.bUp.im=true;
            obj.bUp.win=true;
        case 'im'
            obj.bUp.patch=true;
            obj.bUp.im=true;
            obj.bUp.win=true;
        case {'str','key'}
            obj.bUp.(dest)=true;
        case {'cmd','Cmd'}
             pass;
        otherwise
            if isfield(obj.bUp, comp)
                obj.bUp.(comp)=true;
            else
                obj.bUp.cmd=false;
            end
        end
    end
