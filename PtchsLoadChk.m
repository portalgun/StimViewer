classdef PtchsLoadChk < handle
% XXX SEE FILTER
% TODO KEEP nback
properties
    loadTime
    loadRule
end
properties(Access=private)
    Viewer
    Filter
    Ptchs
    Blk
end
methods
    function obj=PtchsLoadChk(viewer)
        obj.Viewer=viewer;
        obj.Filter=viewer.Filter;
        obj.Ptchs=viewer.Ptchs;
        obj.Blk=viewer.Ptchs.Blk;
    end
end
methods(Hidden)
    function time=trl_load_check(obj,n,trl)
        start=obj.get_secs;

        trls=trl:(trl+n-1);

        % Get needed trials
        blkInd=obj.Blk.blk.find('trl',trls);
        bBlkInd=false(size(obj.Ptchs.bLoadedB));
        bBlkInd(blkInd)=true;

        % GET NEEDED & NOT NEEDED
        nInds=~obj.Ptchs.bLoadedB && blkInd;
        nnInds=obj.Ptchs.bLoadedB && ~blkInd;

        obj.load(nInds,nnInds,start);
        time=obj.loadTime;

    end
    function load(obj,nInds,nnInds,startTime)
        if nargin < 4 || isempty(startTime)
            startTime=get_secs;
        end
        obj.load_patches(nInds);
        obj.clear_patches(nnInds);

        obj.loadTime=obj.get_secs()-startTime;
    end
    function trls=get_rel_trials(obj,loadRule,trl)
        % XXX NOTE USED
        trl=obj.Viewer.trl;
        switch obj.loadRule
        case 'expStart'
            trls=1:obj.get_nTrial;
        case 'reset'
            if trl==0; trl=1; end;
            trls=trl:(trl+obj.n-1);
        case 'trlStart'
            trls=trl;
        case 'prev'
            trls=trl;
        case 'n'
            trls=trl:(trl+n-1);
        end
    end
    function time=get_secs(obj)
        if obj.Viewer.bPsy
            time=GetSecs;
        else
            time=0;
            % TODO
        end
    end
end
end
