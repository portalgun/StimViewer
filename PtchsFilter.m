classdef PtchsFilter < handle
properties
    idx
    ptchs
    Blk

    mode

    N=struct()
    n=struct()
    size=struct()
    flds=struct()
    pind=struct()

    rel=struct()
    abs=struct()

    bind=struct()
    sind=struct()

    fltrsStr=cell(0,1)
    fltrs=cell(0,5) % id=[fld,sign,crit, bOR,fltrMode]
    fltrsIdx=struct('idx',zeros(0),'blk',zeros(0))
    fltrvalsOR=struct('idx',false(0),'blk',false(0))
    fltrvalsAND=struct('idx',false(0),'blk',false(0))

    srtrs=cell(0,3) % id=[fld,bRev, fltrMode]
    srtvals=struct('idx',false(0),'blk',false(0))

    msg
%end
%properties(Access=private)
    fls=struct()
    rng=struct()
    bInit=false
end
methods
    function obj=PtchsFilter(ptchs, moude)
        obj.ptchs=ptchs;
        if nargin > 1
            obj.init(moude);
        end
    end
    function init(obj, moude)
        if nargin >= 2
            obj.mode=moude;
        elseif obj.ptchs.bBlk
            obj.mode='blk';
        else
            obj.mode='idx';
        end

        obj.N.idx=size(obj.ptchs.fnames,1);
        obj.size.idx=uint32([obj.N.idx,1]);
        obj.fls.idx=false(obj.size.idx);
        obj.rng.idx=uint32(1:obj.N.idx)';
        obj.idx=obj.ptchs.idx;
        obj.flds.idx=fieldnames(obj.ptchs.idx);
        obj.pind.idx=uint32(1:obj.N.idx)';
        obj.sind.idx=obj.rng.idx;
        obj.bind.idx=~obj.fls.idx;
        obj.abs.idx=[];
        obj.n.idx=obj.N.idx;

        if obj.ptchs.bBlk
            obj.Blk=obj.ptchs.Blk.blk;
            obj.flds.blk=obj.ptchs.Blk.blk.KEY;
            obj.N.blk=size(obj.Blk,1);
            obj.size.blk=[obj.N.blk,1];
            obj.fls.blk=false(obj.size.blk);
            obj.bind.blk=~obj.fls.blk;
            obj.rng.blk=uint32(1:obj.N.blk)';
            obj.sind.blk=obj.rng.blk;
            obj.pind.blk=uint32(obj.Blk('P').ret);
            obj.abs.blk=[];
            obj.n.blk=obj.N.blk;
            obj.pind.unq=uint32(unique(obj.Blk('P').ret(),'stable'));
            obj.size.unq=size(obj.pind.unq);
            obj.N.unq=size(obj.pind.unq,1);
            obj.rng.unq=uint32(1:obj.N.unq);
            obj.sind.unq=obj.rng.unq;
            obj.fls.unq=false(obj.size.unq);
            obj.bind.unq=~obj.fls.unq;
            obj.abs.unq=[];
            obj.n.unq=obj.N.unq;
        end
        obj.rel.(obj.mode)=1;

        obj.rel_to_abs();
        obj.update_abs_fun();
        obj.update_rel_fun();


        obj.bInit=true;
    end
%% GET
    function msg=returnMsg(obj)
        msg=obj.msg;
    end
    function [pos,n]=getPos(obj)
        if ~obj.bInit; obj.init(); end

        pos=obj.rel.(obj.mode);
        n=obj.n.(obj.mode);
    end
    function [pos,n]=getAbs(obj)
        if ~obj.bInit; obj.init(); end

        pos=obj.abs.(obj.mode);
        n=obj.n.(obj.mode);
    end
    function [pidx,N]=getPidx(obj)
        if ~obj.bInit; obj.init(); end

        pidx=obj.pind.idx(obj.abs.idx);
        N=obj.N.idx;
    end
    function pidx=getLoadIdx(obj)
        if ~obj.bInit; obj.init(); end

        if ~obj.ptchs.bBlk
            pidx=obj.getPidx();
        else
            pidx=obj.abs.blk;
        end
        if numel(pidx) > 1
            pidx=pidx(1); % OPTION FOR MULTIPLE?
        end
    end
%% MOVE
    function abs=first(obj)
        if ~obj.bInit
            obj.init();
        end
        abs=obj.goto(1);
    end
    function abs=last(obj)
        if ~obj.bInit
            obj.init();
        end
        abs=obj.goto('last');
    end
    function abs=prev(obj)
        if ~obj.bInit
            obj.init();
        end
        abs=obj.goto( obj.rel.(obj.mode)  - 1 );

    end
    function abs=next(obj)
        if ~obj.bInit
            obj.init();
        end
        abs=obj.goto( obj.rel.(obj.mode)  + 1 );
    end
    function abs=goto(obj,rel)
        if ~obj.bInit
            obj.init();
        end
        n=obj.n.(obj.mode);
        if ischar(rel) && strcmp(rel,'last')
            rel=n;
        elseif ischar(rel) && strcmp(rel,'first')
            rel=1;
        end
        if rel > n
            rel=n;
        elseif rel < 1
            rel=1;
        end
        obj.rel.(obj.mode)=rel;
        obj.rel_to_abs();
        obj.update_abs_fun();
        obj.update_rel_fun();

        abs=obj.abs.(obj.mode);
    end
%% CHANGE MODE
    function toggleMode(obj)

        switch obj.mode
        case 'idx'
            obj.changeMode('blk');
        case 'blk'
            obj.changeMode('unq');
        case 'unq'
            obj.changeMode('idx');
        end
    end
    function changeMode(obj,moude)

        % GET ABS
        curP=obj.pind.(obj.mode)(obj.abs.(obj.mode));
        obj.mode=moude;
        obj.abs.(moude)=find(obj.pind.(moude)==curP,1,'first');
        obj.update_abs_fun();


        % FILTER
        if ~isempty(obj.fltrs)
            fltrMode=obj.refilter_fun();
        end

        % UPDATE BIND in refilter fun

        % GET ABS
        obj.abs_to_nearest();
        if isempty(obj.abs.(obj.mode))
            moude=fltrMode;
            obj.abs_to_nearest(fltrMode);
        else
            moude=[];
        end
        obj.update_abs_fun(moude);

        % SORT
        obj.resort_fun();

        % UPDATE SIND in refilter fun

        % GET REL
        obj.abs_to_rel(moude);
        obj.update_rel_fun(moude);

    end
%% FILTER
    function [msg,abs]=filter(obj,fld,sign,crit,bOR)
        % TODO SPLIT IF NO SPACES
        % TODO bOR IF FIRST
        if nargin < 5
            bOR=[];
        end

        msg='';
        abs=obj.abs.(obj.mode);

        % ARGS
        if nargin < 4
            obj.msg=['Incorrect number of filter arguments (' num2str(nargin) '). 3 required (fld sign crit .'];
            msg=obj.msg;
            return
        end
        if ~isempty(sign)
            sign='=';
        elseif ~ismember(sign,{'=','==','>','>=','<=','<'})
            obj.msg=['Invalid sign ' sign ];
            msg=obj.msg;
            return
        end

        % GET FLTRMODE
        if obj.ptchs.bBlk && ismember(fld,obj.flds.blk)
            fltrMode='blk';
        elseif ismember(fld,obj.flds.idx) || ismember(fld,{'SEEN','seen','bad','other'});
            fltrMode='idx';
        else
            obj.msg=['Invalid field ' fld ];
            return
        end

        % INIT
        if ~obj.bInit
            obj.init();
        end

        % FILTER
        [exitflag,obj.msg]=obj.filter_fun(fld,sign,crit,bOR,fltrMode);
        if exitflag
            msg=obj.msg;
            return
        end

        % GET BIND
        obj.update_bind(fltrMode,bOR);

        % GET ABS
        obj.abs_to_nearest();
        if isempty(obj.abs.(obj.mode))
            moude=fltrMode;
            obj.abs_to_nearest(fltrMode);
        else
            moude=[];
        end
        obj.update_abs_fun(moude);

        % GET REL
        obj.abs_to_rel(moude);
        obj.update_rel_fun(moude);

        abs=obj.abs.(obj.mode);

    end
    function abs=unfilter(obj)
        if ~obj.bInit
            obj.init();
        end
        obj.bind.idx=~obj.fls.idx;
        obj.bind.blk=~obj.fls.blk;
        obj.bind.unq=~obj.fls.unq;

        obj.n.idx=obj.N.idx;
        obj.n.unq=obj.N.unq;
        obj.n.blk=obj.N.blk;



        obj.fltrs=cell(0,3);
        obj.fltrsStr=cell(0,1);
        obj.fltrvalsAND.blk=false(0);
        obj.fltrvalsAND.idx=false(0);
        obj.fltrvalsOR.blk=false(0);
        obj.fltrvalsOR.idx=false(0);

        % ABS
        obj.abs_to_nearest();
        obj.update_abs_fun();

        % REL
        obj.abs_to_rel();
        obj.update_rel_fun();

        abs=obj.abs.(obj.mode);
    end
    function abs=rmFilter(obj,fld,sign,crit,bOR)

        T=true(size(obj.fltrs,1),1);
        if nargin < 2
            fldIdx=T;
        else
            fldIdx=ismember(obj.fltrs(:,1),fld); % fld sign Num crit
        end
        if nargin < 3
            signIdx=T;
        else
            if strcmp(sign,'=')
                sign='==';
            end
            signIdx=ismember(obj.fltrs(:,2),sign); % fld sign Num crit
        end
        if nargin < 4
            critIdx=T;
        else
            critIdx=ismember(obj.fltrs(:,3),num2str(crit)); % fld sign Num crit
        end
        if nargin < 5
            orIdx = T;
        else
            orIdx=ismember(obj.fltrs(:,4),bOR); % fld sign Num crit
        end
        ind=fldIdx & signIdx & critIdx & orIdx;
        if nargin < 5
            bOR=obj.fltrs{ind,4};
        end
        fltrMode=obj.fltrs{ind,5};

        obj.rm_filter(fltrMode,ind,bOR);

        abs=obj.abs.(obj.mode);
    end
    function abs=rmSort(obj,fld)
        if obj.ptchs.bBlk && ismember(fld,obj.flds.blk)
            fltrMode='blk';
        elseif ismember(fld,obj.flds.idx)
            fltrMode='idx';
        else
            msg=['Invalid field ' fld ];
            obj.msg=msg;
            abs=obj.abs.(obj.mode);
            return
        end

        ind=ismember(obj.srtrs(:,1),fld);
        obj.srtvals.(fltrMode)(ind,:)=[];
        obj.srtrs(ind,:)=[];
        obj.resort_fun();
        abs=obj.abs.(obj.mode);
    end
%% SORT
    function [msg,abs]=sort(obj,fld,bRev)
        if nargin < 2
            bRev=[];
        end

        % GET FLTRMODE
        if obj.ptchs.bBlk && ismember(fld,obj.flds.blk)
            fltrMode='blk';
        elseif ismember(fld,obj.flds.idx)
            fltrMode='idx';
        else
            msg=['Invalid field ' fld ];
            obj.msg=msg;
            abs=obj.abs.(obj.mode);
            return
        end

        % INIT
        if ~obj.bInit
            obj.init();
        end

        % SORT
        [exitflag,obj.msg]=obj.sort_fun(fld,bRev,fltrMode);
        if exitflag
            msg=obj.msg;
            abs=obj.abs.(obj.mode);
            return
        end

        % GET SIND
        obj.update_sind(fltrMode); % XXX
        % size(obj.sind.idx) % XXX

        % GET REL
        if isempty(obj.abs.(obj.mode))
            moude=fltrMode;
        else
            moude=obj.mode;
        end

        obj.abs_to_rel(moude);
        obj.update_rel_fun(moude);

        msg='';
        abs=obj.abs.(obj.mode);
    end
    function abs=unsort(obj)
        if ~obj.bInit
            obj.init();
        end
        obj.sind.idx=obj.rng.idx;
        obj.sind.blk=obj.rng.blk;
        obj.sind.unq=obj.rng.unq;

        obj.srtrs=cell(0,2);
        obj.srtvals.blk={};
        obj.srtvals.idx={};

        % REL
        obj.abs_to_rel();
        obj.update_rel_fun();

        abs=obj.abs.(obj.mode);
    end
end
methods(Access=private)
    function rel_to_abs(obj)
        sind=obj.sind.(obj.mode);
        sbind=obj.bind.(obj.mode)(sind);
        inds=find(sbind, obj.rel.(obj.mode));
        absSrt=inds(end); % FIND SORTED ABSOLUTE
        obj.abs.(obj.mode)= sind(absSrt); % UNSORT SORTED ABSOLUTE
    end
    function abs_to_rel(obj,fltrMode)
        if nargin > 1 && ~isempty(fltrMode)
            moude=fltrMode;
        else
            moude=obj.mode;
        end
        pos=obj.abs.(moude);
        if pos==0
            obj.rel.(moude)=0;
            return
        end
        if isfield(obj.rel,moude)
            oldrel=obj.rel.(moude);
        end

        sind=obj.sind.(moude);
        sbind=obj.bind.(moude)(sind);
        absInd=false(size(sbind));
        absInd(pos)=true;
        absSrt=absInd(sind);
        absSrt=absSrt(sbind);

        obj.rel.(moude)=find(absSrt);
        if numel(obj.abs.(moude))==1 && numel(obj.rel.(moude)) > 1
            d=abs(oldrel-obj.rel.(moude));
            ind=find(d==min(d),1,'first');
            obj.rel.(moude)=obj.rel.(moude)(ind);
        end

        %obj.abs.(obj.mode)
        %obj.rel.(obj.mode)
    end
    function abs_to_nearest(obj,fltrMode)
        % FOR FILTERING
        % ALL IN ABSOLUTE
        if nargin > 1 && ~isempty(fltrMode)
            moude=fltrMode;
        else
            moude=obj.mode;
        end
        old=obj.abs.(moude);
        bind=obj.bind.(moude);
        ind=find( bind(old:end), 1,'first');

        if ~isempty(ind)
            obj.abs.(moude)=old - 1 + ind;
        else
            obj.abs.(moude)=find( bind(1:old-1 ), 1,'first');
        end
    end
    function update_bind(obj,fltrMode,bOR)
        if isempty(bOR)
            bOR=false;
        end
        if bOR
            lfld='fltrvalsOR';
        else
            lfld='fltrvalsAND';
        end

        switch fltrMode
        case 'idx'
            obj.bind.blk=ismember(obj.pind.blk, obj.pind.idx(obj.bind.idx));
            obj.bind.unq=ismember(obj.pind.unq, obj.pind.idx(obj.bind.idx));

            obj.n.blk=sum(obj.bind.blk);
            obj.n.unq=sum(obj.bind.unq);

            % update fltrsvals
            %obj.pind.blk
            %obj.pind.idx
            % fltrsvalsAnd
            % 0 0
            %size(obj.(lfld).idx) % 0
            %size(obj.pind.idx)   % 49345 1
            obj.(lfld).blk(:,end+1)=ismember(obj.pind.blk, obj.pind.idx(obj.(lfld).idx(:,end)));
        case 'blk'
            obj.bind.idx=obj.fls.idx;
            obj.bind.idx( obj.pind.blk(obj.bind.blk) )=true;
            obj.bind.unq=ismember(obj.pind.unq, obj.pind.idx(obj.bind.idx));

            obj.n.idx=sum(obj.bind.idx);
            obj.n.unq=sum(obj.bind.unq);
            obj.(lfld).blk(:,end+1)=ismember(obj.pind.blk, obj.pind.idx(obj.(lfld).idx));

            % update fltrsvals
            obj.(lfld).idx=obj.fls.idx;
            obj.(lfld).idx( obj.pind.blk(obj.(lfld).blk), end+1 )=true;
        %case 'unq'
        %    obj.bind.idx=obj.fls.idx;
        %    obj.bind.idx( obj.pind.blk(obj.bind.unq) )=true;
        %    obj.bind.blk=ismember(obj.pind.blk, obj.pind.idx(obj.bind.idx));

        %    obj.n.idx=sum(obj.bind.idx);
        %    obj.n.blk=sum(obj.bind.blk);
        end
    end
    function update_sind(obj,fltrMode)
        if nargin < 2 && strcmp(obj.mode,'unq')
            fltrMode='blk';
        elseif nargin < 2
            fltrMode=obj.mode;
        end
        % BIND DOES NOT PLAY A ROLE
        % ALWAYS USING FLTRMODE

        sind=obj.sind.(fltrMode);
        srtPind=obj.pind.(fltrMode)(sind);

        switch fltrMode
        case 'idx'
            % GOOD
            [~,ind]=ismember(srtPind,obj.pind.unq);
            unq=ind(logical(ind));
            obj.sind.unq=unq;


            % GOOD ?
            OUT=arrayfun(@(u) find(obj.pind.blk==u), obj.pind.unq(unq),'UniformOutput',false);
            obj.sind.blk=vertcat(OUT{:});
        case 'blk'
            % XXX
            %vals=unique(srtPind,'stable')
            [~,ind]=ismember(srtPind,obj.pind.unq);
            unq=ind(logical(ind));
            [unq,~]=unique(unq,'stable');
            obj.sind.unq=unq;

            % XXX
            [~,ind]=ismember(unq, obj.pind.idx);
            obj.sind.idx=ind(logical(ind));
        end

    end
    function update_abs_fun(obj,fltrMode)
        if nargin > 1 && ~isempty(fltrMode)
            moude=fltrMode;
        else
            moude=obj.mode;
        end
        pos=obj.abs.(moude);
        pU=obj.pind.unq;
        pI=obj.pind.idx;
        pB=obj.pind.blk;
        switch moude
        case 'idx'
            [~,obj.abs.unq]=ismember(obj.pind.idx(pos),pU);
            obj.abs.blk=find(ismember(pB, obj.pind.idx(pos)));
            if isempty(obj.abs.blk)
                obj.abs.blk=0;
            end
        case 'blk'
            [~,obj.abs.idx]=ismember( obj.pind.blk(pos), pI );
            [~,obj.abs.unq]=ismember( obj.pind.idx(obj.abs.idx), pU );
        case 'unq'
            %[obj.abs.blk]=find(ismember(obj.pind.unq(pos), pB));
            obj.abs.blk=find(ismember(pB, obj.pind.unq(pos)));
            [~,obj.abs.idx]=ismember(obj.pind.unq(pos),pI);
            %obj.abs.idx=find(ismember(pI, obj.pind.unq(pos) ),1,'first');
        end

    end
    function update_rel_fun(obj,fltrMode)
        % MUST COME AFTER UPDATE ABS
        if nargin > 1 && ~isempty(fltrMode)
            moude=fltrMode;
        else
            moude=obj.mode;
        end
        switch moude
        case 'idx'
            obj.abs_to_rel('blk');
            obj.abs_to_rel('unq');
        case 'blk'
            obj.abs_to_rel('idx');
            obj.abs_to_rel('unq'); % XXX
        case 'unq'
            obj.abs_to_rel('idx');
            obj.abs_to_rel('blk');
        end
    end
    function [exitflag,msg]=filter_fun(obj,fld,sign,crit,bOR,fltrMode)
        exitflag=false;
        msg=[];

        % ARGS
        if isempty(bOR)
            bOR=false;
        end
        if isempty(sign) || strcmp(sign,'=')
            sign='==';
        end

        id={fld,sign,Num.toStr(crit)};
        strId=[fld sign Num.toStr(crit)];
        if ismember(strId,obj.fltrsStr)
            msg='Filter has already been applied';
            exitflag=true;
            return
        end

        if strcmp(fltrMode,'blk')
            vals=obj.Blk(fld).ret();
        elseif ismember(fld,{'SEEN','seen','other','bad'})
            vals=obj.ptchs.Flags.(fld);
        elseif strcmp(fltrMode,'idx')
            vals=obj.idx.(fld);
        end

        % EVAL
        cmd=sprintf('vals %s crit;',sign);
        try
            bind=eval(cmd);
        catch ME
            rethrow(ME);
        end
        if sum(bind)<1 && ~bOR
            exitflag=true;
            msg='Filter returned no results';
            return
        end


        if bOR
            bindNew=obj.bind.(fltrMode) | bind;
            valsFld='fltrvalsOR';
        else
            bindNew=obj.bind.(fltrMode) & bind;
            valsFld='fltrvalsAND';
        end
        if sum(bindNew)<1
            exitflag=true;
            msg='Filter returned no results';
            return
        end

        %if ~bOR && size(obj.fltrs,1) > 0
        %    % REPLACE CONFLICTING
        %    sameIdx=ismember(obj.fltrs(:,1),fld)  && ...
        %            ismember(obj.fltrs(:,2),sign) && ...
        %            ~vertcat(obj.fltrs{:,4});
        %    if any(sameIdx)
        %        obj.rm_filter(fltrMode,sameIdx,bOR);
        %    end
        %end

        obj.bind.(fltrMode)=bindNew;
        obj.(valsFld).(fltrMode)(:,end+1)=bind;
        obj.fltrsIdx.(fltrMode)(end+1,1)=size(obj.(valsFld).(fltrMode),2);
        obj.fltrsStr{end+1,1}=strId;
        obj.fltrs(end+1,:)=[id,bOR,fltrMode];
        obj.n.(fltrMode)=sum(obj.bind.(fltrMode));

    end
    function [exitflag,msg]=sort_fun(obj,fld,bRev,fltrMode)
        exitflag=false;
        msg=[];
        if isempty(bRev)
            bRev=false;
        end

        id={fld,Num.toStr(bRev)};
        ind=ismember(fld,obj.srtrs(:,1));

        % REVERSE EXISTING SORT
        if ind & ~strcmp(obj.srtrs(ind,2), Num.toStr(bRev))
            obj.srtvals.(fltrMode)(:,ind)=flipud(obj.srtvals.(fltrMode)(:,ind));
            obj.srts(ind,2)=Num.toStr(~str2double(obj.srtrs(ind,2)));
            return
        end

        if strcmp(fltrMode,'blk')
            val=obj.Blk(fld).ret();
        elseif strcmp(fltrMode,'idx')
            val=obj.idx.(fld);
        end
        if bRev
            obj.srtvals.(fltrMode)(:,end+1)=flipud(val);
        else
            obj.srtvals.(fltrMode)(:,end+1)=val;
        end
        if size(obj.srtvals.(fltrMode),2) > 1
            vals=obj.srtvals.(fltrMode);
            [~,ind]=sortrows(vals);
        else
            [~,ind]=sort(val);
        end
        obj.sind.(fltrMode)=ind;
        obj.srtrs(end+1,:)=[id,fltrMode];

        %val(obj.sind.(fltrMode))
        %size(obj.srtvals.(fltrMode))
        %imagesc(val(obj.sind.(fltrMode)));
    end
    function [fltrMode,msg,exitflag]=refilter_fun(obj)
        obj.unfilter();

        msg='';
        for i = 1:size(obj.fltrs,1)
            fld=obj.fltrs(i,1);
            sign=obj.fltrs(i,2);
            crit=obj.fltrs(i,3);
            bOR=obj.fltrs(i,4);
            fltrMode=fltr(i,5); %fltrmode independent of obj.mode

            [exitflag,m]=obj.filter_fun(fld,sign,crit,bOR,fltrMode);
            if ~isempty(m)
                msg=[msg newlinem m];
            end

            obj.update_bind(fltrMode,bOR);
            if exitflag
                error('This should ont happen')
            end
        end
    end
    function msg=resort_fun(obj)
        obj.unsort();
        % fld, bRev, fltrMOde

        msg='';
        for i = 1:size(obj.srtrs,1)
            fld=obj.srtrs(i,1);
            bRev=str2double(obj.srtrs(i,2));
            fltrMode=fltrMode(obj.srtrs(i,3));

            [exitflag,m]=obj.sort_fun( fld, bRev, fltrMode);
            if ~isempty(m)
                msg=[msg newlinem m];
            end
            obj.update_sind(fltrMode);
            if exitflag
                error('This should ont happen')
            end
        end
    end
    function rm_filter(obj,fltrMode,sameIdx,bOR)
        Idx=obj.fltrsIdx.(fltrMode)(sameIdx);

        obj.fltrsIdx.(fltrMode)(sameIdx,:)=[];
        obj.fltrs(sameIdx,:)=[];
        obj.fltrsStr(sameIdx,:)=[];

        if bOR
            obj.fltrvalsOR.(fltrMode)(:,Idx)=[];
        else
            obj.fltrvalsAND.(fltrMode)(:,Idx)=[];
        end

        obj.fltrsIdx.(fltrMode)(obj.fltrsIdx.(fltrMode)>sameIdx)=obj.fltrsIdx.blk(obj.fltrsIdx.(fltrMode)>sameIdx)-1;
        obj.refilter_fun();
    end
%% XXX

    function update_loaded(obj,nInds,nnInds)
        if ~isempty(nnInds)
            obj.clear_blk(nnInds);
        end
        if ~isempty(nInds)
            obj.load_trials(nInds);
        end
    end
    function update_trl_loaded(obj,trl,intrvls)
        if nargin < 3
            intrvls=[];
        end
        [nInds,nnInds]=obj.get_loaded_status(trl,intrvls);

        obj.update_loaded(nInds,nnInds);
    end
    function [nInds,nnInds]=get_loaded_status(obj,stmInd)
        % NOT NEEDED (unload)
        nnInds=loadedInd(~ismember(loadedInd,stmInd));

        % NEEDED (to load)
        nInds=stmInd(~ismember(stmInd,laodedInd));
    end
    function [nInds,nnInds]=get_trl_loaded_status(obj,trl,intrvls)
        loadedInd=find(obj.bLoadedB);
        if isempty(loadedInd)
            return
        end
        if nargin < 3
            intrvls=[];
        end
        stmInd=obj.get_stmInd(trls,intrvls);

        [nInds,nnInds]=obj.get_loaded_status(stmInd);

    end
    function obj=clear_not_needed(obj,trls,intrvls)
        loadedInd=find(obj.bLoadedB);
        if isempty(loadedInd)
            return
        end
        if nargin < 3
            intrvls=[];
        end
        stmInd=obj.get_stmInd(trls,intrvls);
        inds=loadedInd(~ismember(loadedInd,stmInd));

    end
end
end
