classdef Rsp < handle
properties
    Blk

    bSound
    bRspOnly
    magORval
    cmpNum

    cndInd
    lvlInd
    cmpInd

    nTrials
    trial
    cmpX
    stdX
    cmpInt
    answers
    bCtr

    R
    RTime
    bRCmp
    bRCorrect
    flags

    Tbl
    Curve
end
methods
    function obj=Rsp(blk,Opts)
        obj.Blk=blk;
        obj.parse(Opts);
        obj.init();
    end

    function init(obj)
        obj.nTrials=max(obj.Blk.blk.unique('trl'));
        obj.trial=Vec.col(1:obj.nTrials);
        obj.R=nan(obj.nTrials,1);
        obj.RTime=nan(obj.nTrials,1);
        obj.flags=zeros(obj.nTrials,1);
        if ~obj.bRspOnly
            obj.get_answers();
        end
    end
    function parse(obj,Opts)
        P=obj.getP();
        Args.parse(obj,P,Opts);
    end
    function untable(obj)
        tbl=obj.Table('cmpX','stdX','cmpInt','R','Rtime','bRCmp','bRCorrect','flags').ret();
        obj.cmpX      = tbl(:,1);
        obj.stdX      = tbl(:,2);
        obj.cmpInt    = tbl(:,3);
        obj.R         = tbl(:,4);
        obj.RTime     = tbl(:,5);
        obj.bRCmp     = tbl(:,6);
        obj.bRCorrect = tbl(:,7);
        obj.flags     = tbl(:,8);
    end
    function apply(obj,Rsp)
        Rsp.untable();
        if isequal(Rsp.cmpX,   obj.cmpX)   && ...
           isequal(Rsp.stdX,   obj.stdX)   && ...
           isequal(Rsp.cmpInt, obj.cmpInt) && ...
           isequal(Rsp.answers,obj.answers);
            ind=isnan(Rsp.R) && isnan(obj.R);
            obj.R(ind)        = Rsp.R(ind);
            obj.Rtime(ind)    = Rsp.Rtime(ind);
            obj.bRCmp(ind)    = Rsp.bRCmp(ind);
            obj.bRCorret(ind) = Rsp.RCorret(ind);
            obj.flags(ind)    = Rsp.flags(ind);
            out=true;
        elseif nargout < 1
            error('Uncompatible tables')
        else
            out=false;
        end
    end
    function apply_data(obj,data)
        [stdX,cmpX,bRCmp]=data{'stdX','cmpX','bRCmp'};
        cmpX=Rsp.rmUniformCols(cmpX);
        stdX=Rsp.rmUniformCols(stdX);
        Opts.bPlotCI=false;
        Opts.bPlot=true;
        obj.Curve=psyCurve(stdX, cmpX, bRCmp,Opts);
    end
    function get_answers(obj)
        obj.bRCorrect=nan(obj.nTrials,1);
        obj.bRCmp=nan(obj.nTrials,1);
        obj.cmpInt=obj.Blk.get_cmpIntrvl(obj.trial,obj.cmpNum);
        obj.cndInd=obj.Blk('intrvl',1,'cndInd').ret();
        obj.lvlInd=obj.Blk('intrvl',1,'lvlInd').ret();
        obj.cmpInd=obj.Blk('intrvl',1,'cmpInd').ret();
        obj.cmpX=obj.Blk.trial_to_cmpX(obj.trial,obj.cmpNum);
        obj.stdX=obj.Blk.trial_to_stdX(obj.trial);

        if strcmp(obj.magORval,'mag')
            obj.cmpX=abs(obj.cmpX);
            obj.stdX=abs(obj.stdX);
        end
        cmpX=obj.cmpX(:,1);
        stdX=obj.stdX(:,1);

        obj.answers=nan(size(obj.cmpInt));

        ind=cmpX > stdX & obj.cmpInt==1;
        obj.answers(ind)=1;

        ind=cmpX < stdX & obj.cmpInt==1;
        obj.answers(ind)=2;

        ind=cmpX > stdX & obj.cmpInt==2;
        obj.answers(ind)=2;

        ind=cmpX < stdX & obj.cmpInt==2;
        obj.answers(ind)=1;

        obj.bCtr=isnan(obj.answers);
        obj.answers(obj.bCtr) = double(rand(sum(obj.bCtr),1) > 0.5)+1;
    end
    function respond(obj,trl,int,time)
        obj.R(trl)=int;
        obj.RTime(trl)=time;
        if obj.bRspOnly
            return
        end
        obj.bRCmp(trl)=int==obj.cmpInt(trl);
        obj.bRCorrect(trl)=(int==obj.answers(trl)) || obj.bCtr(trl);

        if obj.bSound
            obj.sound(obj.bRCorrect(trl));
        end
    end
    function setAllCorrect(obj)
        bSound=obj.bSound;
        obj.bSound=false;

        time=zeros(size(obj.answers));
        obj.respond(obj.trial,obj.answers,time);

        obj.bSound=bSound;
    end
    function [cmp,std,int,answer,flag]=getTrial(obj,trl)
        cmp=obj.cmpX(trl);
        std=obj.stdX(trl);
        int=obj.cmpInt(trl);
        answer=obj.answers(trl);
        flag=obj.flags(trl);
    end
    function [TBL,ind]=finalize(obj)
        key=  { 'trial',  'cmpX',   'stdX',   'cmpInt', 'R',      'RTime',  'bRCmp',     'bRCorrect', 'flags'};
        types={ 'uint16', 'double', 'double', 'uint8',  'double', 'double', 'logical',   'logical',   'uint8'};
        ind=isnan(obj.bRCmp);
        tbl=cell(1,length(key));
        O=Obj.copy(obj);
        for i = 1:length(key)
            O.(key{i})(ind,:)=[];
            O.(key{i})=cast(O.(key{i}),types{i});
            tbl{1,i}=O.(key{i});
        end
        obj.Tbl=Table(tbl,key,types);
        if nargout > 0
            TBL=obj.Tbl;
            ind=find(ind);
        end
    end
    function obj=sound(obj,bCorrect)
        if isnan(bCorrect)
            obj.sound_correct();
        elseif  bCorrect
            obj.sound_correct();
        else
            obj.sound_incorrect();
        end
    end
    function inc_flag(obj,trl)
        obj.flags(trl)=obj.flags(trl)+1;
    end
    function dec_flag(obj,trl)
        obj.flags(trl)=obj.flags(trl)-1;
    end
    function reset_flag(obj,trl)
        obj.flags(trl)=0;
    end
    function plotCurve(obj,varargin)
        if isempty(obj.Tbl)
            obj.finalize();
        end
        Tbl=obj.Tbl;
        if nargin > 1
            Tbl=obj.Tbl(varargin{:});
        end
        [stdX,cmpX,bRCmp]=obj.Tbl{'stdX','cmpX','bRCmp'};

        Opts.bPlotCI=false;
        obj.Curve=psyCurve(stdX, cmpX, bRCmp,Opts);

        uNames=obj.Blk.lookup.lvl.KEY(2:end);
        U=EUnits(uNames{:});

        str=obj.Curve.stdstr(U{'mult','name'},true);
        Fig.new();
        obj.Curve.Plot(U{1,'meas','units','mult','frmt'}{:});
        title(str);
        axis square;
    end
end
methods(Static)
    function X=rmUniformCols(X)
        n=size(X,2);
        ind=false(1,n);
        for i = n
            ind(i)=all(X(:,i)==X(1,i));
        end
        X(:,ind)=[];
    end
    function P=getP()
        P={...
            ;'bRspOnly',0,'isBinary'...
            ;'magORval',[], 'ischar_e'...
            ;'bSound', 1, 'Num.isBinary'...
            ;'cmpNum',1,'Num.isBinary'
        };
    end
    function sound_equal()
        freq = 0.5475;
        sound(sin(freq.*[0:1439]).*cosWindowFlattop([1 1440],720,720,0));
    end
    function obj = sound_correct()
        freq = 0.73;
        sound(sin(freq.*[0:1439]).*cosWindowFlattop([1 1440],720,720,0));
    end
    function obj = sound_incorrect()
        freq = 0.3650;
        sound(sin(freq.*[0:1439]).*cosWindowFlattop([1 1440],720,720,0));
    end
end
end
