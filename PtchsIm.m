classdef PtchsIm < handle
%%      - Args
%%        - DspDispWin options
%%        - ImOpts
%%        - check nested opts when applying
%%      - main stim
%%        holder
%%      - DspDispWin handle trgtXYZ etc.
%%      - buffORptch as srcOpt
properties
    oOpts=struct()

    names
    selName
    updated

    ims=struct() % XXX FIX CASE
    opts=struct() % XXX FIX CASE
    DDWIN=struct()
    MAPS=struct() % ?

    Togglers=struct()
    dspFlds
    name2fld
    str2fld
end
properties(Hidden)
    Parent
end
methods
    function obj=PtchsIm(Parent)
        obj.Parent=Parent;
        opts=obj.Parent.imOpts;
        obj.parse(opts);
        obj.names=fieldnames(obj.opts);
        if ismember('stm',obj.names)
            obj.selName='stm';
        elseif ~isempty(obj.names)
            obj.selName=obj.names{1};
        end
        obj.get_name2fld();
    end
    function obj=parse(obj,opts)
        if isempty(obj.Parent.Ptchs.ptch)
            ME=[];
            for i = 1:10
                try
                    obj.Parent.Ptchs.get_patch(i);
                    ME=[];
                    break
                catch ME
                end
            end
            if ~isempty(ME)
                rethrow(ME);
            end
        end
        flds=fieldnames(opts);
        P=obj.getP();
        obj.opts=struct();
        obj.Togglers=struct();
        for i = 1:length(flds)
            fld=flds{i};
            [obj.opts.(fld),obj.Togglers.(fld)]=obj.parse_opt(P,opts{fld});
            obj.Parent.psyOpts{fld}=dict(1,'class','stm'); % XXX
        end

        obj.get_dsp_params();
    end
    function get_dsp_params(obj)
        obj.oOpts=obj.opts;
        P{1}=DspDispWin.getP();
        P{2}=Win3D.getP();
        P{3}=Point3D.getP();

        PP={};
        for i = 1:length(P)
            out=P{i}(:,1);
            ind=cellfun(@iscell,out);
            PP=[PP out{ind} Vec.row(out(~ind))];
        end
        PP=unique(PP);
        PP(contains(PP,{'!','.'}))=[];
        PP(ismember(PP,{'RExyz','LExyz','IppZm'}))=[];
        obj.dspFlds=PP;

        function out=unnestfun(x)
            if iscell(x)
                out=Vec.col(x);
            else
                out=x;
            end
        end
    end
    function restore(obj)
        obj.opts=obj.oOpts;
    end
    function [opts,Toggler]=parse_opt(obj,P,opts)
        % INDVIDUAL NAME
        c=Container(struct());
        [opts,~,Toggler]=Args.parse(c,P,opts);
        flds=fieldnames(opts);
        for i = 1:length(flds)
            fld=flds{i};
            if isa(opts.(fld),'dict')
                k=keys(opts.(fld));
                d=opts.(fld);
                opts.(fld)=struct();
                for j = 1:length(k)
                    opts.(fld).(k{j})=d{k{j}};
                end
            end
        end
        if isfield(opts,'floatPrecision')
            opts=rmfield(opts,'floatPrecision');
        end
        if isfield(opts,'type')
            opts=rmfield(opts,'type');
        end

        % bSTM
        mapNames=['img'; fieldnames(obj.Parent.Ptchs.ptch.maps)];
        bStm=ismember(opts.src,mapNames);

        % TODO MAKE SURE THESE PARAMETERS EXIST
        if bStm
            if ~isfield(opts.posOpts,'posXYpix') || isempty(opts.posOpts.posXYpix)
                opts.posOpts.posXYpix='@Ptch';
            end
            if ~isfield(opts.posOpts,'WHpix')|| isempty(opts.posOpts.WHpix)
                opts.posOpts.WHpix='@Ptch';
            end
            if isempty(opts.duration)
                opts.duration='@Ptch';
            end
        else
            if ~isfield(opts.posOpts,'posXYpix')
                 opts.posOpts.posXYpix=[];
            end
        end

        if isempty(opts.bPlot)
            opts.bPlot=bStm;
        end
        if ~isfield(opts.posOpts,'stmMult')
            opts.posOpts.stmMult=1;
        end

        P=obj.getP_im();
        opts=apply_fun(opts,P,'imOpts');

        P=obj.getP_src(opts.src);
        opts=apply_fun(opts,P,'srcOpts');

        function opts=apply_fun(opts,P,fld)
            for i = 1:size(P,1)
                name=P{i,1};
                def=P{i,2};
                if ~isfield(opts.(fld),name) || isempty(opts.(fld).(name))
                    opts.(fld).(name)=def;
                end
            end
        end
    end
    function get_ims(obj,intOpts)
        obj.updated={};

        for i = 1:length(intOpts.reset)
            name=intOpts.reset{i};
            if ismember_cell(name,obj.names);
                obj.get(name);
            end
        end
        obj.Parent.Psy.reselect();
    end
    function map=get(obj,name)
        O=obj.opts.(name);
        if ~strcmp(O.modes,'all') && ~ismember(obj.Parent.mode,O.modes)
            map=[];
            obj.Parent.Psy.norect(name,1);
            obj.Parent.Psy.notex(name,1);
            obj.Parent.Psy.hide(name,1);
            return
        else
           % obj.Parent.Psy.show(name,1);
        end

        O=obj.parse_ind(name,O);
        map=obj.get_map(O);
        map=obj.modify_map(name,map,O);
        obj.ims.(name)=map;

        % UPDATE
        num=[]; % TODO
        if obj.Parent.bPsy
            obj.update_psy(name,num,map,O);
        end
    end
    function O=parse_pos_meta(obj,O)
        P=obj.Parent.Ptchs.ptch.win.win3D;
        D=obj.Parent.Psy.PTB.VDisp;
        for i = 1:2
            if ischar(O.posOpts.posXYpix{i})
                if strcmp(O.posOpts.posXYpix{i},'@Ptch')
                    O.posOpts.posXYpix{i}=P.posXYpix{i};
                elseif strcmp(O.posOpts.posXYpix{i},'@VDisp')
                    O.posOpts.posXYpix{i}=D.posXYpix;
                end
            elseif all(O.posOpts.posXYpix{i} <= 1 & O.posOpts.posXYpix{i} >= 0)
                O.posOpts.posXYpix{i}=D.WHpix.*O.posOpts.posXYpix{i};
            end
        end
    end
    function O=parse_wh_meta(obj,O)
        P=obj.Parent.Ptchs.ptch.win.win;
        D=obj.Parent.Psy.PTB.VDisp;
        if ischar(O.posOpts.WHpix)
            if strcmp(O.posOpts.WHpix,'@Ptch')
                O.posOpts.WHpix=P.WHpix;
            elseif strcmp(O.posOpts.WHpix,'@VDisp')
                O.posOpts.WHpix=D.WHpix;
            end
        end
    end
    function O=parse_ind(obj,name,O)
        if ~iscell(O.posOpts.posXYpix)
            O.posOpts.posXYpix={O.posOpts.posXYpix O.posOpts.posXYpix};
        end
        O=obj.parse_pos_meta(O);
        if ~isfield(O,'WHpixO')
            O.WHpixO=O.posOpts.WHpix;
        else
            O.posOpts.WHpix=O.WHpixO;
        end
        O=obj.parse_wh_meta(O);
        O.posOpts.WHpix=O.posOpts.WHpix*O.posOpts.stmMult;

        if (ischar(O.duration) && strcmp(O.duration,'@Ptch')) || strcmp(O.src,'img')
            O.duration=obj.Parent.Ptchs.get_duration(obj.Parent.trl, obj.Parent.int);
        else
            O.duration=0;
        end


        [trgtInfo,focInfo,winInfo]=obj.get_dsp_opts(O);
        if strcmp(O.src,'img')
            obj.DDWIN.(name)=obj.Parent.Ptchs.ptch.win;
        elseif strcmp(O.src,'pht') && strcmp(O.srcOpts.buffORptch,'ptch')
            obj.DDWIN.(name)=obj.Parent.Ptchs.ptch.win.copy;
            flds=fieldnames(O.posOpts);
            for i = 1:length(flds)
                if ismember(flds{i},{'oOpts','stmMult'})
                    continue
                end
                F=obj.name2fld(flds{i});
                loc={F{1} name F{2}{:}};
                setfield(obj,loc{:},O.posOpts.(flds{i}));
            end
            obj.DDWIN.(name).update_win(true);
        elseif ~isfield(obj.DDWIN,name)
            obj.DDWIN.(name)=DspDispWin(obj.Parent.Psy.PTB.VDisp,winInfo,trgtInfo,focInfo);
            obj.DDWIN.(name).update();

        end
        if strcmp(O.imOpts.mode,'sbs')
            O.posOpts.WHpix(1)=O.posOpts.WHpix(1)*2;
        end
    end
    function [trgtInfo,focInfo,winInfo]=get_dsp_opts(obj,O)
        winInfo.WHpix=O.posOpts.WHpix;

        % WIN
        if ~isempty(O.posOpts.posXYpix)
            winInfo.posXYpix=O.posOpts.posXYpix;
        end

        % FOC
        if isfield(O,'focInfo')
            focInfo=O.focInfo;
        else
            %focInfo=DspDispWin.getDefaultFocOpts();
            focInfo=struct('dispORwin','subj');
            focInfo.posXYpix=winInfo.posXYpix;
        end

        % TRGT
        if isfield(O,'trgtInfo')
            trgtInfo=O.trgtInfo;
        else
            %trgtInfo=DspDispWin.getDefaultTargetOpts();
            trgtInfo=struct('dispORwin','subj','Dsp',0);
            trgtInfo.posXYpix=winInfo.posXYpix;
        end
        if isfield(O.posOpts,'trgtDsp')
            trgtInfo.Dsp=O.posOpts.trgtDsp;
        end
    end
    function map=dsp_crop(obj,name,map,O)
        PszRCbuff=obj.Parent.Ptchs.ptch.PszRCbuff;
        PszXY=obj.Parent.Ptchs.ptch.PszRC;
        PctrCPs=obj.DDWIN.(name).get_patch_CPs(PszRCbuff,size(map{1}));

        for i = 1:2
            map{i}=Map.crop_interp(map{i}, PctrCPs{i}, PszXY,'linear');
        end
    end
    function map=get_map(obj,O)
        bMap=false;
        switch O.src
        case {'noise','ns'}
            map{1}=Noise.makeMsk(O.posOpts.WHpix);
            map{2}=map{1};
        case {'img','im'}
            fld='im';
            bMap=true;
        case 'gabor'
            % TODO
            map{1}=Gabor.map(O.srcOpts);
        case {'gaussRing','ring'}
            map=GaussRing.map(O.srcOpts);
        case {'circle','circ'}
            map=Msk.circle(O.srcOpts.PszXY);
            map={map,map};
            %map=Circle.map(O.srcOpts);
        otherwise
            if strcmp(O.srcOpts.buffORptch,'buff')
                fld='mapsBuff';
            elseif strcmp(O.srcOpts.buffORptch,'ptch')
                fld='maps';
            end
            bMap=true;
        end
        if bMap
            map=obj.Parent.Ptchs.ptch.(fld).(O.src);
        end
        for i = 1:2
            if size(map{i},3) > 1
                map{i}=map{i}(:,:,3);
            end
        end
    end
    function map=modify_map(obj,name,map,O)
        % FLATTEN
        if O.imOpts.bFlat
            map{2}=map{1};
        end

        % CROP
        if isfield(O.srcOpts,'buffORptch') && strcmp(O.srcOpts.buffORptch,'buff') && (~isfield(O.posOpts,'trgtDsp') || ~isempty(O.posOpts.trgtDsp))
            map=obj.dsp_crop(name,map,O);
        end

        % NORMALIZE
        if ~ismember(O.src,{'img','noise'})
            map=Map.ptbNormalize(map,O.imOpts.bBinoMap);
        end

        % MODE
        map=Map.mapToMode(O.imOpts.mode,map);
    end
    function update_psy(obj,name,num,map,opts)
        obj.Parent.apply_im_update(name,num,map,opts);
    end
    function move_left(obj,n)
        ind=1;
        obj.move_fun(n*-1,ind);
    end
    function move_right(obj,n)
        ind=1;
        obj.move_fun(n,ind);
    end
    function move_up(obj,n)
        ind=2;
        obj.move_fun(n*-1,ind);
    end
    function move_down(obj,n)
        ind=2;
        obj.move_fun(n,ind);
    end
    function move_fun(obj,n,ind)
        fld='posXYZm';

        obj.inc_selected_opt(n,ind,fld);

        name=obj.Parent.Psy.selected{1};
        obj.Parent.Psy.A.(name){1}.bRectUpdate=true;
        obj.Parent.append_update(name);
        obj.DDWIN.(name).update_win(true);

        obj.Parent.reloop();
    end
    function move_forward(obj,n)
        fld='posXYZm';
        ind=3;
        obj.inc_selected_opt(n*1,ind,fld);
        obj.Parent.append_bUp('Im');
        obj.Parent.redraw();
    end
    function move_backward(obj,n)
        fld='posXYZm';
        ind=3;
        obj.inc_selected_opt(n*1,ind,fld);


        obj.Parent.redraw();
    end
    function [exitflag,msg]=inc_selected_opt(obj,n,ind,fld)
        % XXX ind
        exitflag=true;
        msg='';
        if nargin < 4
            [name,num,flds,cval]=obj.Parent.get_selected();
            fld=flds{1};
            F=obj.str2fld(fld);
        else
            name=obj.Parent.Psy.selected{1};
            num=obj.Parent.Psy.selected{2};
            F=obj.name2fld(fld);
            flds=F{2};
            cval=getfield(obj.(F{1}).(name),flds{:});
        end
        if isempty(name)
            msg='Nothing selected';
            return
        end
        counts=F{3};
        flags=F{4};
        cont=F{5};

        if isempty(cont)
            msg='Cannot inc. field';
            return
        end

        bChar=ismember('c',flags);
        bInc=ismember('i',flags);
        bList=ismember('l',flags);
        bInd=any(counts > 1);
        bNest=numel(counts) > 1;
        bMinMax=ismember('m',flags);
        bBinary=bList && numel(cont) == 2;

        if ~bChar & bInd
            cont=cont{ind};
            cval=cval(ind);
        elseif bChar & bInd
            cval=cval{ind{1}}(ind{2});
        end

        if bMinMax
            mini=cont(1);
            maxi=cont(end);
        end
        if bInc
            if length(cont)==1
                inc=cont(1);
            else
                inc=cont(2);
            end
        end

        if bList
            if bChar
                Ind=find(ismember(cont,cval))+n;
            else
                Ind=find(cont==cval)+n;
            end
            if Ind > numel(cont)
                Ind=1;
            elseif Ind < 1
                Ind=numel(cont);
            end
            if bChar
                val=cont{Ind};
            else
                val=cont(Ind);
            end
        elseif bInc
            val=cval+n*inc;
            if bMinMax
                if cval > maxi
                    val=maxi;
                elseif cval < mini
                    val=mini;
                end
            end
        end

        if ~bInd
            setfield(obj,F{1},name,F{2}{:},val);
        else
            C=getfield_fast(obj,F{1},name,F{2}{:});
            if bNest & bChar
                C{ind(1)}{ind(2)}=val;
            elseif bNest
                C{ind(1)}(ind(2))=val;
            elseif bChar
                C{ind}=val;
            else
                C(ind)=val;
            end
            setfield(obj,F{1},name,F{2}{:},C);
        end


        exitflag=false;

        %obj.Togglers.(name).inc(flds,n);
    end
    % SET SELECTED OPT
    function exitflag=apply_opt(obj,name,num,flds,val)
        % XXX ind
        exitflag=true;

        P=obj.getP();
        plist=P(:,1);
        if ~ismember(name,obj.names)
            % TODO
            return
        end
        % HERE
        %
        F=obj.str2fld(flds{1});
        setfield(obj,F{1},name,F{2}{:},val);
        exitflag=false;

        return
        % OLD BELOW

        if any(ismember(flds,obj.dspFlds))
            [exitflag,msg]=obj.DDWIN.(name).set(flds,val);
        else
            [exitflag,msg]=obj.Togglers.(name).set(flds,val);
        end
        return
         %OLD BELOW

        % PARAM NAME
        bNested=false;
        prp=flds{end};
        flds(end)=[];
        if length(flds) > 0
            try
                getfield_fast(obj.opts,flds{:});
                bNested=true;
            catch ME
                % TODO
                return
            end
            try
                obj.opts=setfield(obj.opts,name,flds{:},prp,val);
            catch
                % TODO
                return
            end
        else
            ind=ismember(plist,prp);
            if ~any(ind)
                % TODO
                return
            end

            tst=Args.parse_test(P{ind,3});
            if ~tst(val)
                % TODO
                return
            end
            def=P{ind,2};
            if isempty(val) && ~isempty(def)
                % TODO
                val=def;
            end
            obj.opts.(name).(prp)=val;
        end

        exitflag=false;

        % PARSE With P
        % set if valid
    end
    function getOpts(obj,name)
        P=getP;
        obj.opts.(name);
        obj.DDWIN.(name);
    end
    function OUT=getInfo(obj,name)
        P=obj.infoP();

        S=struct();
        nms=unique(P(:,1));
        for i = 1:length(nms)
            S.(nms{i})=cell(0,2);
        end
        for i = 1:size(P,1)
            grp=P{i,1};
            txt=P{i,2};
            loc={P{i,3} name P{i,4}{:}};
            val=getfield_fast(obj,loc{:});
            if iscell(val)
                val=['{' Cell.toStr(val,2) '}'];
            elseif all(isnumeric(val)) && numel(val) > 1
                val=['[' num2str(val) ']'];
            end
            S.(grp){end+1,1}=[txt ':'];
            S.(grp){end,2}=val;
        end
        OUT=name;
        nms={'psy','im','TF','trgt','foc','win'};
        for i = 1:length(nms)
            OUT=[OUT newline nms{i} newline Str.indent(Cell.toStr(S.(nms{i}),2),4)];
        end
    end
    function get_name2fld(obj)
        P=obj.infoP();
        obj.str2fld=containers.Map();
        for i = 1:size(P,1)
            obj.str2fld(P{i,2})=P(i,3:end);
        end

        obj.name2fld=containers.Map();
        for i = 1:size(P,1)
            flds=P{i,4};
            if ismember(flds{1},{'trgt','foc'})
                name=strjoin(flds,'.');
            else
                name=flds{end};
            end
            obj.name2fld(name)=P(i,3:end);
        end
    end
end
methods(Static)
    function P=infoP()

        dispORwin={'subj','disp','win'};
        los={'naive','ambig','trans','C','anchor'};
        % TODO
        % naive:
        % ambig:  trgtXYZ, LOR
        % trans:  guideLOS
        % C:      trgtXYZ, guideLOS
        % anchor: trgtXYZ, guideLOS, LOR

        p=[-1 .0001 1];
        pos={p,p,p};

        x=[-1000 0.5 -1000];
        pix={x x};

        v=[-10,0,10];
        vrs={v,v};
        vrg={v,v};

        dist={0.001};

        m=[0 .001 1];
        wh={m m};

        w=[0 -0.5 2000];
        whpix={w w};

        d=[0 0.06 6];
        whdeg={d,d};

        a=[1 .001 1];
        dsp  ={a*60};
        dspAM={a};

        P={...
           'im',   'src',       'opts', {'src'},                     1,'', {};
           'psy',  'priority',  'opts', {'priority'},                1,'l',[-10:10];
           'psy',  'duration',  'opts', {'duration'},                1,'i',[0.05];
           'im',   'bBinoMap',  'opts', {'imOpts','bBinoMap'},       1,'l',[true false];
           'im',   'mode',      'opts', {'imOpts','mode'},           1,'lc',{'sbs','sng','ana'};
           'im',   'bFlat',     'opts', {'imOpts','bFlat'},          1,'l',[true false];
            ...
           'TF',   'Disp deg',  'DDWIN', {'Dsp'},                    1,'im',dsp;
           'TF',   'Disp a.m.', 'DDWIN', {'DspAM'},                  1,'im',dspAM;
           'TF',   'Dist m.',   'DDWIN', {'Dist'},                   1,'',{};
           'TF',   'Depth m.',   'DDWIN', {'Depth'},                  1,'',{};
            ...                 'DDWIN'
           'foc',  'coord',     'DDWIN', {'foc','dispORwin'},        1,'lc',dispORwin;
           'foc',  'XYZ m.',    'DDWIN', {'foc','posXYZm'},          3,'im',pos;
           'foc',  'XY pix',    'DDWIN', {'foc','posXYpix'},     [2,3],'im',pix;
           'foc',  'Vrs',       'DDWIN', {'foc','vrsXY'},            2,'im',vrs;
           'foc',  'Vrg',       'DDWIN', {'foc','vrgXY'},            2,'im',vrg;
           'foc',  'L.O.S.',    'DDWIN', {'foc','los'},              1,'imc',los;
           'foc',  'dist m.',   'DDWIN', {'foc','dist'},             1,'im',dist;
            ...                 'DDWIN'
           'trgt', 'coord',     'DDWIN', {'trgt','dispORwin'},       1,'lc',dispORwin;
           'trgt', 'XYZ m',     'DDWIN', {'trgt','posXYZm'},         3,'im',pos;
           'trgt', 'XY pix ',   'DDWIN', {'trgt','posXYpix'},    [2,3],'im',pix;
           'trgt', 'Vrs',       'DDWIN', {'trgt','point','vrsXY'},   2,'im',vrs;
           'trgt', 'Vrg',       'DDWIN', {'trgt','point','vrgXY'},   2,'im',vrg;
           'trgt', 'L.O.S.',    'DDWIN', {'trgt','los'},             1,'imc',los;
           'trgt', 'dist m.',   'DDWIN', {'trgt','dist'},            1,'im',dist;
            ...
           'win',  'coord',     'DDWIN', {'win','dispORwin'},        1,'lc',dispORwin;
           'win',  'XYZ m.',    'DDWIN', {'win','posXYZm'},          3,'im',pos;
           'win',  'XY pix ',   'DDWIN', {'win','posXYpix'},     [2,3],'im',pix;
           'win',  'Vrs',       'DDWIN', {'win','point','vrsXY'},    2,'im',vrs;
           'win',  'Vrg',       'DDWIN', {'win','point','vrgXY'},    2,'im',vrg;
           'win',  'L.O.S.',    'DDWIN', {'win','los'},              1,'imc',los; % XXX
           'win',  'dist m.',   'DDWIN', {'win','dist'},             1,'im',dist;
           ...
           'win',  'WH m.',     'DDWIN', {'win','WHm'},              2,'im',wh;
           'win',  'WH pix',    'DDWIN', {'win','WHpix'},            2,'im',whpix;
           'win',  'WH deg',    'DDWIN', {'win','WHdegRaw'},         2,'im',whdeg; % XXX
        };

    end
    function P=getP()
        %% TODO SPLIT OUT PSYEL ONLY
        P={...
            % Viewer
            'modes',                               'all', 'ischarcell_e', 0,'1'; ...
            ...
            % PsyEl
            'type',                                [],    '',             0,'p'; ... % XXX not used
            'floatPrecision',                      0,     'Num.is',       0,'p'; ... % XXX not used
            'bHidden',                             0,     'isbinary',     0,'p'; ...    %% T
            'priority',                            [],    'Num.is',       1,'p'; ...
            'bPlot',                               [],    'isbinary',     0,'1'; ...
            'duration',                            [],    '',             0,''; ...
            ...
            'imOpts',                             [],    'Args.isoptions_e',  0,'s';
            ...
            'posOpts',                             [],    'isoptions_e',  0,'s';
            ...
            'src',                                 'img', 'ischar_e',     0,''; ...
            'srcOpts',                             [],    'Args.isoptions_e',  0,'s';
            ...
        };
    end
    function P=getP_im()
        P={...
            'bBinoMap',                            0,     'isbinary',     0,'i';
            'mode',                                'sng', 'ischar_e',     0,'i'; ...
            'bFlat',                               0,     'isbinary',     0,'i'; ...
        };
    end
    function P=getP_pos()
        P={...
            'WHpix',                               [],    '',             1,'d'; ...
            'posXYpix',                            [],    '',             1,'d'; ...
            'stmMult',                             1,     'Num.is',       1,''; ...
            'trgtDsp',                             [],    'Num.is_e',     0,'d'; ...
        };
    end
    function P=getP_src(typ)
        switch typ
        case 'ptch'
            P=getP_ptch();
        otherwise
            P={};
        end
    end
    function P=getP_ptch()
        P={...
            'buffORptch',                         'ptch',    '',             1,'d'; ...
        };
    end
end
end
