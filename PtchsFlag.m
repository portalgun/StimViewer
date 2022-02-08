classdef PtchsFlag < handle
properties
    seen
    bad
    other

    lastSave=[0 0 0]
end
properties(Access=private)
    badFiles
    Ptchs
    Filter
end
methods
    function obj=PtchsFlag(ptchs)
        obj.Ptchs=ptchs;
    end
    function setFilter(obj,filter)
        obj.Filter=filter;
    end
    function get(obj)
        fname=obj.Ptchs.get_fname();
        if Fil.exist(fname)
            obj.load();
        else
            obj.reset();
        end
        obj.proc_bad_files();
    end
    function out=get_needs_save(obj)
        cur=[ sum(obj.seen) sum(obj.bad) sum(obj.other)];
        out= obj.lastSave(1) + 1 < cur(1) || ~isequal(obj.lastSave(2:3),cur);
    end
    function reset(obj)
        obj.seen=false(size(obj.Ptchs.fnames));
        obj.bad=false(size(obj.Ptchs.fnames));
        obj.other=zeros(size(obj.Ptchs.fnames));
    end
    function fnames=proc_bad_files(obj)
        dire=obj.Ptchs.get_dir();
        badFiles=Fil.find(dire,'.*\.bad');
        if isempty(obj.badFiles)
            return
        end
        badNames=strrep(badFiles,'.bad','');
        idx=ptch.names2nums(obj.Ptchs.hashes.database,obj.Ptchs.hashes.tbl,badNames);
        obj.bad(idx)=true;
        obj.save();
        full=strcat(dire,badFiles);
        cellfun(@delete,full);
    end
    function load(obj)
        fname=obj.get_fname();
        load(fname);
        obj.seen=seen;
        obj.bad=bad;
        obj.other=other;
    end
    function msg=save(obj)
        fname=obj.get_fname();
        bad=obj.bad;
        seen=obj.seen;
        other=obj.other;

        save(fname,'bad','seen','other');
        obj.lastSave=[ sum(seen) sum(bad) sum(other)];
        if nargout > 0
            msg='Saved.';
        end
    end
    function fname=get_fname(obj);
        fname=[obj.Ptchs.get_dir() '_flags_.mat'];
    end
    function replace_flagged(obj,defName)
        % XXX
        replaceBinds=obj.idx.flags==1;
        B=Blk(defName,replaceBinds,1);
    end
    function toggle_other(obj, val)
        [pidx,pidxBlk,abs,rel,n]=obj.Filter.getPidx();
        if nargin < 2
            obj.other=obj.other(pidx)+1;
        else
            obj.other=val;
        end
        obj.toggle_fun('seen',val);
    end
    function toggle_seen(obj, val)
        if nargin < 2
            val=[];
        end
        obj.toggle_fun('seen',val);
    end
    function toggle_bad(obj, val)
        if nargin < 2
            val=[];
        end
        obj.toggle_fun('bad',val);
    end
end
methods(Access=private)
    function toggle_fun(obj,fld, val)
        obj
        [pidx,pidxBlk,abs,rel,n]=obj.Filter.getPidx();
        if ~isempty(val)
            obj.(fld)(pidx)=val;
        elseif obj.(fld)(pidx)
            obj.(fld)(pidx)=false;
        else
            obj.(fld)(pidx)=true;
        end
    end
end
end
