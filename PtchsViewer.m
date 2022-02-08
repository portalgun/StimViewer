classdef PtchsViewer < handle

%    changeMode
%        (get abs
%        refilter_fun
%        update_bink
%        abs_to_nearest
%        obj.update_pos_fun('abs');
%
%        resort
%        obj.update_sind();
%
%
%    filter
%        filter_fun
%        update_bind
%        abs_to_nearest
%        update_given_abs
%    sort
%        sort_fun
%        update_sind
%        update_given_abs ::
properties(Hidden)
    alias
    mode

    errmsg
    msg
    bInit
    bPTB
    exitflag=false
    runFlag
    returncode
    ME

    list

    bKey % XXX ?
    bAct % XXX ?
    bPsy
    bPrint
    bPlot

    printOpts
    ptbOpts
    stmOpts
    psyOpts
    plotOpts
    rspOpts

    % Opts
    % STM OPTS

    ims

    s
    trl
    int

    abs
    pidx
    lidx
end
properties(Hidden)
    PTB    % dep
    PsyInt % dep
    Ptchs
    Cmd
    Echo
    Filter
    Flags
    Info
    Psy    % dep
    Rsp
    LChk

    PtchOpts
    im
end
properties(Access=private)
    f
    sp
    clim=[]
    pos=[]

end
methods(Static)
    function Opts = readConfig(alias)
        if nargin < 1 || isempty(alias)
            alias=ptchs.getAlias;
        end
        Opts=Cfg.read(['D_viewer_' alias '.cfg']);
    end
end
methods
    function obj=PtchsViewer(ptchs,alias,bPsy)

        obj.Ptchs=ptchs;
        if nargin < 2
            alias=[]; %
        end
        if nargin < 3
            bPsy=[];
        end

        obj.init(alias,bPsy);
    end
    function error(obj,text)
        obj.errmsg{end+1,1}=text;
    end
end
methods(Access=private)
    function init(obj,alias,bPsy,bForce)
        if isempty(alias)
            alias=ptchs.getAlias;
        end
        obj.alias=alias;

        Opts=PtchsViewer.readConfig(obj.alias);
        if ~isempty(bPsy)
            Opts{'bPsy'}=bPsy;
        end

        %PARSE
        obj=Args.parse(obj,PtchsViewer.getP,Opts);
        obj.parse_stm_opts();
        % plotOPts
        obj.parse_plot_opts();
        %printOpts
        obj.parse_print_opts();

        if obj.bPsy && isempty(obj.bPlot);
            obj.bPlot=false;
        end

        keys=fieldnames(Opts{'psyOpts'});

        obj.bPsy=~isempty(which('ListenChar'));
        if obj.bPsy && ~obj.bPsy
            error('Cannot use viewer, PTB not installed');
        end
        if nargin < 4
            bForce=false;
        end
        if bForce
            obj.re_init_parts();
        end
        obj.init_parts();
    end
    function init_parts(obj)
        if isempty(obj.bPsy)
            obj.bPsy=false;
        end

        % CMD -- Viewer
        if isempty(obj.Cmd)
            obj.Cmd=PsyShell(obj);
        end

        % FILTER - Ptchs
        if isempty(obj.Filter)
            obj.Filter=PtchsFilter(obj.Ptchs);
        end

        % FLAGS -- Filter
        obj.Flags=obj.Ptchs.Flags;
        obj.Flags.setFilter(obj.Filter);

        % INFO -- Ptchs, Viewer, Flags, Filter
        if isempty(obj.Info)
            obj.Info=PtchsInfo(obj);
        end

        % PSY
        if obj.bPsy
            obj.init_psy();
        end

        % OPTS
        obj.PtchOpts=Holder(obj);

        % IM
        obj.im=obj.PtchOpts;

        % RSP
        obj.init_Rsp();


        % XXX
        %obj.Ptchs.set_subj(subjInfo);

        obj.LChk=PtchsLoadChk(obj);

        % XXX fname
        fname=[];
        obj.PsyInt=PsyInt(fname);



        % XXX
        % sort by trl & intrvl if exp
    end
    function obj=parse_stm_opts(obj)
        stmOpts=obj.stmOpts;
        flds=fieldnames(stmOpts);
        obj.stmOpts=struct();
        P=obj.getStmP();
        for i = 1:length(flds)
            fld=flds{i};
            obj.stmOpts.(fld)=Args.parse(struct(),P,stmOpts{fld});
            obj.psyOpts{fld}=dict(1,'class','stm');
        end
    end
    function obj=parse_plot_opts(obj)
        P=ptch_plot.getPlotP();
        obj.plotOpts=Args.parse(struct(),P,obj.plotOpts);
    end
    function obj=parse_print_opts(obj)
        P=PtchsInfo.getP();
        sOpts=Args.parse(struct(),P,obj.printOpts{'stringOpts'});
        obj.printOpts=struct('stringOpts',sOpts);
    end
    function init_psy(obj)
        %vOpts=PtchsViewer.readConfig(obj.alias);
        %pOpts=Psycho.readConfig(obj.alias);
        %pp=vOpts{'psyOpts'};
        %pOpts=pp.mergePref(pOpts,false,true);
        obj.Psy=Psycho(obj,obj.psyOpts);
        obj.bPsy=true;

        hn=Sys.hostname;
        if ~strcmp(obj.Ptchs.ptchOpts.DispInfo,hn)
            Error.warnSoft('Hostname does not match, adjusting ptchOpts');
            obj.Ptchs.VDisp=hn;
        end

    end
    function obj=init_Rsp(obj)
        if  isempty(obj.rspOpts)
            return
        end
        rspOpts{'stdX'}      = obj.Info.stds();
        rspOpts{'cmpX'}      = obj.Info.cmps();
        rspOpts{'cmpIntrvl'} = obj.Info.intrvls();
        rspOpts{'nTrial'}    = obj.Info.nTrial;
        rspOpts{'expType'}   = obj.mode;
        obj.Rsp=Rsp(rspOpts);

        % XXX
        %if obj.bTest==3
        %    obj.Rsp.populate_rnd();
        %end
    end
    function apply_opts(obj)
        % XXX
        % ZERO
        if obj.bZer
            obj.Cmd.ex_return('t zer');
        end

        % WINDOW
        bWinFld=isfield(obj.Ptchs.ptchOpts,'bWindow');
        if  ~bWinFld && isfield(obj.Ptchs.ptchOpts,'wdwInfo')
            obj.Ptchs.ptchOpts.bWindow=true;
        elseif ~bWinFld
            obj.Ptchs.ptchOpts.bWindow=false;
        end

        if ~obj.bWindow
            obj.Cmd.ex_return('t window');
        end
    end
end
methods
    function re_init(obj)
        % RESET PTCHS OPTS
        obj.im.restore();
        obj.init([],obj.bPsy,true);
    end
    function re_init_parts(obj)
        obj.Cmd=PsyShell(obj);
        obj.Filter=PtchsFilter(obj.Ptchs);

        obj.Flags=obj.Ptchs.Flags;
        obj.Flags.setFilter(obj.Filter);

        obj.Info=PtchsInfo(obj);
        if obj.bPsy
            obj.init_psy();
        end

        obj.PtchOpts=Holder(obj);
        obj.im=obj.PtchOpts;

        obj.reload();
    end
    function run(obj,start,bOnce)
        obj.errmsg={};
        obj.runFlag=1;
        obj.exitflag=0;
        CL=onCleanup(@() obj.exit()); % run exit on complete or error % XXX
        if nargin < 2 || isempty(start)
            start=1;
        end
        if nargin < 3
            bOnce=false;
        end
        obj.bInit=true;

        obj.goto(start,true);
        obj.reset();


        % PLOT
        if obj.bPlot
            obj.plot();
        end


        % PSY VISUAL
        if obj.bPsy
            obj.init_ptb();
        end

        %UPDATE
        bUp=obj.Cmd.bUp;
        obj.update(bUp);


        % FIRST DRAW
        if obj.bPsy
            obj.Psy.init_aux();
            obj.update(bUp);
            obj.Psy.dispSep('RUN');
            if strcmp(obj.mode,'view')
                obj.drawPsy(bUp);
            else
                obj.Psy.present_keystart();
            end
        end

        % PRINT
        if obj.bPrint
            obj.print();
        end

        if bOnce
            return
        end

        while true
            obj.main();
            obj.bInit=false;
            if obj.exitflag
                break
            end
        end

        obj.runFlag=0;

    end
    function obj=init_ptb(obj)
        lasterror('reset');
        obj.bPTB=1;
        obj.PTB=Ptb([],obj.ptbOpts); % 10 ptb
        obj.Psy.PTB=obj.PTB;
    end
    function reset(obj)
        obj.exitflag=false;
        obj.Info.msg=' ';
        obj.Cmd.resetKey();
    end
    function obj=exit(obj)
        % runflag
        % consistent with runner
        % 2  complete
        % 0  run
        % -1 error
        % -2 exited
        if ~obj.runFlag && obj.exitflag==0;
            obj.returncode=2;
            obj.Psy.dispSep('RUN_END---COMPLETE');
        elseif obj.exitflag==1
            obj.returncode=-2;
            obj.Psy.dispSep('RUN_END---USER-EXIT');
        elseif obj.runFlag
            obj.returncode=-1;
            obj.Psy.dispSep('RUN_END---ERROR');
        else
            % XXX?
            obj.returncode=1;
        end

        if obj.bPsy && obj.bPTB && ~isempty(obj.PTB)
            obj.Psy.PTB.sca();
        end
        if obj.returncode==-1
            obj.ME=lasterror;
        end
        obj.im.restore();
        warning('on','MATLAB:hg:AutoSoftwareOpenGL');

        disp(newline)
        disp('Viewer Status');
        disp(['  runFlag    =  ' num2str(obj.runFlag)]);
        disp(['  exitflag   =  ' num2str(obj.exitflag)]);
        disp(['  returncode =  ' num2str(obj.returncode)]);
        disp(newline)
        if ~isempty(obj.errmsg)
            Error.warnSoft(strjoin(obj.errmsg,newline));
        end

        obj.exitflag=true;
    end
    function exit_prompt(obj)
        if obj.Flags.get_needs_save();
            if obj.bPsy
                obj.Psy.present_quit_prompt();
            else
                obj.Info.print(obj.infoList,'Save before quiting (Y/N)?');
            end
        else
            obj.exit();
        end
    end
end
methods(Access=private)
    function print(obj,bUp,msg)
        obj.Info.print();
    end
    function bSuccess=update(obj,bUp,msg)
        if ischar(bUp) && strcmp(bUp,'all')
            bUp=struct('cmd',1,'im',1,'tex',1,'draw',1);
        end

        % CHECK FOR UPDATE
        bSuccess=obj.bUpdate(bUp);
        if ~bSuccess
            return
        end

        % UPDATE IM
        if bUp.im || bUp.Viewer
            obj.reload();
        end

        % UPDATE INFO
        obj.update_info(bUp);

    end
    function out=bUpdate(obj,bUp)
        out=false;
        flds=fieldnames(bUp);
        for i = 1:length(flds)
            if ~bUp.(flds{i})
                continue
            end

            meth=['update_' flds{i}];
            if ~ismethod(obj.Info,meth) && ~ismember(flds{i},{'tex'})
                error(['unhandled method: ' meth ]);
            end
            out=true;
        end
    end
    function append_msg(obj,msg)
        obj.Info.append_msg(msg);
    end
    function update_info(obj,bUp)
        % NOTE NEEDS TO COME AFTER reload()

        % PRINT INFO
        obj.Info.update(bUp);
        opts=obj.printOpts.stringOpts();
        list=opts.list;
        obj.Info.format(list,opts);

        if obj.bPsy
            obj.Psy.apply_infos();
        end

    end
%% MAIN
    function main(obj,bInit) % Indep
        %obj.exitflag

        % READ
        obj.Psy.dispSep('RUN_END');
        [exitflag,bUp,msg]=obj.Cmd.main();
        if ~isempty(msg)
            obj.append_msg(msg);
        end
        if obj.exitflag || exitflag;
            return
        end

        % UPDATE
        bSuccess=obj.update(bUp,msg);
        if ~bSuccess
            return
        end

        % PRINT
        if obj.bPrint
            obj.print(bUp,msg);
        end


        % PLOT
        if obj.bPlot && (bUp.im || bUp.patch || bUp.Viewer)
            obj.plot();
        end

        % DRAW
        bgo =bUp.im || bUp.patch || bUp.Viewer;
        %bgo =(bUp.cmd || bUp.str || bUp.im || bUp.patch || bUp.Viewer); % XXX TEX
        if obj.bPsy && bgo
            obj.drawPsy(bUp);
        end

    end
%% DRAW
    function present_loading()
        if obj.bPsy
            obj.Psy.present_loading();
        else
            % TODO
        end
    end
    function drawPsy(obj,bUp)
        %nS=obj.PsyInt.getNSub;
        [opts,name]=obj.PsyInt.getSubOpts(obj.int,obj.s);
        opts=obj.optsAppend(opts,bUp);
        obj.runSubInt(opts,name);
    end
    function opts=optsAppend(obj,opts,bUp)
        % TODO GEN THIS
        bEcho=bUp.key;
        bCmd=bUp.cmd | bUp.str;
        bStmInfo=bUp.Flags | bUp.Filter | bUp.win;
        bIm=bUp.im | bUp.patch;

        if bIm
            opts=obj.optsAppend_fun(opts,'stm');
        end
        if bStmInfo
            opts=obj.optsAppend_fun(opts,'stmInfo');
        end
        if bCmd
            opts=obj.optsAppend_fun(opts,'cmd');
        end
        if bEcho
            opts=obj.optsAppend_fun(opts,'echo');
        end
    end
    function opts=optsAppend_fun(obj,opts,name)
        % XXX check
        if ~ismember(name,opts.reset);
            opts.reset{end+1}=name;
        end
        if ~ismember(name,opts.draw)
            opts.draw{end+1}=name;
        end
    end
    function runSubInt(obj,opts,name)
        if opts.t ~= 0 && obj.t ~= opts.t
            return
        elseif opts.modt ~= 0 && mod(obj.t,opts.modt)~=0
            return
        end

        % KEY-CHANGE
        if ~strcmp(opts.key, obj.Cmd.getKeyDefName) || (~isempty(opts.mode) && ~strcmp(opts.mode,obj.Cmd.getMode))
            obj.Cmd.changeKey(opts.key, opts.mode);
        end

        % IMS
        obj.get_ims(opts);

        % DRAW
        obj.Psy.draw_subInt(opts);

        % HOOK
        if ~isempty(opts.hook)
            obj.run_hook(opts.hook);
        end
        % LOAD
        if opts.loadt > 0
            obj.trl_load_check(opts.loadt);
        end
        % WAIT
        if opts.time > 0
            obj.wait(opts.time,opts.loadt > 0);
        end
    end
    function get_ims(obj,opts)
        flds=fieldnames(obj.stmOpts);
        for i = 1:length(opts.reset)
            if ismember(opts.reset{i},flds)
                obj.get_ims_stm(opts.reset{i});
            end
        end
    end
    function map=get_ims_stm(obj,name)
        opts=obj.stmOpts.(name);
        flds=fieldnames(opts);

        % META
        if ischar(opts.XYpix) && strcmp(opts.XYpix,'@Ptch')
            opts.XYpix=obj.Ptchs.ptch.win.win.posXYpix;
        end
        if ischar(opts.WHpix)
            if strcmp(opts.WHpix,'@Ptch')
                opts.WHpix=obj.Ptchs.ptch.win.win.WHpix;
            elseif strcmp(opts.WHpix,'@wdwXYpix')
                opts.WHpix=obj.Psy.PTB.wdwXYpix;
            end
        end
        if ischar(opts.duration) && strcmp(opts.duration,'@Ptch')
            opts.duration=obj.Ptchs.get_duration(obj.trl, obj.int);
        end

        bMap=true;
        if strcmp(opts.src,'noise')
            map{1}=Noise.makeMsk(opts.WHpix);
            map{2}=map{1};
            bMap=false;
        elseif strcmp(opts.src,'img')
            fld='im';
        elseif strcmp(opts.buffORptch,'buff')
            fld='mapsBuff';
        elseif strcmp(opts.buffORptch,'ptch')
            fld='map';
        end
        if bMap
            map=obj.Ptchs.ptch.(fld).(opts.src);
        end

        if ~ismember(opts.src,{'img','noise'})
            for i = 1:2
                if size(map{i},3) > 1
                    map{i}=map{i}(:,:,3);
                end
                map{i}=map{i}-min(min(map{i}));
                map{i}=map{i}/max(max(map{i}));
            end
        end
        if opts.bZer
            map{2}=map{1};
        end
        if strcmp(opts.mode,'sbs')
            map=obj.im_to_sbs(map);
        end
        num=[]; % and name TODO
        obj.Psy.update_im(name,[],map);
        obj.Psy.update_geom(name,[],opts.XYpix,opts.WHpix);
        obj.Psy.update_duration(name,[],opts.duration);
    end
    function sbs=im_to_sbs(obj,map)
        sbs=cell(1,2);
        sbs{1}=[map{1} map{2}];
        sbs{2}=sbs{1};
    end
%% PLOT
    function obj=plot(obj)
        if isempty(obj.f)
            obj.f=Fig.new(); % ::this
            obj.sp=[];
        end
        try
            figure(obj.f)
        catch
            obj.f=Fig.new();
            figure(obj.f)
            obj.sp=[];
        end
        S=obj.plotOpts;
        sp=obj.Ptchs.ptch.plot('sp',S.sp, ...
                               'clim',S.clim, ...
                               'pos',S.pos, ...
                               'bSP',S.bSP, ...
                               'bPht',S.bPht, ...
                               'bXYZ',S.bXYZ, ...
                               'bImg',S.bImg,...
                               'bAnaglyph',S.bAnaglyph, ...
                               'bZer',S.bZer,...
                               'buffORptch',S.buffORptch ...
                            );
        % XXXX clim = old filters
        obj.pos=[];
        drawnow
    end
    function get_patch(obj)
        obj.lidx=obj.Filter.getLoadIdx();
        obj.pidx=obj.Filter.getPidx();
        if strcmp(obj.mode,'view')
            if isempty(obj.lidx)
                try
                    obj.Ptchs.get_patch(obj.pidx,[],true);
                catch ME
                    % NOTE, FILES MAY NOT BE GENERATED, SO SKIP OVER THEM
                    if strcmp(ME.identifier,'MATLAB:load:couldNotReadFile')
                        obj.next();
                    else
                        rethrow(ME);
                    end
                end
            else
                obj.Ptchs.get_patch(obj.lidx);
            end
        else
            if ~obj.Ptchs.bLoadedB(obj.lidx)
                obj.Ptchs.load_patch(obj.lidx);
            end
            obj.Ptchs.ptch=obj.Ptchs.INDSB(obj.lidx);
        end
    end
end
methods
%% ZOOM
    function obj=zoom_in(obj,inc)
        % TODO
        obj.bUpdate.plot=1;
        if ~exist('inc','var') || isempty(inc)
            inc=0.05;
        end
        if obj.bPsy
            obj.stmSz=obj.stmSz+inc;
        else
            obj.pos=obj.sp.position;
            obj.pos(3:4)=obj.pos(3:4)*mult;
        end
    end
    function obj=zoom_out(obj,dec)
        % TODO
        obj.bUpdate.plot=1;
        if ~exist('dec','var') || isempty(dec)
            dec=0.05;
        end
        if obj.bPsy
            obj.stmSz=obj.stmSz-dec;
        else
            obj.pos=obj.sp.position;
            obj.pos(3:4)=obj.pos(3:4)*mult;
        end
    end
%% MODE
    function msg=toggleMode(obj)
        obj.Filter.toggleMode();
        obj.get_patch();
        msg=obj.Filter.returnMsg;
    end
    function msg=changeMode(obj,moude)
        obj.Filter.changeMode();
        obj.get_patch();
        msg=obj.Filter.returnMsg;
    end
%% MOVEMENT
    function msg=reload(obj)
        obj.Flags.seen(obj.pidx)=true;
        obj.get_patch();
        msg=obj.Filter.returnMsg;
    end
    function msg=Reload(obj)
        msg=obj.reload();
    end
    function msg=first(obj)
        obj.Flags.seen(obj.pidx)=true;
        abs=obj.Filter.goto(1);
        if ~isequal(abs,obj.abs)
            obj.abs=abs;
            obj.get_patch();
        end
        msg=obj.Filter.returnMsg;
    end
    function msg=last(obj)
        obj.Flags.seen(obj.pidx)=true;
        abs=obj.Filter.goto('last');
        if ~isequal(abs,obj.abs)
            obj.abs=abs;
            obj.get_patch();
        end
        msg=obj.Filter.returnMsg;
    end
    function msg=prev(obj)
        obj.Flags.seen(obj.pidx)=true;
        abs=obj.Filter.prev();
        if ~isequal(abs,obj.abs);
            obj.abs=abs;
            obj.get_patch();
        end
        msg=obj.Filter.returnMsg;
    end
    function msg=next(obj)
        obj.Flags.seen(obj.pidx)=true;
        abs= obj.Filter.next();
        if ~isequal(abs,obj.abs);
            obj.abs=abs;
            obj.get_patch();
        end
        msg=obj.Filter.returnMsg;
        % XXX exit if last in exp
    end
    function msg=goto(obj,rel,bForce)
        if nargin < 3
            bForce=false;
        end
        if ~isempty(obj.pidx)
            obj.Flags.seen(obj.pidx)=true;
        end
        abs= obj.Filter.goto(rel);
        if bForce || ~isequal(abs,obj.abs)
            obj.abs=abs;
            obj.get_patch();
        end
        msg=obj.Filter.returnMsg;
    end
%% TRIAL
    function get_trial(obj)
        blk=obj.Blk.blk(obj.Filter.abs.blk).ret();
        obj.trl=blk('trl').ret();
        obj.int=blk('intrvl').ret();
        obj.nInt=numel(blk('trl',obj.trl,'intrvl').unique());
    end
%% FILTER
    function msg=filter(obj,fld,sign,crit, bOR)
        if nargin < 5
            bOR=[];
        end

        [msg,abs]=obj.Filter.filter(fld,sign,crit,bOR);
        if ~isequal(abs,obj.abs)
            obj.abs=abs;
            obj.get_patch();
        end
    end
    function msg=unfilter(obj)

        abs=obj.Filter.unfilter();
        if ~isequal(abs,obj.abs)
            error('this should not happend')
        end
        msg=obj.Filter.returnMsg;
    end
    function msg=sort(obj,fld,bRev)
        if nargin < 3
            bRev=[];
        end
        [msg,abs] = obj.Filter.sort(fld,bRev);
        if ~isequal(abs,obj.abs);
            error('this should not happend')
        end
    end
    function msg=unsort(obj)
        abs= obj.Filter.unsort();
        if ~isequal(abs,obj.abs)
            error('this should not happend')
        end
        msg=obj.Filter.returnMsg;
    end
    function msg=rmSort(obj,fld)
        abs=obj.Filter,rmSort(fld);
        if ~isequal(abs,obj.abs)
            error('this should not happend')
        end
        msg=obj.Filter.returnMsg;
    end
    function msg=rmFilter(obj,fld,sign,crit,bOR)
        abs=obj.Filter.rmFilter(fld,sign,crit,bOR);
        if ~isequal(abs,obj.abs)
            error('this should not happend')
        end
        msg=obj.Filter.returnMsg;
    end

    function bTimeout=wait_fun(obj,ti,te)
        bTimeout=false;
        if isempty(ti)
            ti=GetSecs;
        end
        bNew=1;
        % XXX change to quit mode
        while true
            if ~bNew
                [exitflag,bUp,msg]=obj.Cmd.main();
                if exitflag
                    obj.exitflag=1;
                    return
                end
            else
                bNew=false;
            end
            if GetSecs-ti >= te
                bTimeout=true;
                return
            end
        end
    end

end
methods(Access=?Psycho)
    function wait(obj,wTime,bLoadTime)
        if nargin < 3
            bLoadTime=false;
        end
        if bLoadTime
            start=obj.LChk.loadTime;
            obj.LChk.loadTime=0;
        else
            start=[];
        end
        obj.wait_fun(start,wTime);
    end
    function trl_load_check(obj,n)
        obj.LChk.trl_load_check(n,obj.trl,obj.int);
    end
end
methods(Static)
    function P=getStmP()
        P={...
            'buffORptch',[],'ischar_e'; ...
            'mode',      'sng','ischar_e'; ...
            'src',       'img','ischar_e'; ...
            'bZer',      0,'isbinary'; ...
            'bWindow',   1,'isbinary'; ...
            'WHpix',   [],'@(x) true'; ...
            'XYpix',   [],'@(x) true'; ...
            'duration',   [],'@(x) true'; ...
            'stmMult', 1, 'Num.is';...
            'floatPrecision',0,'Num.is';...
        };
    end
    function P=getP()
        P={...
           'mode','view','ischar';
           'bPlot',[],'isBinary_e';
           'bPsy', false, 'isBinary';
           'bPrint',true,'isBinary';
           ... % PTB
           'printOpts',[], 'isoptions_e';
           'plotOpts', [], 'isoptions_e';
           'psyOpts',  [], 'isoptions_e';
           'stmOpts',  [], 'isoptions_e';
           'rspOpts',  [], 'isoptions_e';
           'ptbOpts',  [], 'isoptions_e';
           'bKey',true,'isBinary_e';   % XXX ?
           'bAct',true','isBinary_e';  % XXX ?
          };

    end
end
end
