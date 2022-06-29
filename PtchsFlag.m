classdef PtchsFlag < handle
properties
    SEEN
    seen
    bad
    poor
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
        if nargin > 1
            return
        end
        obj.Ptchs=ptchs;
    end
    function setFilter(obj,filter)
        obj.Filter=filter;
    end
    function get(obj)
        fname=obj.get_fname();
        if Fil.exist(fname)
            obj.load();
        else
            obj.reset();
        end
        %obj.proc_bad_files();
    end
    function out=get_needs_save(obj)
        cur=[ sum(obj.seen) sum(obj.bad) sum(obj.other)];
        out= obj.lastSave(1) + 1 < cur(1) || ~isequal(obj.lastSave(2:3),cur);
    end
    function reset(obj)
        obj.bad=false(size(obj.Ptchs.fnames));
        obj.poor=false(size(obj.Ptchs.fnames));
        obj.other=zeros(size(obj.Ptchs.fnames));
    end
    function reset_seen(obj)
        obj.seen=zeros(size(obj.Ptchs.fnames));
    end
    function accum_seen_other(obj)
        obj.other=obj.other | obj.seen;
        obj.seen=zeros(size(obj.Ptchs.fnames));
    end
    function accum_seen_SEEN(obj)
        obj.SEEN=obj.SEEN | obj.seen;
        obj.seen=zeros(size(obj.Ptchs.fnames));
    end
    function accum_other_SEEN(obj)
        obj.SEEN=obj.SEEN | obj.other;
        obj.other=zeros(size(obj.Ptchs.fnames));
    end
    function fnames=proc_bad_files(obj)
        % XXX rm?
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
        S=load(fname);
        if obj.Ptchs.exist_badGen();
            bBad=obj.Ptchs.load_badGen();
            S.bad=S.bad | bBad;
        end
        obj.seen=S.seen;
        obj.bad=S.bad;
        obj.other=S.other;
        if isfield(S,'poor')
            obj.poor=S.poor;
        else
            obj.poor=false(size(obj.bad));
        end
        if isfield(S,'SEEN')
            obj.SEEN=S.SEEN;
        else
            obj.SEEN=false(size(obj.seen));
        end
    end
    function msg=save(obj,bBackup)
        if nargin < 2
            bBackup=[];
        end
        fname=obj.get_fname(bBackup);
        bad=obj.bad;
        seen=obj.seen;
        SEEN=obj.SEEN;
        other=obj.other;
        poor=obj.poor;

        save(fname,'bad','seen','poor','other','SEEN');
        obj.lastSave=[ sum(seen) sum(bad) sum(other)];
        if nargout > 0
            msg='Saved.';
        end
    end
    function fname=get_fname(obj,bBackup);
        if nargin < 2 || isempty(bBackup)
            bBackup=false;
        end
        if bBackup
            bstr=['bk_' strrep(char(datetime),' ','_') '_'];
        else
            bstr='';
        end
        fname=[obj.Ptchs.get_dir() '_flags_' bstr '.mat'];
    end
    function replace_flagged(obj,defName)
        % XXX
        replaceBinds=obj.idx.flags==1;
        B=Blk(defName,replaceBinds,1);
    end
%% OTHER
    function inc_other(obj)
        pidx=obj.Filter.getPidx();
        obj.other(pidx)=obj.other(pidx)+1;
    end
    function dec_other(obj)
        pidx=obj.Filter.getPidx();
        obj.other(pidx)=obj.other(pidx)-1;
    end
    function reset_other(obj)
        pidx=obj.Filter.getPidx();
        obj.other(pidx)=0;
    end
%% SEEN
    function inc_seen(obj, val)
        pidx=obj.Filter.getPidx();
        obj.seen(pidx)=obj.seen(pidx)+1;
    end
%% BAD
    function toggle_bad(obj, val)
        if nargin < 2
            val=[];
        end
        obj.toggle_fun('bad',val);
    end
%% POOR
    function toggle_poor(obj, val)
        if nargin < 2
            val=[];
        end
        obj.toggle_fun('poor',val);
    end
end
methods(Access=private)
    function toggle_fun(obj,fld, val)
        pidx=obj.Filter.getPidx();
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
