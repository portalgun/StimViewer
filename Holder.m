classdef Holder
properties
    o
    Ptchs
    Filter
end
methods
    function obj=Holder(viewer)
        obj.Ptchs=viewer.Ptchs;
        obj.o=obj.Ptchs.ptchOpts;
        obj.Filter=viewer.Filter;
    end
    function restore(obj)
        obj.Ptchs.ptchOpts=obj.o;
    end
    function set(obj,prp,val)
        prp=obj.prp_expand(prp);
        val=obj.val_expand(val);
        obj.set_prp_fun(prp,val);
    end
    function reset(obj,prp)
        prp=obj.prp_expand(prp);
        val=getfield(obj.o.ptchOpts,prp{:});
        obj.set_prp_fun(prp,val);
    end

    function toggle(obj,prp,vals)
        if nargin >= 3
            [vals,bMany,All]=obj.vals_expand(vals);
        end
        prp=obj.prp_expand(prp);
        try
            val=getfield(obj.Ptchs.ptchOpts,prp{:});
        catch ME
            if strcmp(ME.identifier,'MATLAB:nonExistentField')
                val=[];
            else
                rethrow(ME);
            end
        end
        if nargin >= 3
            ind=find(ismember(vals,val));
            if isempty(ind)
                ind=1;
            end
            n=numel(vals);
            if ind+1 > n
                ind=1;
            else
                ind=ind+1;
            end


            if bMany(ind)
                new=All{ind};
            elseif isnumeric(vals)
                new=vals(ind);
            else
                new=vals{ind};
            end
        elseif isempty(val) || ~val
            new=true;
        else
            new=false;
        end
        obj.set_prp_fun(prp,new);
        %obj.Ptchs.ptchOpts.trgtInfo.trgtDsp
    end
end
methods(Access=private)
    function prp=prp_expand(obj,prp)
        if iscell(prp)
            return
        end
        if ischar(prp)
            prp=strsplit(prp,'.');
        end
    end
    function [vals,bMany,All]=vals_expand(obj,vals);
        if iscell(vals)
            [vals,bMany,All]=cellfun(@obj.val_fun,vals,'UniformOutput',false);
            bMany=[bMany{:}];
        else
            [vals,bMany,All]=obj.val_fun(vals);
        end

        bN=all(cellfun(@Num.is,vals));
        if iscell(vals) && bN
            try
                vals=[vals{:}];
            catch
                vals=unique(vertcat(vals{:})','stable');
            end
        end
    end
    function [val,bMany,All]=val_fun(obj,val)
        bMany=false;
        All=[];
        if ~(ischar(val) && startsWith(val,'@'))
            return
        end
        val=regexprep(val,'^@','');
        if contains(val,'.')
            spl=strsplit(val,'.');
        end
        if ismember(spl{1},{'PtchOpts','im'})
            spl{1}=[];
        end
        val=getfield(obj,spl{:});
        if size(val,1)==obj.Ptchs.Blk.blk.length()
            bMany=true;
            All=val;
            %[~,~,abs]=obj.Filter.getPidx();
            [lidx]=obj.Filter.getLoadIdx();
            val=val(lidx,:);
        end

    end
    function set_prp_fun(obj,prp,val)
        obj.Ptchs.ptchOpts=setfield(obj.Ptchs.ptchOpts,prp{:},val);
    end

end
end
