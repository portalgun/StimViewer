classdef PtchsViewer < handle & ptchsViewer_actions & ptchsViewer_info
% TODO binVal -> edges
% TODO binVal -> edges
% TODO refresh on resize
properties
    F

    clim
    stmSz=1

    rmsFix
    dcFix
    buffORptch='buff'
    bWindow
    bCrp
    bZer
    flatAnchor=''
    monoORbinoContrast
    monoORbinoFix

    sp=[]
    pos
    f

    ptchOpts
    bHelp=0
    bStmInfo=1
    bXYZ=1
    bSBS=1
    bPht=1
end
properties(Hidden)
    bPTB
    bUpdate
    KEY
    exitflag=0
    promptflag=0
    lastMode='n'

    Disp
    tmp=0

    STR
    OUT
    TXT
end
methods
    function obj=PtchsViewre(fnameORptchs,keyDefName,Opts,bRun)
        warning('off','MATLAB:hg:AutoSoftwareOpenGL');
        obj.f=Fig.next;

        keyOpts=struct();
        keyOpts.bPtb=0;
        if ~exist('keyDefName','var') || isempty(keyDefName)
            keyOpts.keyDefName='ptchsViewer';
        end
        if ~exist('bRun','var') || isempty(bRun)
            bRun=1;
        end

        obj.KEY=Key(keyOpts);

        if ~exist('Opts','var') || isempty(Opts)
            Opts=struct();
        end
        obj=obj.parseOpts(Opts);

        obj.init_info();
        obj.init_update();

        obj.F=ptchsFilter(fnameORptchs,0);
        obj.apply_opts();
        obj.F.start;


        %ListenChar(-1);
        %CL=onCleanup(@() obj.exit); % run exit on complete or error
        obj.main();
    end
    function obj=exit(obj)
        ListenChar(1);
        warning('on','MATLAB:hg:AutoSoftwareOpenGL');
        if obj.bPTB
            %close all;
        end
    end
    function obj=init_update(obj)
        obj.bUpdate=struct();

        obj.bUpdate.key=1;
        obj.bUpdate.new=1;
        obj.bUpdate.cmd=1;
        obj.bUpdate.plot=1;

        obj.bUpdate.disp=1;
        obj.bUpdate.go=1;
        obj.bUpdate.im=0;
        if obj.bPTB
            obj.bUpdate.tex=0;
        end
    end
    function obj=parseOpts(obj,Opts)
        p=ptchsViewer.get_parseOpts();
        obj=Args.parse(obj,p,Opts);
    end
    function obj=main(obj)
        %clc
        while true
            if obj.bUpdate.cmd
                obj.get_strs();
                obj.draw();
                obj.bUpdate.cmd=0;
            end

            obj.KEY.read();
            isempty(obj.KEY.key);

            % HANDLE YES/NO PROMPT
            if obj.promptflag
                if ~isempty(obj.KEY.key)
                    if any(obj.KEY.key=='y')
                        obj.exitflag=1;
                        obj.promptflag=0;
                        if obj.bPTB
                            break
                        else
                            continue
                        end
                    elseif any(obj.KEY.key=='n')
                        obj.exitflag=0;
                        obj.promptflag=0;
                        if obj.bPTB
                            break
                        else
                            continue
                        end
                    end
                else
                    continue
                end
            end
            if ~isempty(obj.KEY.key)
                obj.bUpdate.key=1;
            end

            obj.STR=obj.KEY.STR.OUT;
            obj.OUT=obj.KEY.OUT;

            % MODE
            if ~strcmp(obj.KEY.mode, obj.lastMode)
                obj.lastMode=obj.KEY.mode();
                %obj.handle_mode_change();
                obj.bUpdate.cmd=1;
            end

            % COMMANDS
            obj.msg=[obj.KEY.mode];
            if ~isempty(obj.OUT)
                %display(obj.KEY.OUT)
                obj.parse_cmd(obj.OUT);
                obj.OUT=[];
            end
            if  ~isempty(obj.STR) && ~strcmp(obj.STR, obj.strL.STR)
                obj.strL.STR=obj.STR;
                obj.bUpdate.cmd=1;
                obj.STR=[];
            end
            if obj.bUpdate.im
                obj.reload();
            end

            if obj.exitflag
                ListenChar(1);
                warning('on','MATLAB:hg:AutoSoftwareOpenGL');
                break
            elseif obj.bPTB
                break
            end
        end
    end
    function obj=parse_sort(obj,fld,bRev)
        obj.F.sort(obj,fld,bRev);
    end
    function obj=parse_cmd(obj,CMD)
        if ~iscell(CMD{1})
            CMD={CMD};
        end
        for i = 1:length(CMD)

            cmd=CMD{i};
            if strcmp(cmd{1},'run')
                obj.parse_run(cmd(2:end));
            elseif strcmp(cmd{1},'set')
                obj.parse_set(cmd(2:end));
            elseif strcmp(cmd{1},'go')
                obj.parse_go(cmd(2:end));
            end
        end
        obj.bUpdate.plot=obj.bUpdate.plot | obj.F.bUpdate;
    end
    function obj=parse_run(obj,cmd)
        obj.bUpdate.cmd=1;
        switch cmd{1}
            case 'zoom_in'
                obj.zoom_in();
                obj.bUpdate.plot=1;
            case 'zoom_out'
                obj.zoom_out();
                obj.bUpdate.plot=1;
            case 'toggle_sbs';
                obj.toggle_sbs();
                obj.bUpdate.plot=1;
            case 'toggle_ind_mode'
                obj.F.toggle_mode();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_patch_or_buff'
                obj.toggle_patch_or_buff();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_crop'
                obj.toggle_crop();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_flat'
                obj.toggle_flat();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_window'
                obj.toggle_window();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_bZer'
                obj.toggle_window();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_xyz'
                obj.toggle_xyz();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_pht'
                obj.toggle_pht();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_mono_or_bino_contrast'
                obj.toggle_mono_or_bino_contrast();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case 'toggle_mono_or_bino_fix'
                obj.toggle_mono_or_bino_fix();
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            case ':'
                obj.parse_ex(obj.KEY.STR.OUT);
                obj.KEY.STR.OUT=[];
            case 'flag_next'
                obj.F.inc_flag();
            case 'flag_prev'
                obj.F.dec_flag();
            case 'toggle_help'
                obj.toggle_help();
            case 'toggle_stmInfo'
                obj.toggle_stmInfo();
            case 'clear_filter'
                obj.F.unFilter();
                %obj.F.rm_filter();
            case 'str'
                obj.parse_run_str(cmd(2:end));
            case 'reload'
                obj.bUpdate.plot=1;
            case 'Reload'
                obj.bUpdate.plot=1;
                obj.bUpdate.im=1;
            otherwise
                obj.bUpdate.cmd=0;
                return
        end
    end
    function obj=parse_set(obj,cmd)
        obj.bUpdate.cmd=1;
        switch cmd{1}
            case ':'
                obj.parse_ex(obj.KEY.STR.OUT);
                obj.KEY.STR.OUT=[];
            case 'str'
                return
            otherwise
                obj.bUpdate.cmd=0;
        end
    end
    function obj=parse_go(obj,cmd)
        obj.bUpdate.cmd=1;
        obj.bUpdate.new=1;
        obj.bUpdate.plot=1;
        switch cmd{1}
            case 'next'
                obj.next();
            case 'prev'
                obj.prev();
            case 'first'
                obj.first();
            case 'last'
                obj.last();
            case 'go'
                obj.go_to(str2double(obj.KEY.STR.OUT));
                obj.KEY.STR.OUT=[];
            otherwise
                obj.bUpdate.cmd=0;
                obj.bUpdate.im=0;
                obj.bUpdate.plot=0;
        end
    end
    function obj=parse_ex(obj,STR)
        obj.bUpdate.cmd=0;
        strs=strsplit(STR);
        i=0;
        while true
            i = i + 1;
            if i > length(strs)
                return
            end
            str=strs{i};
            l=length(strs(i:end));
            switch str
                case 'filter'
                    if l < 3; return; end

                    fld=strs{i+1};

                    val1=strs{i+2};
                    val2=[];
                    if l > 3
                        val2=strs{i+3};
                    end

                    obj.F.msg={''};
                    obj.F.filter(fld,val1,val2,'idx');
                    if ~isempty(obj.F.msg{1}) && contains(obj.F.msg{1},'Not valid')
                        obj.F.msg={''};
                        obj.F.filter(fld,val1,val2,'idxBlk');
                    end
                    %if ~isempty(obj.F.msg); return; end
                    if l > 3
                        i=i+3;
                    else
                        i=i+2;
                    end
                    obj.bUpdate.cmd=1;
                case 'sort'
                    if l < 2; return; end

                    fld=strs{i+1};
                    obj.F.sort(fld,0);
                    if ~isempty(obj.F.msg); return; end
                    i=i+1;
                    obj.bUpdate.cmd=1;
                case 'sortrev'
                    if l < 2; return; end
                    fld=strs{i+1};
                    obj.F.sort(fld,1);
                    if ~isempty(obj.F.msg); return; end
                    i=i+1;
                    obj.bUpdate.cmd=1;
                case 'clim'
                    if l < 2;
                        return
                    elseif Alph.is(strs{i+1})
                        fld=strs{i+1};
                        obj.clim=obj.F.get_clim(fld);
                        if ~isempty(obj.F.msg); return; end
                        i=i+1;
                    elseif l > 2 & isnum(strs{i+1}) && isnum(strs{i+2})
                        obj.clim=[str2double(strs{i+1}) str2double(strs{i+2})];
                    else
                        return
                    end
                    obj.bUpdate.cmd=1;
                    obj.bUpdate.plot=1;
                %case 'disparity'
                %    if l < 2; return; end
                %    if ~isnum(strs{i+1}); return; end
                %    fld=str2double(strs{i+1});


                %    if l > 2 & strs{i+2} == '1'
                %        obj.fix_disparity_all(fld);
                %    else
                %        obj.fix_disparity(fld);
                %    end

                %    obj.bUpdate.cmd=1;
                %    obj.bUpdate.plot=1;
                %case 'clear_disparity'
                %    if l < 2; return; end

                %    if l > 1 & strs{i+1} == '1'
                %        obj.unfix_disparity_all();
                %    else
                %        obj.unfix_disparity();
                %    end
                case 'rms'
                    if l < 2; return; end
                    if ~isnum(strs{i+1}); return; end
                    obj.rmsFix=str2double(strs{i+1});

                    if l > 2 & strs{i+2} == '1'
                        obj.fix_contrast_all();
                    else
                        obj.fix_contrast();
                    end

                    obj.bUpdate.cmd=1;
                    obj.bUpdate.plot=1;
                case 'dc'
                    if l < 2; return; end
                    if ~isnum(strs{i+1}); return; end
                    obj.dcFix=str2double(strs{i+1});

                    if l > 2 & strs{i+2} == '1'
                        Obj.fix_contrast_all();
                    else
                        obj.fix_contrast();
                    end

                    obj.bUpdate.cmd=1;
                    obj.bUpdate.plot=1;
                case {'clear_rms','rms_clear'}
                    if l < 1; return; end

                    obj.rmsFix=[];
                    if l > 2 & strs{i+1} == '1'
                        obj.unfix_contrast_all();
                    else
                        obj.unfix_contrast();
                    end

                    obj.bUpdate.cmd=1;
                    obj.bUpdate.plot=1;
                case {'clear_dc','dc_clear'}
                    if l < 1; return; end
                    obj.dcFix=[];


                    if l > 2 & strs{i+1} == '1'
                        obj.unfix_dc_all();
                    else
                        obj.unfix_dc();
                    end

                    obj.bUpdate.cmd=1;
                    obj.bUpdate.plot=1;
                case 'q'
                    obj.bUpdate.cmd=1;
                    obj.promptflag=1;
                    obj.KEY.STR.OUT='';
                case 'q!'
                    obj.exitflag=1;
                    obj.bUpdate.cmd=1;
                case 'wq'
                    obj.F.save();
                    obj.exitflag=1;
                    obj.bUpdate.cmd=1;
                case 'w'
                    obj.F.save();
                end
        end
    end
%% DRAW
    function obj=draw(obj)
        obj.TXT=obj.get_txt();
        if obj.bUpdate.plot && ~obj.bPTB
            %obj.draw_txt(obj.TXT);
            obj.plot();
            obj.bUpdate.plot=0;
            obj.F.bUpdate=0;
        end
    end
%% PLOT
    function obj=plot(obj)
        figure(obj.f)
        [obj.sp]=obj.F.ptchs.ptch.plot_viewer(obj.sp, obj.clim, obj.pos, obj.buffORptch, logical(obj.dcFix));
        obj.pos=[];
        drawnow
    end
    function obj=get_titles(obj)
        % fPos
        % pidx
        % values
    end
%% OTHER
end
methods(Static)
    function p=get_parseOpts()
        p={...
           'rmsFix',[],'Num.is_1_a_e' ...
          ;'dcFix' ,[],'Num.is_1_a_e' ...
          ;'bWindow' ,[],'Num.isBinary_1_a' ...
          ;'monoORbinoContrast' ,'bino','ischar_e' ...
          ;'monoORbinoFix' ,'bino','ischar_e' ...
          ;'bCrp' ,[],'Num.isBinary_1_a' ...
          ;'flatAnchor' ,'','Num.isBinary_1_a' ...
          ;'clim', [],'Num.is_1_2' ...
          ;'bPTB',0,'Num.isBinary' ...
          ;'bZer',1,'Num.isBinary' ...
          ;'bXYZ',1,'Num.isBinary' ...
          ;'bPht',1,'Num.isBinary' ...
          ;'stmSz',1,'Num.is_1_a_e' ...
          ;'bSBS',1,'Num.isBinary' ... % default, sbs
          };
    end
end
end
