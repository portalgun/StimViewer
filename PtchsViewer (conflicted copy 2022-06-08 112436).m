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
    bInit
    bOverrideCmd
    bPTB=false
    exitflag=false
    completeflag=false
    runFlag
    returncode
    bExitExternal=false
    ME

    preStr
    %list

    bKey % XXX ?
    bAct % XXX ?
    bPsy
    bPrint
    bPlot

    util
    printOpts
    ptbOpts
    imOpts
    utilOpts
    psyOpts
    plotOpts
    rspOpts
    expIntName
    viewIntName


    % Opts
    % STM OPTS

    ims

    s
    int
    trl
    nTrl


    bUp

    intOpts
    oIntOpts
    lastIntOpts
    cmdOpts
    lastCmdOpts

    lastText

    abs
    pidx
    lidx
    bPause=false
    bNext=false
    bShell
    bReloop=false

    key % certain responses
    bKeyChange

    preDebugTrial

end
properties(Hidden)
    PTB    % dep
    Plot
    PsyInt % dep
    ExpPsyInt
    ViewPsyInt
    DebPsyInt
    Ptchs
    Cmd
    Echo
    Filter
    Flags
    Info
    Psy    % dep
    Rsp
    LChk
    PtchOpts %holder
    Im

    tmp % DEBUGGIN
end
methods(Static)
    function Opts = readConfig(alias)
        if nargin < 1 || isempty(alias)
            alias=obj.getAlias();
        end
        Opts=Cfg.read(['D_viewer_' alias '.cfg']);
        Opts2=Cfg.read(['D_viewer_util.cfg']);
        Opts=Opts.mergePref(Opts2,1,true);
    end
    function alias=getAlias()
        alias=getenv('VIEWER_ALIAS');
        if isempty(alias)
            alias=ptchs.getAlias;
        else
            Env.var('ALIAS');
        end
    end
end
methods
    function obj=PtchsViewer(ptchs,alias,bPsy,moude,bExitExternal)


        obj.Ptchs=ptchs;
        obj.Ptchs.dire=[];
        dire=obj.Ptchs.get_dir();
        obj.Ptchs.dire=dire;

        if nargin < 2
            alias=[]; %
        end
        if nargin < 3
            bPsy=[];
        end
        if nargin >= 4
            obj.mode=moude;
        else
            obj.mode='view';
        end
        if nargin >= 5
            obj.bExitExternal=bExitExternal;
        end

        obj.init(alias,bPsy);
    end
    function error(obj,text)
        obj.errmsg{end+1,1}=text;
    end
end
methods(Access=private)
%% RUN
    function init(obj,alias,bPsy,bForce)
        if isempty(alias)
            alias=obj.getAlias;
        end
        obj.alias=alias;

        Opts=PtchsViewer.readConfig(obj.alias);
        if ~isempty(bPsy)
            Opts{'bPsy'}=bPsy;
        end

        %PARSE
        obj=Args.parse(obj,PtchsViewer.getP,Opts);
        obj.parse_print_opts();
        obj.parse_util_opts();

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
    function re_init(obj)
        % RESET PTCHS OPTS
        obj.PtchOpts.restore();
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

        obj.reload();
    end
    function init_parts(obj)
        if isempty(obj.bPsy)
            obj.bPsy=false;
        end

        % INT
        obj.ExpPsyInt=PsyInt(obj.expIntName, obj.util);

        obj.DebPsyInt=PsyInt(obj.expIntName,obj.util);
        %obj.DebPsyInt.modifyAll('autoInc',0);
        %obj.DebPsyInt.modifyAll('mode','normal'); XXX
        if ~isempty(obj.viewIntName)
            obj.ViewPsyInt=PsyInt(obj.viewIntName);
        end

        switch obj.mode
        case 'exp'
            obj.PsyInt=obj.ExpPsyInt;
        case 'debug'
            obj.PsyInt=obj.DebPsyInt;
        case 'view'
            obj.PsyInt=obj.ViewPsyInt;
        end


        % CMD -- Viewer
        defName=obj.PsyInt.getKey();
        if isempty(obj.Cmd)
            obj.Cmd=PsyShell(obj,defName);
        end

        % FILTER - Ptchs
        if isempty(obj.Filter)
            obj.Filter=PtchsFilter(obj.Ptchs);
        end

        % FLAGS -- Filter
        obj.Flags=obj.Ptchs.Flags;
        obj.Flags.setFilter(obj.Filter);

        % OPTS
        obj.PtchOpts=Holder(obj);

        % RSP
        obj.init_Rsp();

        % Plot
        obj.Plot=PtchsPlotter();

        % LChk
        obj.LChk=PtchsLoadChk(obj);

        % IM
        obj.Im=PtchsIm(obj);

        % INFO -- Ptchs, Viewer, Flags, Filter
        obj.Info=PtchsInfo(obj);

        % PSY
        if obj.bPsy
            obj.init_psy();
        end

    end
    function obj=parse_print_opts(obj)
        P=PtchsInfo.getP();
        sOpts=Args.parse(struct(),P,obj.printOpts{'stringOpts'});
        obj.printOpts=struct('stringOpts',sOpts);
    end
    function init_psy(obj)
        allOpts=obj.imOpts.mergePref(obj.psyOpts);
        obj.Psy=Psycho(obj,allOpts);
        obj.bPsy=true;


        hn=Sys.hostname;
        if ~strcmp(obj.Ptchs.ptchOpts.DispInfo,hn)
            Error.warnSoft('Hostname does not match, adjusting ptchOpts');
            obj.Ptchs.VDisp=hn;
        end

    end
    function obj=parse_util_opts(obj)
        P={ ...
            'bTimer',   0,'isbinary';...
            'bEcho',   1,'isbinary';...
            'bCounter',1,'isbinary';...
            'bFlags'  ,1,'isbinary';...
        };
        obj.utilOpts=Args.parse(struct(),P,obj.utilOpts);

        flds=fieldnames(obj.utilOpts);
        obj.util={};
        for i = 1:length(flds)
            fld=flds{i};
            if fld(1)~='b';
                continue
            end
            name=Str.Alph.lower(fld(2:end));
            if obj.utilOpts.(fld)
                obj.util{end+1,1}=name;
            end
        end

    end
    function obj=init_Rsp(obj)
        if  isempty(obj.rspOpts)
            return
        end
        obj.Rsp=Rsp(obj.Ptchs.Blk, obj.rspOpts);

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
%% RUN
end
methods
    function cont(obj)
        CL=onCleanup(@() obj.exit()); % run exit on complete or error % XXX
        obj.PTB.keyOn_noMat();
        obj.exitflag=0;
        obj.reloop();
        obj.exitflag
        obj.main_loop();
        obj.exitflag
    end
    function run(obj,start,bOnce,preStr)
        if nargin < 4
            obj.preStr=[];
        else
            obj.preStr=preStr;
        end
        obj.errmsg={};
        obj.runFlag=1;
        obj.exitflag=false;
        obj.completeflag=false;
        obj.bInit=true;
        obj.intOpts=struct();

        if ismember(obj.mode,{'exp','debug'})
            obj.nTrl=obj.Ptchs.get_nTrial();
        else
            obj.nTrl=inf;
        end

        CL=onCleanup(@() obj.exit()); % run exit on complete or error % XXX
        if nargin < 2 || isempty(start)
            start=1;
        end
        if nargin < 3
            bOnce=false;
        end

        if obj.bPsy && ~obj.bPTB
            obj.init_ptb();
        end

        obj.reset();
        %obj.Ptchs.ptchOpts.flatAnchor='L';  % XXX

        switch obj.mode
            case 'exp'
                obj.exp_mode(true);
            case 'debug'
                obj.debug_mode(true);
            case 'view'
                obj.view_mode(true);
        end
        obj.Psy.dispSep(obj.mode);

        obj.main_loop();

    end
    function main_loop(obj)
        %profile clear
        %profile on
        while true
            obj.main();
            obj.bInit=false;
            if obj.exitflag || obj.completeflag
                break
            end
        end
        obj.preStr=[];

        obj.runFlag=0;
    end
    function obj=init_ptb(obj)
        lasterror('reset');
        obj.bPTB=1;
        obj.PTB=Ptb([],obj.ptbOpts); % 10 ptb
        obj.Psy.PTB=obj.PTB;

        obj.Psy.init_aux();
        obj.Psy.dispSep('RUN');
    end
    function reset(obj)
        obj.bReloop=false;
        obj.tmp=0;
        obj.exitflag=false;
        obj.Info.msg=' ';
        obj.Cmd.resetKey();

        obj.errmsg={};
        obj.intOpts=struct();
        obj.init_cmdOpts();
    end
    function obj=exit(obj)
        % runflag
        % consistent with runner
        % 2  complete
        % 0  run
        % -1 error
        % -2 exited
        if obj.completeflag==1
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

        if obj.bPsy && obj.bPTB && ~isempty(obj.PTB) && (~obj.bExitExternal || obj.runFlag==-1)
            obj.Psy.PTB.close();
            obj.bPTB=false;
        end
        if obj.returncode==-1
            obj.ME=lasterror;
            display(newline)
            display(newline)
            display([num2str(obj.trl) ' ' num2str(obj.int) ' ' num2str(obj.s)]);
            display(obj.PsyInt.sName)
            %if ~isempty(obj.intOpts) && numel(fieldnames(obj.intOpts)) > 0
            %    obj.intOpts
            %    obj.intOpts.text
            %end
        end
        obj.PtchOpts.restore();
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
%% MODES
    function view_mode(obj,bFirst)
        if nargin < 2; bFirst=false; end

        if strcmp(obj.mode,'exp')
            obj.preDebugTrial=obj.trl;
        end

        obj.Filter.init('unq');
        obj.s=1;
        obj.int=1;
        obj.bInit=true;
        % GET LOCATION

        obj.bPause=false;

        obj.mode='view';
        obj.PsyInt=obj.ViewPsyInt;

        if ~bFirst
            obj.show_util(false);
            obj.reloop();
        end
    end
    function debug_mode(obj,bFirst)
        if nargin < 2; bFirst=false; end

        if strcmp(obj.mode,'exp')
            obj.preDebugTrial=obj.trl;
        end

        obj.PsyInt=obj.DebPsyInt;
        obj.copyPsyInt([],'debug');
        obj.mode='debug';
        obj.PsyInt.bInit=true;

        if ~bFirst
            obj.append_reset(obj.util,1);
            obj.show_info();
            obj.reloop();
        end
    end
    function copyPsyInt(obj,srcMode,destMode)
        if isempty(srcMode)
            srcMode=obj.mode;
        end
        bView=strcmp(srcMode,'view');
        switch srcMode
        case {'exp','experiment'}
            S=obj.ExpPsyInt;
        case {'view','viewer'}
            S=obj.ViewPsyInt;
            bView=true;
        case {'deb','debug'}
            S=obj.DebPsyInt;
        end

        switch destMode
        case {'exp','experiment'}
            D=obj.ExpPsyInt;
        case {'view','viewer'}
            D=obj.ViewPsyInt;
            bView=true;
        case {'deb','debug'}
            D=obj.DebPsyInt;
        end

        flds=fieldnames(S);
        skip={'INTS','INTNAMES','nSInts','defaults'};
        flds(ismember(flds,skip))=[];
        for i = 1:length(flds)
            D.(flds{i})=S.(flds{i});
        end
        %D.bPause=false;
        D.reInit;
    end
    function exp_mode(obj,bFirst)
        if nargin < 2; bFirst=false; end

        if ~isempty(obj.preDebugTrial)
            obj.cmdOpts.mode='yn';
            obj.make_prompt('Return to last trial?');
            obj.redraw();
            if obj.key
                obj.trl=obj.PsyInt.goto(obj.preDebugTrial);
                obj.preDebugTrial=[];
            end
            obj.key=[];
        end

        obj.PsyInt=obj.ExpPsyInt;
        obj.mode='exp';

        if ~bFirst
            %obj.hide_util(false);
            obj.append_reset(obj.util,1);
            obj.reloop();
        end
    end
%% PROMPTS
    function make_prompt(obj,txt,name,bMode)
        if nargin < 3
            name='ctrText';
        end
        if nargin < 4
            bMode=true;
        end

        obj.lastCmdOpts=obj.cmdOpts;
        obj.lastIntOpts=obj.intOpts;
        if bMode
            obj.cmdOpts.bPause=~obj.bPause;
            obj.cmdOpts.mode=obj.Cmd.getMode();
            obj.bPause=true;
        end

        text=struct();
        text.name=name;
        text.num=1;
        text.text=txt;

        Opts=struct();
        Opts.bgColor=0;
        Opts.borderFill=0;
        Opts.borderWidth=1;

        text.Opts=Opts;
        obj.cmdOpts.text=text;

        %obj.append_reset(name,1);
        obj.intOpts.text=obj.cmdOpts.text;

        obj.redraw;
        %obj.merge_opts();
        %obj.change_key();
        %obj.redraw();

    end
    function close_prompt(obj,name,bRedraw)
        if nargin < 2 || isempty(name)
            name='ctrText';
        end
        if nargin < 3
            bRedraw=true;
        end
        if obj.cmdOpts.bPause
            obj.bPause=false;
        end
        obj.cmdOpts=obj.lastCmdOpts;
        obj.intOpts=obj.lastIntOpts;
        %obj.cmdOpts.text.text='';
        %obj.intOpts.text.text='';

        obj.unappend_reset(name);
        %obj.append_reset(name,0);
            %obj.cmdOpts.draw(cellfun(@isempty,obj.cmdOpts.draw))=[];
            %obj.cmdOpts.reset(cellfun(@isempty,obj.cmdOpts.reset))=[];

        if bRedraw
            obj.reloop();
            obj.PsyInt.continueTime();
        end

    end
    function plotting_prompt(obj)
        txt='Plotting...';
        obj.make_prompt(txt);
    end
    function continue_prompt(obj,str)
        if nargin < 2 || isempty(str)
            str='';
        else
            str=[str newline];
        end
        %txt='Continue to next block? (Y/N)';
        txt=[str 'Continue to next block?'];
        obj.up_down_prompt(txt);
    end
    function up_down_prompt(obj,txt);
        txt=[txt ' (Up=Yes / Down=No)'];
        obj.make_prompt(txt);

        obj.Cmd.changeKey([], 'cont');
        bCmd=false;
        obj.exitflag=0;
        pause(.1);
        while ~bCmd
            [bCmd,obj.bUp,msg,obj.bKeyChange]=obj.Cmd.main();
        end
        obj.Cmd.lastMode();
        obj.close_prompt([],false);
        obj.reloop();
        %obj.redraw();
    end
    function exit_prompt(obj)
        txt='Are you sure you want to quit? (Y/N)';
        obj.make_prompt(txt);
    end
    function save_prompt(obj)
        txt='Save before quitting? (Y/N)';
        obj.make_prompt(txt);
    end
    function help_prompt(obj)
        if ismember(obj.mode,{'exp','debug'})
            obj.key_help_prompt();
        else
            dk
        end
    end
    function key_help_prompt(obj)
        txt=obj.Cmd.getKeyDefString();
        obj.make_prompt(txt);
    end
    function cmd_help_prompt(obj)
        txt=obj.Cmd.getKeyCmdStrings();
        obj.make_prompt(txt);
    end
    function pause_prompt(obj,bCmd)
        if nargin < 2
            moude=obj.Cmd.getMode();
            bCmd=strcmp(moude,'cmd') || ~strcmp(obj.mode,'exp');
        end
        txt='Pause';
        if bCmd
            obj.make_prompt(txt,'cmdText',false);
        else
            obj.make_prompt(txt);
        end
    end
%% SHOW/HIDE
    function show(obj,names,nums,bMode,moude,bRedraw)
        if ~iscell(names)
            names={names};
        end
        if nargin < 3  || isempty(nums)
            nums=ones(numel(names),1);
        end
        if numel(nums) > 1 &&  numel(names) == 1
            repmat(names,numel(nums),1);
        end

        if nargin >=4 && ~isempty(bMode)
            obj.cmdOpts.mode=obj.Cmd.getMode();
        elseif nargin >= 5 && ~isempty(moude)
            obj.cmdOpts.mode=moude;
        end
        if nargin < 6 || isempty(bRedraw)
            bRedraw=true;
        end

        %for i = 1:length(names)
            %obj.Psy.show(names{i},nums(i));
        %end
        obj.append_reset(names,0);

        if bRedraw
            obj.reloop();
        end
    end
    function hide(obj,names,nums,bMode,bRedraw)
        if ~iscell(names)
            names={names};
        end
        if nargin < 3 || isempty(nums)
            nums=ones(length(names),1);
        end
        if numel(nums) > 1 &&  numel(names) == 1
            repmat(names,numel(nums),1);
        end
        if nargin < 4 || isempty(bMode)
            bMode=false;
        end
        if nargin < 5 || isempty(bRedraw)
            bRedraw=true;
        end
        %for i = 1:length(names)
        %    obj.Psy.hide(names{i},nums(i));
        %end
        obj.unappend_reset(names);
        if bMode
            obj.cmdOpts.mode='';
        end

        if bRedraw
            obj.reloop();
        end
    end
    function toggle_fun(obj,names,nums,bMode)
        if ~iscell(names)
            names={names};
        end
        if nargin < 3  || isempty(nums)
            nums=ones(numel(names),1);
        end
        if numel(nums) > 1 &&  numel(names) == 1
            repmat(names,numel(nums),1);
        end
        bShow=any(ismember(obj.names, obj.intOpts.draw));
        if bShow
            obj.show(names,nums,bMode);
        else
            obj.hide(obj.names,nums);
        end
    end
    function show_info(obj)
        %obj.show({'stmInfo','stmInfo','stmInfo'},[1 2 3]);
        obj.show({'stmInfo'},[1 2 3 4]);
    end
    function hide_info(obj)
        %obj.show({'stmInfo','stmInfo','stmInfo'},[1 2 3]);
        obj.hide({'stmInfo'},[1 2 3 4]);
    end
    function show_cmd(obj)
        obj.bPause=true;
        obj.show({'cmd','echo'},[],[],'cmd',false);
        obj.Cmd.changeKeyStr('SHELL');
        obj.pause_prompt(true);
    end
    function hide_cmd(obj,bKey)
        if nargin < 2
            bKey=false;
        end
        if bKey && ~strcmp(obj.Cmd.Key.aKeyStr,'SHELL')
            return
        end
        if strcmp(obj.mode,'exp') && ~obj.utilOpts.bEcho
            list={'cmd','echo'};
            nums=[1 1];
        else
            list={'cmd'};
            nums=1;
        end
        bMode=true;
        bClose=true;

        % CLOSE IN REVERSE ORDER
        if bClose
            obj.close_prompt('cmdText');  % NOREDRAW
        end

        obj.bPause=false();
        obj.cmdOpts.bPause=false;
        obj.hide(list,nums,bMode,true);

        %obj.Cmd.lastMode();
    end
    function showUtil(obj)
        obj.show_util(true,false,true);
    end
    function show_util(obj,bRedraw,bOnce,bPersist)
        if nargin < 2
            bRedraw=true;
        end
        if nargin < 3
            bOnce=true;
        end
        if nargin < 4
            bPersist=false;
        end
        list=obj.Psy.utilList();
        obj.append_reset(list(:,1),bOnce,bPersist);
        if bRedraw()
            obj.reloop();
        end
    end
    function hide_util(obj,bRedraw)
        if nargin < 2
            bRedraw=true;
        end
        list=obj.Psy.utilList();
        obj.unappend_reset(list(:,1));
        if bRedraw
            obj.reloop();
        end
    end
    function toggle_intInfo(obj)
        obj.toggle_fun('stmInfo',4,false);
    end
%% SMART TOGGLE
    function cmd_full_screen(obj)
        m=obj.Info.cmdMode;
        if strcmp(m,'full')
            s='normal';
        else
            s='full';
        end
        obj.Info.cmdMode=s;
        obj.append_bUp('cmd');
        obj.reloop();
    end
    function cmd_esc_dwim(obj)
        aKey=obj.Cmd.Key.aKeyStr;
        if strcmp(aKey,'SHELL')
            str=obj.Cmd.getString();
            if isempty(str)
                if strcmp(obj.mode,'exp')
                    obj.hide_cmd(true);
                else
                    obj.cmdOpts.mode='';
                end
            else
                obj.Cmd.eval('_str_cancel');
            end
            obj.reloop();
        else
            obj.lastMode();
        end
        %'_str_cancel'           ,{'str','cancel_str'};
        %'hide'               ,{'Parent','hide_cmd'};
    end
    function lastMode(obj)
        moude=obj.Cmd.lastMode;
        obj.Cmd.eval(['_' moude '_mode'],false);
        %obj.Cmd.eval_ex({'key','change_to_lastMode'},0);
        %moude
        obj.cmdOpts.mode=moude;
        obj.Cmd.changeKeyStr('SHELL');
        obj.redraw();
    end
    function out=is_pause_prompt(obj)
        out=ismember('ctrText',obj.cmdOpts.draw) && numel(fieldnames(obj.cmdOpts.text)) > 0 && strcmp(obj.cmdOpts.text.text,'Pause');
    end
    function toggle_pause(obj)
        if obj.is_pause_prompt
            obj.close_prompt();
        elseif obj.bPause
            obj.close_prompt;
            obj.pause_prompt();
        else
            obj.pause_prompt;
        end
    end
%end
%methods(Access=private)
%% MAIN
    function main(obj) % Indep
        %- READ
        if ~obj.bReloop
            obj.read();
            if obj.exitflag; return; end
        end
        obj.bReloop=false;

        %- MERGE OPTIONS
        obj.merge_opts();

        if strcmp(obj.intOpts.name,'expStart') && ~isempty(obj.preStr)
            n=ceil((length(obj.intOpts.text.text)-length(obj.preStr))/2);
            spc=repmat(' ',1,abs(n));
            obj.intOpts.text.text=[ obj.preStr newline spc obj.intOpts.text.text];
        end

        %- KEY
        obj.change_key();

        %- PATCH
        exiflag=obj.get_patch();
        if exiflag; return; end

        %- IMS
        obj.Im.get_ims(obj.intOpts);

        %- Info
        obj.update_info(obj.bUp);

        %- PRINT
        if obj.bPrint
            %clc;
            %obj.Info.print();
        end

        %- PLOT
        if obj.bPlot
            obj.Plot.plot(obj.Im.ims,obj.Im.opts);
        end

        %- PSY
        if obj.bPsy
            obj.apply_text();
            obj.Psy.draw(obj.intOpts);
        end

        %- HOOK
        if ~isempty(obj.intOpts.hook)
            obj.run_hook(obj.intOpts.hook);
        end
        %- LOAD
        if obj.intOpts.loadTrls > 0
            obj.trl_load_check(obj.intOpts.loadTrls);
        end

    end
    function reloop(obj)
        obj.bReloop=true;
        obj.main();
    end
    function redraw(obj)
        if ~obj.bPsy
            return
        end
        %obj.Im.get_ims(); %XXX needed?
        obj.merge_opts();
        obj.apply_text();
        obj.Psy.draw(obj.intOpts);
    end
    function read(obj)
        % TWO SOURCES OF CMD: PSYSHELL & PSYINT
        while true
            % THINK OF CMD COMMING LAST IN THE LOOP RATHER THAN FIRST...
            if obj.bInit
                obj.bUp=obj.Cmd.bUp;
                bCmd=true;
            elseif obj.bOverrideCmd
                bCmd=true;
                obj.bOverrideCmd=false;
            else
                [bCmd,obj.bUp,msg,obj.bKeyChange]=obj.Cmd.main();
                obj.Info.append_msg(msg);
                if obj.exitflag; return; end
            end
            [bNew,obj.s,obj.int,obj.trl,obj.oIntOpts]=obj.PsyInt.getInt(obj.bInit,obj.bPause,bCmd,obj.PTB.onsetT,obj.bNext);
            obj.bNext=false;
            obj.intOpts=obj.oIntOpts;

            % EXIT
            if obj.trl > obj.nTrl;
                obj.exitflag=true;
                obj.completeflag=true;
                return
            end

            if ~bNew; continue; end
            break
        end
        obj.append_bUp('int');
        if ismember_cell(obj.mode,{'exp','debug'})
            obj.append_bUp('rsp');
        end
        if ismember_cell(obj.bUp,'PtchOpts')
            obj.append_reset('stm',1);
        end

    end
    function change_key(obj)
        if (~strcmp(obj.intOpts.key, obj.Cmd.getKeyDefName) || (~isempty(obj.intOpts.mode) && ~strcmp(obj.intOpts.mode,obj.Cmd.getMode)))
            obj.Cmd.changeKey(obj.intOpts.key, obj.intOpts.mode);
        end
    end
    function append_bUp(obj,varargin)
        for i = 1:length(varargin)
            name=varargin{i};
            if ~ismember_cell(name,obj.bUp)
                obj.bUp{end+1,1}=name;
            end
        end
    end
    function exitflag=get_patch(obj,bReload)
        % TODO, 1. load raw patch, copy, apply opts
        %       2. bReload -- reload is recopy  & apply
        exitflag=false;
        if nargin < 2
            bReload=ismember_cell('stm',obj.intOpts.reset);
        end
        opts=[];
        bRaw=[];

        lastlidx=obj.lidx;
        obj.get_indeces();
        if (isequal(lastlidx, obj.lidx)  && ~bReload) || isempty(obj.lidx)
            return
        end
        obj.append_bUp('patch','im','win','Flags');
        obj.append_reset('!stm',1);
        obj.expand_fun('intOpts','reset');
        obj.Flags.inc_seen();

        for i = 1:20
            try
                obj.Ptchs.get_patch(obj.lidx,opts,bRaw,bReload);
                return
            catch ME
                % NOTE, FILES MAY NOT BE GENERATED, SO SKIP OVER THEM
                %ME.identifier
                str='MATLAB:load:couldNotReadFile';
                if ~strcmp(ME.identifier,str) || strcmp(obj.mode,'exp')
                    rethrow(ME);
                end
            end
            obj.Flags.toggle_bad(true);
            obj.Info.append_msg(ME.message);

            obj.Filter.next();
            obj.get_indeces();
            obj.append_bUp('Filter');
            obj.intOpts.reset;
        end
        error('Too many files missing')
        %obj.bOverrideCmd=true;

        %exitflag=true;
    end
    function get_indeces(obj)
        if strcmp(obj.mode,'view')
            obj.pidx=obj.Filter.getPidx();     % PATCH NUMBER
            obj.lidx=obj.Filter.getLoadIdx();  % LOAD NUMBER, Different if BLK
        elseif obj.int > 0 & obj.trl > 0
            obj.lidx=obj.Ptchs.Blk.blk.find('trl',obj.trl,'intrvl',obj.int);
            obj.pidx=obj.Ptchs.Blk.blk(obj.lidx,'P').ret();
        end
    end
    function update_info(obj,bUp)
        % PRINT INFO
        obj.Info.update(bUp);
        opts=obj.printOpts.stringOpts();
        list=opts.list;
        if obj.bInit
            names=props(obj.Info);
            names=names(endsWith(names,'Info'));
        end
        obj.Info.format(list,opts);

        if obj.bPsy
            obj.Psy.apply_infos();
        end

    end
    function init_cmdOpts(obj)
        obj.cmdOpts=obj.intOpts;
        flds=fieldnames(obj.cmdOpts);
        for i = 1:length(flds)
            fld=flds{i};
            if ischar(obj.cmdOpts.(fld))
                obj.cmdOpts.(fld)='';
            elseif isnumeric(obj.cmdOpts.(fld))
                obj.cmdOpts.(fld)=[];
            elseif isstruct(obj.cmdOpts.(fld))
                obj.cmdOpts.(fld)=struct();
            elseif iscell(obj.cmdOpts.(fld))
                obj.cmdOpts.(fld)={};
            end
        end
        obj.cmdOpts.rm_draw={};
        obj.cmdOpts.rm_reset={};
        obj.cmdOpts.rm_close={};

        obj.cmdOpts.resetToRm={};
        obj.cmdOpts.bPause=false;
    end
    function merge_opts(obj)
        % if ptchopts are changed, reset. causes reloading of patch

        if obj.bInit
            obj.init_cmdOpts;
            %if strcmp(obj.mode,'view')
            if ismember_cell(obj.mode,{'debug','view'})
                list=obj.Psy.utilList();
                obj.append_reset(list(:,1),0);

                flds={'reset','draw','close'};
                for i = 1:length(flds)
                    expand_fun(obj,'intOpts',flds{i});
                end
            end
            return
        end


        obj.cmdOpts.reset(ismember_cell(obj.cmdOpts.reset, obj.cmdOpts.resetToRm))=[];
        obj.cmdOpts.resetToRm={};

        if obj.bKeyChange
            obj.cmdOpts.mode=obj.Cmd.getMode;
        end

        % MERGE cmdOpts, usually from CMD
        flds=fieldnames(obj.intOpts);
        for i = 1:length(flds)
            fld=flds{i};
            cmd=obj.cmdOpts.(fld);
            Int=obj.intOpts.(fld);

            if iscell(cmd)
                cmd(cellfun(@isempty,cmd))=[];
                obj.cmdOpts.(fld)=cmd;
            end
            if iscell(Int)
                obj.intOpts.(fld)=[Int ; cmd( ~ismember_cell(cmd, Int))];
            elseif isstruct(Int)
                if numel(fieldnames(cmd))==0
                    continue
                end
                if ~isequal(Int,cmd) && strcmp(fld,'text')
                    obj.append_reset(cmd.name);
                end
                if length(Int)==1 && length(cmd)==1
                    if strcmp(Int.name,cmd.name) || numel(fieldnames(Int)) > 0
                        obj.intOpts.(fld)=cmd;
                        obj.append_reset(cmd.name);
                    else
                        %obj.intOpts.(fld)(end+1,1)=cmd; XXX
                        obj.intOpts.(fld)=cmd; %XXX
                    end
                else
                    TODO
                end

            elseif ~isempty(cmd)
                obj.intOpts.(fld)=cmd;
            end
        end

        flds={'reset','draw','close'};
        for i = 1:length(flds)
            obj.intOpts.(flds{i})(ismember_cell(obj.intOpts.(flds{i}), obj.cmdOpts.(['rm_' flds{i}])))=[];
            obj.expand_fun('intOpts',flds{i});
        end

    end
    function expand_fun(obj,opts,fld)
        ind=startsWith(obj.(opts).(fld),'!');
        if ~any(ind)
            return
        end
        inds=find(ind);
        for i = 1:length(inds)
            switch obj.(opts).(fld){ind}
            case '!stm'
                list=obj.Psy.stmList(:,1);
            case '!util'
                list=obj.Psy.utiList(:,1);
            case '!aux'
                list=obj.Psy.utiList(:,1);
            case  '!prompt'
                list=obj.Psy.promptList(:,1);
            otherwise
                error(['Unhandled meta' obj.(opts).(fld){ind}] )
            end
            obj.(opts).(fld){ind}=list;
        end
        obj.(opts).(fld)=unique(vertcat(obj.(opts).(fld){:}));
    end
    function out=append_update(obj,name)
        two=ismember_cell(name,obj.intOpts.reset);
        out=ismember_cell(name,obj.intOpts.draw) || two;
        if out && ~two
            obj.intOpts.reset{end+1,1}=name;
        end
    end
    function append_reset(obj,name,bOnce,bPersist)
        if iscell(name)
            name=unique(name);
            cellfun(@(x) obj.append_reset(x,bOnce),name);
            return
        end
        if nargin < 3
            bOnce=false;
        end
        if nargin < 4
            bPersist=false;
        end
        % DRAW NEXT INTERVAL
        try
            if ~ismember(name,obj.intOpts.reset)
                obj.intOpts.reset{end+1,1}=name;
            end
        catch ME
            rethrow(ME);
        end
        if ~ismember(name,obj.intOpts.draw)
            obj.intOpts.draw{end+1,1}=name;
        end

        if bOnce
            return
        end

        % DRAW UNTIL REMOVED
        if bPersist && ~ismember(name,obj.cmdOpts.reset)
            obj.cmdOpts.reset{end+1,1}=name;
        end
        if ~ismember(name,obj.cmdOpts.draw)
            obj.cmdOpts.draw{end+1,1}=name;
        end
        obj.cmdOpts.resetToRm{end+1}=name;
    end
    function unappend_reset(obj,name)
        if iscell(name)
            name=unique(name);
            cellfun(@(x) obj.unappend_reset(x), name);
            return
        end
        if ismember(name,obj.cmdOpts.draw)
            obj.cmdOpts.draw(ismember(obj.cmdOpts.draw,name))=[];
        end
        if ismember(name,obj.cmdOpts.reset)
            obj.cmdOpts.reset(ismember(obj.cmdOpts.reset,name))=[];
        end
        if ismember(name,obj.intOpts.draw)
            obj.intOpts.draw(ismember(obj.intOpts.draw,name))=[];
        end
        if ismember(name,obj.intOpts.reset)
            obj.intOpts.reset(ismember(obj.intOpts.reset,name))=[];
        end
    end
    function apply_text(obj)
        opts=obj.intOpts.text;
        %if isempty(opts) || numel(fieldnames(opts)) < 1 || isempty(opts.text)
        if isempty(opts) || numel(fieldnames(opts)) < 1
            return
        end
        name=opts.name;
        num=opts.num;
        txt=opts.text;


        Opts=opts.Opts;
        if isempty(Opts)
            Opts=struct();
        end
        Oflds=fieldnames(Opts);

        oflds=fieldnames(opts);
        oflds(ismember_cell(oflds,[Oflds {'text','name','num','Opts'}]))=[];
        for i = 1:length(oflds)
            Opts.(oflds{i})=opts.(oflds{i});
        end

        obj.Psy.apply_text(name,num,txt,Opts);
    end
    function exitflag=pass_string(obj,str,dest,args)
        exitflag=true;
        if isempty(args)
            msg='No arguments';
            obj.Cmd.append_msg(msg);
            return
        end

        if length(args)==1
            name=args{1};
            num=1;
        else
            name=args{1:end-1};
            num=1;
        end
        [flds,val,exitflag,msg]=Cfg.parseStr(str,'[\[\{\}:,] *');
        if exitflag && isempty(msg) % XXX FIX
            exitlflag=0;
        else exitflag
            obj.Cmd.append_msg(msg);
            return
        end

        if strcmp(dest,'Parent')
            exitflag=obj.apply_opt(name,num,flds,val);
        else
            switch dest
                case 'stm'
                    exitflag=obj.Im.apply_opt(name,num,flds,val);
                case 'util'
                case 'prompt'
                case 'aux'
                otherwise
                    return
            end
            if ~exitflag
                obj.append_bUp('Psy');
                obj.append_reset(args{1},1); % XXX ?
                obj.Psy.reselect();
                obj.reloop();
            end
        end
    end
    function out=apply_opt(obj,str,args)
        out=[];
        str
        args
    end
    function [name,num,flds,val]=get_selected(obj)
        [name,num,flds,val]=obj.Psy.get_selected();
    end
    function append_msg(obj,msg,bViewer)
        if nargin < 1
            bViewer=false;
        end
        obj.Cmd.append_msg(msg);
        if bViewer
            TODO
        end
    end
    function apply_im_update(obj,name,num,map,opts)
        obj.Psy.update_im(name,num,map);
        obj.Psy.update_geom(name,num,opts.posOpts.posXYpix,opts.posOpts.WHpix);
        obj.Psy.update_priority(name,num,opts.priority);
        obj.Psy.update_duration(name,num,opts.duration);
        if ~isempty(opts.duration)
            obj.PsyInt.modifyS('time',opts.duration);
            %obj.cmdOpts.time=opts.duration;
        end
    end
end
methods
%% RSP
    function respond(obj,val)
        time=obj.Cmd.popKeyTime-obj.PsyInt.sStartT;
        obj.Rsp.respond(obj.trl,val,time);
    end
    function inc_rsp_flag(obj)
        obj.Rsp.inc_flag(obj.trl);
    end
    function dec_rsp_flag(obj)
        obj.Rsp.dec_flag(obj.trl);
    end
    function reset_rsp_flag(obj)
        obj.Rsp.reset_flag(obj.trl);
    end
%% RELOAD
    function msg=reload(obj)
        obj.get_patch(true);
    end
    function next_trial(obj,val)
        obj.bNext=true;
    end
    function prev_trial(obj,val)
        obj.bNext=-1;
    end
    function change_blk(obj,moude,lvlInd,blocks);
        vDisp=obj.Ptchs.VDisp;
        obj.Ptchs.exp_init(obj.Ptchs.Blk.alias, moude,lvlInd,blocks);
        obj.Ptchs.apply_display(vDisp.hostname,vDisp.subjname);
        obj.PtchOpts=Holder(obj);
        obj.init_Rsp();
    end
    function trl_load_check(obj,n)
        obj.LChk.trl_load_check(n,obj.trl);
    end
%% FILTER
    function get_trial(obj)
        blk=obj.Ptchs.Blk.blk(obj.Filter.abs.blk);
        obj.trl=blk('trl').ret();
        obj.int=blk('intrvl').ret();
        obj.nTrl=numel(blk('trl',obj.trl,'trl').unique());
    end
%% CONVENIENCE
    function out=el(obj,name,num)
        if nargin < 3
            num=1;
        end
        out=obj.Psy.A.(name){num};
        if ~isempty(out.Obj)
            out=out.Obj;
        end
    end
    function out=El(obj,name,num)
        if nargin < 3
            num=1;
        end
        out=obj.Psy.A.(name){num};
    end
%% MISC
    function run_hook(obj,hook)
        hook=strsplit(hook,'.');
        out=regexp(hook{end},'\(([^)])\)','once');
        if ~isempty(out)
            args=strsplit(out,',');
        end
        if numel(hook)==1
            if ismethod(obj,hook{1})
                obj.(hook{1});
            else
                eval([hook ';'])
            end
        else
            obj.(hook{1}).(hook{2});
        end
    end

end
methods(Static)
    function P=getP()
        P={...
           'bPlot',[],'isBinary_e';
           'bPsy', false, 'isBinary';
           'bPrint',true,'isBinary';
           ... % PTB
           'printOpts',[], 'isoptions_e';
           'plotOpts', [], 'isoptions_e';
           'psyOpts',  [], 'isoptions_e';
           'imOpts',  [], 'isoptions_e';
           'rspOpts',  [], 'isoptions_e';
           'ptbOpts',  [], 'isoptions_e';
           'utilOpts',  [], 'isoptions_e';
           'expIntName',[],'ischar_e';
           'viewIntName',[],'ischar_e';
           'bKey',true,'isBinary_e';   % XXX ? cmd?
           'bAct',true','isBinary_e';  % XXX ? cmd?
          };

    end
end
end
