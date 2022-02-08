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
    stdX
    cmpX
    cmpIntrvl
    bMotion

    srtrs
    fltrs
    fltrMode

    %-------
    % Filter
    filterInfo
    srtInfo
    indexInfo

    % FLAG
    flagInfo

    % PTCH
    idxInfo
    srcInfo
    blkInfo

    % WIN
    tfInfo
    subjInfo
    winInfo

    % IM
    phtInfo
    imInfo
    wdwInfo

    % CMD
    cmdInfo
    %STR
    strInfo
    %KEY
    keyInfo
    %MSG
    msg

    % CONSTANT
    hashInfo
    genOpts
    dbInfo

    STR
end
properties(Access=private)
    Ptchs
    Cmd
    Echo
    Flags
    Filter
    Blk
    Viewer
    bInit=true
end
properties(Constant=true, Hidden)
    div=[newline '-----------------------------' newline];
end
methods
    function obj=PtchsInfo(viewer)
        obj.Viewer=viewer;
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

        flds=fieldnames(bUp);
        for i = 1:length(flds)
            if ~bUp.(flds{i}) || ismember(flds{i},{'tex'})
                continue
            end

            meth=['update_vals_' flds{i}];
            if ismethod(obj,meth)
                obj.(meth)();
            end

            meth=['update_' flds{i}];
            obj.(meth)();
        end
    end
%% VALS
    function update_vals_patch(obj)
        obj.subj=obj.Viewer.PTB.VDisp.SubjInfo;
    end
    function update_vals_Filter(obj)
        [obj.pidx,obj.N]=obj.Filter.getPidx();
        [obj.rel,obj.n]=obj.Filter.getPos();
        obj.abs=obj.Filter.getAbs();
        obj.lidx=obj.Filter.getLoadIdx;
        obj.fltrMode=obj.Filter.mode;
        obj.srtrs=obj.Filter.srtrs;
        obj.fltrs=obj.Filter.fltrsStr;

        if strcmp(obj.Viewer.mode,'IFC')
            obj.stdX=obj.Ptchs.get_stdX(obj.trl);
            obj.cmpX=obj.Ptchs.get_cmpX(obj.trl,1);
            obj.cmpIntrvl=obj.Ptchs.get_cmpIntrvl(obj.trl);
        end
    end
    function update_vals_Flags(obj)
        [obj.pidx,obj.N]=obj.Filter.getPidx();
        obj.seen=obj.Flags.seen(obj.pidx);
        obj.bad=obj.Flags.bad(obj.pidx);
        obj.other=obj.Flags.other(obj.pidx);

        obj.nSeen=sum(obj.seen);
        obj.nFlags=numel(obj.Flags.seen);
    end
%% INFO
    function update_Filter(obj)
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
        if nargin < 2
            obj.pidx=obj.Filter.getPidx();
        end
        fI.seen=obj.seen;
        fI.bad=obj.bad;
        fI.other=obj.other;
        obj.flagInfo=PtchsInfo.struct2TableFun(fI);
    end
    function update_cmd(obj)
        cmd=obj.Cmd.lastCmd{end};
        if (~iscell(cmd) && isempty(cmd)) || (iscell(cmd) && all(cellfun(@isempty,cmd)))
            obj.cmdInfo=['>  '];
        elseif ischar(cmd)
            obj.cmdInfo=['>  ' cmd];
        else
            obj.cmdInfo=['>  ' strjoin(cmd,[newline '>  '])];
        end
        %val='>';
    end
    function update_Viewer(obj)
        return
    end
    function update_str(obj)
        strInfo=struct();
        [str, pos, mode]=obj.Cmd.getString;
        b=str(1:pos-1);
        e=str(pos:end);

        moude=obj.Cmd.getMode();
        if moude=='k'
            cmd=[ str '-' ];
        elseif moude=='c'
            cmd=['>> ' b '|' e];
        else
            cmd=[moude '<'];
        end

        obj.strInfo=cmd;
    end
    function update_key(obj)
        % FROM CMD AND KEY

        mode=obj.Cmd.getLastMode;
        literal=obj.Cmd.getKeys;
        if iscell(literal)
            literal=strjoin(literal,' ');
        end
        obj.keyInfo=[ ' ' mode ];
        if obj.Viewer.bKey
            obj.keyInfo=[obj.keyInfo ': ' literal ];
        end
        if obj.Viewer.bAct
            lst=obj.Cmd.lastAct{end};
            if isempty(lst) || all(cellfun(@isempty,lst))
                return
            end
            if iscell(lst) && ~isempty(lst)
                lst=strjoin(lst,' :: ');
            end
            obj.keyInfo=[obj.keyInfo ' :: ' lst];
        end
    end
%% PTCH
    function update_constant(obj)

        obj.stds   =obj.Ptchs.get_stdX();
        obj.cmps   =obj.Ptchs.get_cmpX();
        obj.intrvls=obj.Ptchs.get_cmpIntrvl();
        obj.nTrial=obj.Ptchs.get_nTrial();
        obj.bMotion=obj.Ptchs.get_bMotion();


        % HASHINFO
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

        % IDX
        idxInfo=structfun(@(x) x(pidx,:),obj.Ptchs.idx,'UniformOutput',false);
        rmflds={'fname','PctrRC','seen','flags'};
        for i = 1:length(rmflds)
            if isfield(idxInfo,rmflds{i})
                idxInfo=rmfield(idxInfo,rmflds{i});
            end
        end
        idxInfo2=struct();
        swtchflds={'binVal','val'};
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
        swtchflds={'fname','PctrRC','binVal','Val'};
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

        % BLK
        if obj.Ptchs.bBlk
            flds=obj.Ptchs.Blk.blk.KEY;
            bind=ismember(flds,'P');
            blk=obj.Ptchs.Blk.blk(obj.Filter.abs.blk).ret();
            blk(:,bind)=[];
            flds(:,bind)=[];
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
        obj.winInfo.trgtDsp=obj.Ptchs.ptch.win.trgtDSP;
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
    function append_msg(obj,msg)
        if ~isempty(msg)
            obj.msg=msg;
        end
        if iscell(obj.msg)
            obj.msg(cellfun(@isempty,obj.msg))=[];
            if ~isempty(obj.msg);
                obj.msg=strjoin(obj.msg,newline);
            end
        else
        end
        if isempty(obj.msg)
            obj.msg=[' '];
        end
    end
    function OUT=format(obj,list,opts)
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
        for i = 1:length(list)
            if isempty(obj.(list{i}))
                continue
            end

            %% DIVIDER
            div=obj.get_div(list{i},opts);

            %% TITLE
            titl=obj.get_div(list{i},opts);

            if strcmp(opts.type,'string')
                STR=[STR ...
                     div ...
                     titl ...
                     obj.(list{i})];
            else
                STR=[STR;...
                     div;...
                     titl; ...
                     obj.(list{i})];
            end
        end
    end
    function div=get_div(obj,infoName,opts)
        if ismember(infoName, opts.newlines) || ismember('all', opts.newlines)
            div=newline;
        end
        if ismember(infoName, opts.div) || ismember('all', opts.div)
            div=PtchsInfo.div;
        elseif ismember(infoName,opts.doubNewlines)|| ismember('all', opts.doubNewlines)
            div=[newline newline];
        else
            div='';
        end
    end
    function div=get_title(obj,infoName,opts)
        if ismember(infoName,titles)
            titl=[':' Str.Alph.upper(strrep(infoName,'Info','')) ':' newline ];
        else
            titl='';
        end
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
        C=builtin('struct2cell',S);
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
        list=obj.Viewer.printOpts.stringOpts.list;
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
