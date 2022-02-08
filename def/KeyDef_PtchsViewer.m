classdef KeyDef_PtchsViewer < handle & KeyDef
properties
    i=containers.Map % insert
    c=containers.Map % command

    n=containers.Map % normal
    g=containers.Map % go
    v=containers.Map % visual
    k=containers.Map % num go

    z=containers.Map % ZOOM
    r=containers.Map % RELOAD
    d=containers.Map % RM
    D=containers.Map % DEL
    s=containers.Map % STIM
    t=containers.Map % TOGGLE
    C=containers.Map % CH
    q=containers.Map % Quit prompt
end
properties(Constant)
    stdModes={'n','e','i','g','k','v','c',  'q','z','r','d','D','s','t','C'};
end
methods
    function obj=KeyDef_PtchsViewer();
        obj.name='PtchsViewer';
        obj.mode='n';
        obj.defMode='n';


        E=KeyDef_PtchsViewer.getEx();
        [D,T]=KeyDef_PtchsViewer.get();
        modes=KeyDef_PtchsViewer.stdModes;
        obj.init(E,D,modes,T);
   end
end
methods(Static)
    function E=getEx();
        E=KeyDef_vim.getEx();
        e={...

                'ex_return'          ,{{'Cmd','ex_return'},{'key','last_mode'}};
                't bad'              ,{'Flags','toggle_bad'};
                't other'            ,{'Flags','toggle_other'};
                't filter'           ,{'Filter','toggleMode'};
                't ana'              ,{{'Viewer','toggle','bAnaglyph'},{'Viewer','reload'}};
                't pht'              ,{{'Viewer','toggle','bPht'},{'Viewer','reload'}};
                't xyz'              ,{{'Viewer','toggle','bXYZ'},{'Viewer','reload'}};
                't key'              ,{{'Viewer','toggle','bKey'},{'Viewer','reload'}};
                't act'              ,{{'Viewer','toggle','bAct'},{'Viewer','reload'}};
                't help'             ,{'Viewer','toggle','bHelp'};
                't stmInfo'          ,{'Viewer','toggle','bStmInfo'};
                't sbs'              ,{'Viewer','toggle','sbs'};
                'm ch'               ,{'key','mode','C'};
                'm toggle'           ,{'key','mode','t'};
                'm stm'              ,{'key','mode','s'};
                'm rm'               ,{'key','mode','d'};
                'm del'              ,{'key','mode','D'};
                'm zoom'             ,{'key','mode','z'};
                'm reload'           ,{'key','mode','r'};
                'm quit'             ,{'key','mode','q'};
                ...
                'r view'             ,{'Viewer','reload'};
                'r parts'            ,{'Viewer','re_init_parts'};
                'r ptch'             ,{'Viewer','Reload'};
                'z in'               ,{'Viewer','zoom_in'};
                'z out'              ,{'Viewer','zoom_out'};
                ...
                't patchORbuff'      ,{'Viewer','toggle','ptchORbuff',{'ptch','buff'}};
                't dc'               ,{'im','toggle','dcFix' ,{0,'@o.dcFix'}};
                't rms'              ,{'im','toggle','rmsFix',{0,'@o.rmsFix'}};
                't bino'             ,{'im','toggle','monoORbinoFix',{'mono','bino'}};
                't rmsBino'          ,{'im','toggle','monoORbinoContrast',{'mono','bino'}};
                %'t flat'             ,{'im','toggle','flatAnchor',{'L','R',''}};
                't flat'             ,{'im','toggle','bFlat'};
                't window'           ,{{'im','toggle','bWindow'};
                                       {'Viewer','toggle','bWindow'}};
                't zer'              ,{'im','toggle','trgtInfo.trgtDsp',{0,'@o.trgtInfo.trgtDsp'}};
                ...
                'i clim'             ,{{'key','mode','c'}, {'str','insert_str','clim '}};
                'i disparity'        ,{{'key','mode','c'}, {'str','insert_str','disparity '}};
                ...
                ...
                'clim'               ,{'Viewer','set','clim','$','$'};
                'disparity'          ,{{'im','trgtInfo'},'set','trgtDsp','$'};
                'rms'                ,{'im','set','rmsFix','$'};
                'dc'                 ,{'im','set','dcFix','$'};
                'mult'               ,{'Viewer','set','stmMult','$'};
                ...
                'i mult'             ,{{'key','mode','c'}, {'str','insert_str','mult '}};
                'i filter'           ,{{'key','mode','c'}, {'str','insert_str','filter '}};
                'i sort'             ,{{'key','mode','c'}, {'str','insert_str','sort '}};
                'i sortrev'          ,{{'key','mode','c'}, {'str','insert_str','sortrev '}};
                'i rmfilter'         ,{{'key','mode','c'}, {'str','insert_str','rmFilter '}};
                'i rmsort'           ,{{'key','mode','c'}, {'str','insert_str','rmSort '}};
                ...
                'd filter'           ,{'Filter','unfilter'};
                'd sort'             ,{'Filter','unsort'};
                'd ptchOpts'         ,{'go','reset_ptchOpts'};
                ...
                'rmFilter'           ,{'Filter','rmFilter','$0'};
                'rmSort'             ,{'Filter','rmSort','$0'};
                'filter'             ,{'Filter','filter','$0'};
                'sort'               ,{'Filter','sort',  '$0',false};
                'sortrev'            ,{'Filter','sort',  '$0',true};
                ...
                'm n'                ,{'key','mode','n'};
                'w'                  ,{'Flags','save'};
                'wq'                 ,{{'Flags','save'},{'Viewer','exit'}};
                'q!'                 ,{'Viewer','exit'};
                ...
                'q'                  ,{{'key','mode','q'},{'Viewer','exit_prompt'}};
                'q y'                ,{{'Flags','save'},{'Viewer','exit'}};
                'q n'                ,{'Viewer','exit'};
                'q esc'              ,{'key','last_mode'};

        };
        E=[E; e];
    end
    function [D,T]=get()
        [D,T]=KeyDef_vim.get();
        d={...
              'q y'           ,'q',  'y';
              'q n'           ,'q',  'n';
              'q esc'         ,'q',  '\]';
              %'m c'           ,'Cs',':';
              %'m n'           ,'Cs','\[';
              't bad'         ,'Csn' ,'\t';
              't other'       ,'Csn' ,'\tS';
              ...
              'r view'        ,'r' ,'v';
              'r parts'       ,'r' ,'V';
              'r ptch'        ,'r' ,'p';
              ...
              'z in'          ,'z' ,'i';
              'z out'         ,'z' ,'o';
              ...
              't ana'         ,'t' ,'a';
              't bino'        ,'t' ,'b';
              't patchORbuff' ,'s' ,'c';
              't dc'          ,'t' ,'D';
              't filter'      ,'t' ,'f';
              't stmInfo'     ,'t' ,'i';
              't key'         ,'t' ,'k';
              't pht'         ,'t' ,'p';
              't flat'        ,'t' ,'d';
              't rms'         ,'t' ,'r';
              't sbs'         ,'t' ,'s';
              't rmsBino'     ,'t' ,'R';
              't window'      ,'t' ,'w';
              't xyz'         ,'t' ,'x';
              't zer'         ,'t' ,'z';
              't help'        ,'n' ,'?';
               ...
              'd ptchOpts'    ,'D' ,'p';
              'd filter'      ,'D' ,'f';
              'd sort'        ,'D' ,'o';
              ...
              'i rmfilter'    ,'d' ,'f';
              'i rmsort'      ,'d' ,'o';
              'i filter'      ,'n' ,'f';
              'i sort'        ,'n' ,'o';
              'i sortrev'     ,'n' ,'O';
              'm ch'          ,'n' ,'c';
              'm stm'         ,'n' ,'s';
              'm toggle'      ,'n' ,'t';
              'm del'         ,'n' ,'D';
              'm rm'          ,'n' ,'d';
              'm reload'      ,'n' ,'r';
              ...
              'd ptchOpts'    ,'s' ,'\d';
              'i clim'        ,'s' ,'c';
              'i disparity'   ,'s' ,'d';
              'm n'           ,'tnivkgCsdr' ,'\]';
              'ex_return'     'c','\n';
              %'ex_return'     ,'qc', '\n'
        };
        D=[D; d];
        T=[T 'trDz'];
    end
end
end

