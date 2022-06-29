classdef Holder
properties
    o
    Ptchs
    Filter
    prps % SAVED VALUES
    bNeedsSave
end
methods
    function obj=Holder(viewer)
        obj.Ptchs=viewer.Ptchs;
        obj.o=obj.Ptchs.ptchOpts;
        obj.Filter=viewer.Filter;
        fname=obj.get_fname();
        if ~isempty(fname) && Fil.exist(fname)
            obj.load();
        end
        obj.prps=struct();
    end
%% SAVE/LOAD
    function [fname]=get_fname(obj)
        dire=obj.Ptchs.get_dir();
        b=obj.Ptchs.Blk.unique('lvlInd','blk');
        if any(cellfun(@numel,b) > 2)
            fname=[];
            return
        end
        vals=strrep(Num.toStr(cell2mat(b)),',','-');
        fname=[dire '_ptchOpts_' vals '_.mat'];
    end
    function obj=save(obj)
        fname=obj.get_fname();
        prps=obj.prps;
        obj.save(fname,'prps');
        obj.bNeedsSave=0;
    end
    function obj=load(obj)
        fname=obj.get_fname();
        S=load(fname);
        obj.prps=S.prps;

        obj.apply_prps();
    end
    function apply_prps()
        flds=Struct.getFields(obj.prps);
        for i = 1:length(flds)
            val=getfield(obj.prps,flds{i}{:});
            obj.Ptchs.ptchOpts=setfield(obj.Ptchs.ptchOpts,flds{i}{:},val);
        end
    end
%% SET
    function restore(obj)
        obj.Ptchs.ptchOpts=obj.o;
        obj.prps=struct();
    end
    function set(obj,prp,val,ind)
        if nargin < 4
            ind=[];
        end
        prp=obj.prp_expand(prp);
        val=obj.val_expand(val);
        obj.set_prp_fun(prp,val,ind,true);
        obj.bNeedsSave=true;

    end
    function reset(obj,prp,ind)
        if nargin < 3
            ind=[];
        end
        prp=obj.prp_expand(prp);
        val=getfield(obj.o.ptchOpts,prp{:});
        obj.set_prp_fun(prp,val,ind,false);

    end
    function toggle(obj,prp,vals,ind)
        if nargin >= 3
            [vals,bMany,All]=obj.vals_expand(vals);
        end
        if nargin < 4
            ind=[];
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
        obj.set_prp_fun(prp,new,ind,true);
        obj.bNeedsSave=true;
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
    function set_prp_fun(obj,prp,val,ind,bSet)
        if nargin < 4
            ind=[];
        end
        if isempty(ind)

            %% SET
            obj.Ptchs.ptchOpts=setfield(obj.Ptchs.ptchOpts,prp{:},val);

            %% SET PRP
            if bSet
                obj.prps=setfield(obj.prp,prp{:},val);
            else
                if length(prp) > 1
                    F=getfield(obj.prp,prp{1:end-1});
                    F=rmfield(F,prp{end});
                    obj.prps=setfield(obj.prp,prp{1:end-1},F);
                elseif length(prp) == 1
                    obj.prps=rmfield(obj.prps,prp{:});
                end
            end

            return

        end

        %% CHECK IND
        F=getfield(obj.Ptchs.ptchOpts,prp{:});
        n=length(obj.Ptchs.Blk.blk);
        if n > ind
            error('ind out of bounds')
        end

        %% SET
        if size(F,1) == 1
            F=repmat(F,n,1);
            obj.Ptchs.ptchOpts=setfield(obj.Ptchs.ptchOpts,prp{:},F);
        end
        obj.Ptchs.ptchOpts=setfield(obj.Ptchs.ptchOpts,prp{:},{ind,':'},val);

        %% SET PRP
        obj.prps=setfield(obj.prp,prp{:},{ind,':'},val);
        F=getfield(obj.prp,prp{:});
        if ~bSet && isUniform(F)
            if length(prp) > 1
                F=getfield(obj.prp,prp{1:end-1});
                F=rmfield(F,prp{end});
                obj.prps=setfield(obj.prp,prp{1:end-1},F);
            elseif length(prp) == 1
                obj.prps=rmfield(obj.prps,prp{:});
            end
        end

    end

end
end
