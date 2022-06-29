classdef PtchsInfo < handle
properties

    lidx
    N
    pidx
    n
    abs
    rel

    seen
    bad
    poor
    other
    nSeen
    nFlags

    subj


    nTrial
    stds
    cmps
    intrvls

    trl
    int
    s
    stdX
    cmpX
    cmpIntrvl
    bMotion

    srtrs
    fltrs
    fltrMode

    lastTime
    lastTimeStr=''
    lastTrl=-1
    lastInt=-1
    lastS=-1;

    %-------
    % Filter
    filterInfo=''
    srtInfo=''
    indexInfo=''
    trlInfo=''

    % selected
    selInfo=''

    % INT
    intInfo=''
    timeInfo=''
    rspInfo=''
    rspFlagInfo=''


    % FLAG
    flagInfo=''

    % PTCH
    idxInfo=''
    srcInfo=''
    blkInfo=''
    statInfo=''

    % WIN
    tfInfo=''
    subjInfo=''
    winInfo=''

    % IM
    phtInfo=''
    imInfo=''
    wdwInfo=''

    % CMD
    cmdInfo=''
    %STR
    strInfo=''
    %KEY
    keyInfo=''
    %MSG
    msg=''

    % CONSTANT
    hashInfo=''
    genOpts=''
    dbInfo=''

    STR
    cmdHeightF=38; % XXX TODO GET BAED ON PTB FONT
    cmdMode='normal'
end
properties(Access=private)
    Ptchs
    Cmd
    Echo
    Flags
    Filter
    Blk
    Parent
    bInit=true
end
properties(Constant=true, Hidden)
    div=[newline '-----------------------------' newline];
end
methods
    function obj=PtchsInfo(viewer)
        obj.Parent=viewer;
        obj.Cmd=viewer.Cmd;
        obj.Ptchs=viewer.Ptchs;
        obj.Flags=viewer.Flags;
        obj.Filter=viewer.Filter;
    end
    function update(obj,bUp)
        if obj.bInit
            obj.update_constant();
            obj.bInit=false;
        end

        obj.update_time();
        if ~isempty(obj.msg)
            obj.update_msg();
        end
        for i = 1:numel(bUp)
            obj.(['update_' bUp{i}])();
        end
    end
    function update_msg(obj)
        if isempty(obj.msg) || (iscell(obj.msg) && all(cellfun(@isempty,obj.msg)))
            obj.msg=[' '];
            return
        end
        if iscell(obj.msg)
            obj.msg(cellfun(@isempty,obj.msg))=[];
            if ~isempty(obj.msg);
                obj.msg=strjoin(obj.msg,newline);
            end
        end
        if isempty(obj.msg) || (iscell(obj.msg) && all(cellfun(@isempty,obj.msg)))
            obj.msg=' ';
        end
    end
    function append_msg(obj,msg)
        if isempty(msg)
            return
        end
        if iscell(obj.msg)
            obj.msg(cellfun(@isempty,obj.msg))=[];
            if ~isempty(obj.msg);
                obj.msg=[obj.msg strjoin(obj.msg,newline)];
            end
        else
            obj.msg=msg;
        end
    end
    function update_time(obj)
        s=obj.Parent.PsyInt.sStartT;
        if s==0
            t=s;
        else
            t=round(GetSecs-s,2);
        end
        if isempty(obj.lastTrl)
            flds={'trl','int','s'};
            for i = 1:length(flds)
                obj.(flds{i})=obj.Parent.PsyInt.(flds{i});
            end
            flds={'lastTrl','lastInt','lastS'};
            for i = 1:length(flds)
                obj.(flds{i})=-1;
            end
        end
        if ~isequal(obj.lastTrl,obj.trl) || obj.lastInt > obj.int || obj.lastS > obj.s
            obj.lastTimeStr='';
        elseif obj.int > obj.lastInt || obj.s > obj.lastS
            obj.lastTimeStr=[obj.Parent.PsyInt.lastTime newline];
        end

        obj.timeInfo=[obj.lastTimeStr sprintf('%6.2f',t)];
        %if s~=0
        %    obj.gdTime=obj.timeInfo;
        %end
        obj.lastTime=t;
        obj.lastTrl=obj.trl;
        obj.lastInt=obj.int;
        obj.lastS=obj.s;
    end
%% INFO
    function update_Im(obj)
        obj.update_Psy();
    end
    function update_PsyInt(obj)
    end
    function update_Psy(obj)
        h=obj.Parent.Psy.return_selected_params();
        if isempty(h)
            obj.selInfo='';
            return
        elseif h.type==0
            obj.selInfo=obj.Parent.Im.getInfo(h.name);
        end
    end
    function update_rsp(obj)
        if obj.trl== 0
            return
        end
        [cmp,std,int,answer,flag]=obj.Parent.Rsp.getTrial(obj.trl);
        rI=struct();
        rI.cmp=cmp;
        rI.std=std;
        rI.int=int;
        rI.answer=answer;
        obj.rspInfo=PtchsInfo.struct2TableFun(rI);

        obj.rspFlagInfo=num2str(flag);

        %obj.Parent.Ptchs.Blk('trl',obj.trl)
        %clc
        %if rI.int==2
        %    disp(['std ' num2str(rI.std)])
        %    disp(['cmp ' num2str(rI.cmp)])
        %elseif rI.int==1
        %    disp(['cmp ' num2str(rI.cmp)])
        %    disp(['std ' num2str(rI.std)])
        %end
        %disp(['answer ' num2str(rI.answer)])
    end
    function update_Filter(obj)
        [obj.pidx,obj.N]=obj.Filter.getPidx();
        [obj.rel,obj.n]=obj.Filter.getPos();
        obj.abs=obj.Filter.getAbs();
        obj.lidx=obj.Filter.getLoadIdx;
        obj.fltrMode=obj.Filter.mode;
        obj.srtrs=obj.Filter.srtrs;
        obj.fltrs=obj.Filter.fltrsStr;

        if strcmp(obj.Parent.mode,'IFC')
            obj.stdX=obj.Ptchs.get_stdX(obj.trl);
            obj.cmpX=obj.Ptchs.get_cmpX(obj.trl,1);
            obj.cmpIntrvl=obj.Ptchs.get_cmpIntrvl(obj.trl);
        end

        % FROM FILTER
        fI=struct();

        fI.pidx=obj.pidx;
        fI.(obj.fltrMode)=[num2str(obj.rel) ' / ' num2str(obj.n)];
        fI.seen_prog=[num2str(obj.nSeen) ' / ' num2str(obj.nFlags)];
        obj.filterInfo=strjoin(obj.fltrs,' ');

        if ~isempty(obj.srtrs)
            obj.srtInfo=strjoin(obj.srtrs(:,1),' ');
        else
            obj.srtInfo='';
        end

        obj.indexInfo=PtchsInfo.struct2TableFun(fI);
    end
    function update_Flags(obj)
        [obj.pidx,obj.N]=obj.Filter.getPidx();
        obj.seen=obj.Flags.seen(obj.pidx) > 1;
        obj.bad=obj.Flags.bad(obj.pidx);
        obj.poor=obj.Flags.poor(obj.pidx);
        obj.other=obj.Flags.other(obj.pidx);

        obj.nSeen=sum(obj.Flags.seen > 0);
        obj.nFlags=numel(obj.Flags.seen);

        fI.seen=obj.seen;
        fI.bad=obj.bad;
        fI.poor=obj.poor;
        fI.other=obj.other;
        obj.flagInfo=PtchsInfo.struct2TableFun(fI);
    end
    function update_int(obj)
        [obj.trl,obj.int,obj.s,intInd,sName]=obj.Parent.PsyInt.get_ints();
        obj.trl=obj.Parent.trl;
        obj.intInfo=sprintf('%3d.%02d.%02d \n%s',obj.trl,obj.int,obj.s,sName);
        obj.trlInfo=[num2str(obj.trl) ' / ' num2str(obj.nTrial)];
    end
    function update_Parent(obj)
        return
    end
%% CMD
    function update_str(obj)
        bCursor=true; % XXX
        [obj.strInfo,pos]=obj.Cmd.getPrompt(bCursor);
    end
    function update_cmd(obj)
        switch(obj.cmdMode)
            case 'full'
                height=obj.cmdHeightF;
            case 'normal'
                height=ceil(obj.cmdHeightF/8);
            case 'none'
                height=0;
        end
        botPos=0;  % TODO
        obj.cmdInfo=obj.Cmd.getHist('cmd',height,botPos);
    end
    function update_key(obj)
        % FROM CMD AND KEY
        bAct=strcmp(obj.Parent.Cmd.getMode,'cmd') || ~strcmp(obj.Parent.mode,'exp');
        obj.keyInfo=obj.Cmd.getKeyEcho(bAct);
    end
%% PTCH
    function update_constant(obj)
        obj.nTrial=obj.Ptchs.get_nTrial();
        obj.bMotion=obj.Ptchs.get_bMotion();

        %obj.stds   =obj.Ptchs.get_stdX();
        %obj.cmps   =obj.Ptchs.get_cmpX();
        %obj.intrvls=obj.Ptchs.get_cmpIntrvl();


        % HASHINFO
        if isempty(obj.Ptchs.ptch)
            obj.Ptchs.get_patch(1);
        end
        srcInfo=obj.Ptchs.ptch.srcInfo;
        obj.hashInfo=PtchsInfo.struct2TableFun(srcInfo.hashes);
        %  TODO
        %obj.dbInfo=PtchsInfo.struct2TableFun(Obj.struct(srcInfo.db));
        % TODO
        %if ~isempty(srcInfo.genOpts)
        %    obj.genOpts=PtchsInfo.struct2TableFun(Obj.struct(srcInfo.genOpts));
        %else
            obj.genOpts='';
        %end
    end
    function update_patch(obj);
        pidx=obj.Filter.getPidx();
        %lidx=obj.Filter.getLoadidx();

        obj.subj=obj.Parent.PTB.VDisp.SubjInfo;

        % IDX
        idxInfo=structfun(@(x) x(pidx,:),obj.Ptchs.idx,'UniformOutput',false);
        rmflds={'fname','PctrRC','seen','flags'};
        for i = 1:length(rmflds)
            if isfield(idxInfo,rmflds{i})
                idxInfo=rmfield(idxInfo,rmflds{i});
            end
        end
        idxInfo2=struct();
        swtchflds={'binVal','val','bExtra'};
        for i = 1:length(swtchflds)
            if ~isfield(idxInfo,swtchflds{i});
                continue
            end
            idxInfo2.(swtchflds{i})=idxInfo.(swtchflds{i});
            idxInfo=rmfield(idxInfo,swtchflds{i});
        end
        obj.idxInfo=PtchsInfo.struct2TableFun(idxInfo,true,true);

        % SRC
        srcInfo=Obj.struct(obj.Ptchs.ptch.srcInfo);
        if iscell(srcInfo.fname) && numel(srcInfo.fname)==1
            srcInfo.fname=srcInfo.fname{1};
        end
        srcInfo.PctrRC=[srcInfo.PctrRC{:}];
        rmflds={'LorR'};
        for i = 1:length(rmflds)
            srcInfo=rmfield(srcInfo,rmflds{i});
        end
        srcInfo2=struct();
        swtchflds={'fname','PctrRC'};
        %swtchflds={'fname','PctrRC'},'binVal','Val'};
        for i = 1:length(swtchflds)
            srcInfo2.(swtchflds{i})=srcInfo.(swtchflds{i});
            srcInfo=rmfield(srcInfo,swtchflds{i});
        end
        flds={'genOpts','db','database','hashes'};
        for i = 1:length(flds)
            srcInfo=rmfield(srcInfo,flds{i});
        end
        %obj.srcInfo=PtchsInfo.struct2TableFun(orderfields(srcInfo,idxInfo),true,true);
        obj.srcInfo=PtchsInfo.struct2TableFun(srcInfo);
        if isequal(obj.srcInfo,obj.idxInfo)
            obj.idxInfo='';
        end

        % STATs
        if numel(fieldnames(obj.Ptchs.Stats)) > 1
            I=obj.Filter.getPidx();
            flds=fieldnames(obj.Ptchs.Stats);
            stats=struct();
            for i = 1:length(flds)
                FLD=obj.Ptchs.Stats.(flds{i});
                if I <= size(FLD,1)
                    stats.(flds{i})=FLD(I,:);
                else
                    stat.(flds{i})=nan;
                end
            end
            obj.statInfo=PtchsInfo.struct2TableFun(stats);
        end

        % BLK
        if obj.Ptchs.bBlk
            flds=obj.Ptchs.Blk.blk.KEY;
            blk=obj.Ptchs.Blk(obj.Filter.abs.blk);
            blk=[blk{:}];
            %bind=ismember(flds,'P');
            %blk(:,bind)=[];
            %flds(:,bind)=[];
            bEll=false;
            bSpc=false;
            n=7;
            if size(blk,1) > n-1
                bEll=true;
                blk=blk(1:n-1,:);
            elseif size(blk,1) < n
                spc=n-size(blk,1);
                bSpc=true;
            end
            blkInfo=Cell.toStr([flds; num2cell(blk)]);
            if bEll
                blkInfo=[blkInfo newline '...'];
            elseif bSpc
                blkInfo=[blkInfo repmat([ newline ' '],1,spc)];
            end
            %blkInfo=obj.Ptchs.Blk.blk(obj.Filter.abs.blk).struct();
            %p=[srt(bind) srt(~bind)];

            %blkInfo=structfun(@(x) unique(x,'stable'),blkInfo,'UniformOutput',false)';
            %obj.blkInfo=PtchsInfo.struct2TableFun(orderfields(blkInfo,p),true,true);
            obj.blkInfo=blkInfo;
        end

    end
    function update_win(obj)
        trgtInfo=obj.Ptchs.ptch.trgtInfo;
        focInfo=obj.Ptchs.ptch.focInfo;

        foc=obj.Ptchs.ptch.win.foc.pointS;
        trgt=obj.Ptchs.ptch.win.trgt.pointS;
        win=obj.Ptchs.ptch.win.win;


        tpos=PtchsInfo.cell_fun(trgt.posXYZm);
        fpos=PtchsInfo.cell_fun(foc.posXYZm);
        wpos=PtchsInfo.cell_fun(win.posXYZm);

        % TFINFO
        tfInfo={'','win','foc','trgt';  ...
                'posXYZm:' [wpos] [fpos] [tpos]};
        obj.tfInfo=Cell.toStr(tfInfo);

        % SUBJINFO
        S=Obj.struct(obj.subj);
        S=rmfield(S,{'L','R','defL','defR','defIPDm','CExyz'});
        obj.subjInfo=PtchsInfo.struct2TableFun(S);

        % WININFO
        flds={'WHpix','WHm','vrgXY'};
        obj.winInfo=struct();
        for i = 1:length(flds)
            obj.winInfo.(flds{i})=win.(flds{i});
        end
        obj.winInfo.WszRCPixOffset=obj.Ptchs.ptch.WszRCPixOffset;
        obj.winInfo.trgtDspAM=obj.Ptchs.ptch.win.DspAM;
        obj.winInfo=PtchsInfo.struct2TableFun(obj.winInfo);

    end
    function update_im(obj)
        % ptchOpts
        ptch=obj.Ptchs.ptch;
        im=obj.Ptchs.ptch.im;

        %obj.ptchOpts=PtchsInfo.struct2TableFun(ptchOpts);

        % PHTINFO
        rb=PtchsInfo.cell_fun(obj.Ptchs.ptch.im.RMSbino);
        db=PtchsInfo.cell_fun(obj.Ptchs.ptch.im.DCbino);
        rm{1}=PtchsInfo.cell_fun(obj.Ptchs.ptch.im.RMSmono(1));
        rm{2}=PtchsInfo.cell_fun(obj.Ptchs.ptch.im.RMSmono(2));
        dm{1}=PtchsInfo.cell_fun(obj.Ptchs.ptch.im.DCmono(1));
        dm{2}=PtchsInfo.cell_fun(obj.Ptchs.ptch.im.DCmono(2));
        obj.phtInfo={'', 'mono{1}','mono{2}','bino'; ...
                 'RMS' [rm{1}] [rm{1}] [rb];
                 'DC'  [dm{1}] [dm{1}] [db]};
        obj.phtInfo=Cell.toStr(obj.phtInfo);

        % IMINFO
        imInfo=struct();
        flds={'PszRC','PszRCbuff','PctrCPs','primaryXYZ','primaryPht'};
        for i = 1:length(flds)
            imInfo.(flds{i})=ptch.(flds{i});
        end
        imInfo.PszRC=PtchsInfo.cell_fun(imInfo.PszRC);
        imInfo.PszRCbuff=PtchsInfo.cell_fun(imInfo.PszRCbuff);
        imInfo.PctrCPs=PtchsInfo.cell_fun(imInfo.PctrCPs);
        flds={'monoORbino','bFlat','dnkFix','dcFix','rmsFix'};
        for i = 1:length(flds)
            imInfo.(flds{i})=im.(flds{i});
        end
        obj.imInfo=PtchsInfo.struct2TableFun(imInfo);

        % WDW INFO
        obj.wdwInfo=PtchsInfo.struct2TableFun(im.wdwInfo);

    end
%% PRINT
    function OUT=format(obj,list,opts)
        %if ismember_cell('strInfo',list)
            %for i = 1:length(list)
            %    list{i}
            %    obj.(list{i})
            %end
        %end
        if nargin < 2
            list=[];
            STR=cell(1,1);
            STR{1}=obj.getPrintStr(list,opts);
        elseif ~isempty(list) && isstruct(list{1})
            STR=cell(size(list));
            for i = 1:length(list)
                STR{i}=obj.getPrintStr(list{i},opts);
            end
        elseif ~isempty(list)
            STR=cell(1,1);
            STR{1}=obj.getPrintStr(list,opts);
        end
        if nargout > 0
            OUT=STR;
        else
            obj.STR=STR;
        end
    end
    function STR=getPrintStr(obj,list,opts)
        if nargin < 2 || isempty(list)
            list=obj.getList();
        end
        if isempty(list)
            return
        end

        if strcmp(opts.type,'string')
            STR='';
        else
            STR={};
        end
        bStart=true;
        list(cellfun(@isempty,list))=[];
        bAllNew=ismember_cell('all', opts.newlines);
        if ~bAllNew
            bAllDiv=ismember_cell('all', opts.div);
            if ~bAllNew
                bAllDoub=ismember_cell('all', opts.doubNewlines);
                if ~bAllDoub
                    if ~bAllNew
                        bNew=ismember_cell(list, opts.newlines);
                        if ~all(bNew)
                            bDiv=ismember_cell(list, opts.div);
                            if ~all(bDiv)
                                bDoub=ismember_cell(list,opts.doubNewlines);
                            end
                        end
                    end
                end
            end
        end

        bTitleAll=ismember_cell('all',opts.titles);
        if ~bTitleAll
            bTitle=ismember_cell(list,opts.titles);
        end

        for i = 1:length(list)
            if isempty(obj.(list{i}))
                continue
            end

            %% DIVIDER
            if bStart
                div='';
                bStart=false;
            elseif  bAllNew || bNew(i)
                div=[newline newline];
            elseif bAllDiv || bDiv(i)
                div=PtchsInfo.div;
            elseif bAllDoub || bDoub(i)
                div=[newline newline newline];
            else
                div=newline;
            end

            if bTitleAll || bTitle(i)
                titl=[':' upper(strrep(list{i},'Info','')) ':' newline ];
            else
                titl='';
            end

            if strcmp(opts.type,'string')
                STR=[STR ...
                     div ...
                     titl ...
                     obj.(list{i})]; %- SLOW
            else
                STR=[STR;...
                     div;...
                     titl; ...
                     obj.(list{i})];
            end
        end
        %while startsWith(STR,newline)
        %    STR=STR(2:end);
        %end
    end
    function titl=get_title(obj,infoName,opts)
    end
    function print(obj)
        for i = 1:length(obj.STR)
            disp(obj.STR{i});
        end
    end
end
methods(Static=true, Access=private)
    function T=struct2TableFun(S,bAsIs,bTrans,header)
        if nargin < 2
            bAsIs=false;
        end
        if nargin < 3
            bTrans=false;
        end
        if bAsIs
            flds=fieldnames(S);
        else
            flds=strcat(fieldnames(S),':');
        end
        %C=struct2cell(S);
        if isa(S,'Container')
            C=builtin('struct2cell',S.get);
        else
            C=builtin('struct2cell',S);
        end
        %if ~bAsIs
            ind=cellfun(@(x) (isnumeric(x) || iscell(x)) & numel(x) > 1,C);
            if any(ind)
                C(ind)=cellfun(@PtchsInfo.cell_fun,C(ind),'UniformOutput',false);
            end
        %end
        C=[flds C];
        %if strcmp(flds{1},'I')
        %    C
        %    dk
        %end

        if bTrans
            C=C';
        end
        if nargin >=4
            C=[header; C];
        end
        T=Cell.toStr(C);
    end
    function out=cell_fun(in,bBrackets)
        if iscell(in)
            in=cellfun(@PtchsInfo.cell_fun,in,'UniformOutput',false);
            in=strjoin(in,', ');
        end
        if nargin < 2 && numel(in) ==1
            bBrackets=false;
        elseif nargin < 2
            bBrackets=true;
        end
        if bBrackets
            out=[ '[' regexprep(num2str(in), ' *','  ') ']' ];
        else
            out=[ regexprep(num2str(in), ' *','  ') ];
        end
    end
    function S=merge_struct_fun(varargin)
        S=varargin{1};
        for i = 2:length(varargin)
            flds=fieldnames(varargin{i});
            for j = 1:length(flds)
                S.(flds{j})=varargin{i}.(flds{j});
            end
        end
    end

    function obj=parse_expType(obj,expType)
        switch expType
            case {'2IFC','2AFC'}
                obj.expType='2IFC';
            case {'viewer'}
                obj.expType='viewer';
        end
    end
    function list=getList(obj)
        list=obj.Parent.printOpts.stringOpts.list;
    end
end
methods(Static)
    function P=getP()
        P={...
            'type','string','ischar';
            'newlines',{'all'},'ischarcell_e';
            'doubNewlines',{},'ischarcell_e';
            'titles',{},'ischarcell_e';
            'div',{},'ischarcell_e';
            'hcat',{},'ischarcell_e';
            'list',{},'ischarcell_e';
        };
    end
end
end
