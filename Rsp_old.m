classdef Rsp < handle & trlInt
properties

    % OUT
    answers % trlint
    responses
    RcmpChs
    bCorrect

    cmpIntrvl
    stdX
    cmpX

    % PARAMS
    bCheckCorrect % trlint
    bSoundCorrect % trlint
    bRecordAnswer
    bRecordResponse
    bRecordRcmpChs
    bFlip
    nIntrvl2Rsp % number of intervals with responses
    method
    expType

end
properties(Hidden=true)
    nTrial
    flags % XXX
    FlagNames % XXX
    bPsycho=0
end
events
end
methods
    function obj=Rsp(PARorOpts);
        if isa(PARorOpts,'psycho')
            obj.parse_psycho(PARorOpts);
        else
            Opts=PARorOpts;
            obj=obj.parse_Opts(Opts);
        end

    end
    function obj=parse_psycho(psycho)
        PAR=PARorOpts;
        obj.bPsycho=1;
        I=PAR.EXP.nIntrvl2Rsp;
        % XXX opts ?
        if obj.bPsycho && ~exist('nTrial','var') || isempty(nTrial)
            nTrial=PAR.EXP.nTrial;
        end
        if obj.bPsycho && (~exist('nIntrvl2Rsp','var') || isempty(nIntrvl2Rsp))
            nIntrvl=PAR.EXP.nIntrvl;
        elseif ~exist('nIntrvl2Rsp','var') || isempty(nIntrvl2Rsp)
            nIntrvl2Rsp=1;
        end
        obj.trlint_init(PAR); %handles update and all that
    end
    function obj=parse_Opts(obj,Opts)
        names={...
                  'bCheckCorrect', 1, 'Num.isBinary'...
                  ;'bSoundCorrect', 1, 'Num.isBinary'...
                  ;'bRecordResponse', 1, 'Num.isBinary'...
                  ;'bRecordAnswer', 1, 'Num.isBinary'...
                  ;'bRecordRcmpChs', 1, 'Num.isBinary'...
                  ;'method', 'val', 'ischar'...
                  ;'bFlip', 0, 'Num.isBinary'...
                  ;'nIntrvl2Rsp', 1, 'Num.isInt'...
                  ;'cmpX', [], ''...
                  ;'stdX', [], ''...
                  ;'cmpIntrvl', [], ''...
                  ;'expType', [], ''...
                  ;'nTrial', [], ''...
        };
        obj=Args.parse(obj,names,Opts);
        if isempty(obj.nTrial) && ~isempty(obj.stdX)
            obj.nTrails=obj.stdX;
        end
        if ~isempty(obj.nTrial)
            obj.responses=nan(obj.nTrial,obj.nIntrvl2Rsp);
            obj.bCorrect=nan(obj.nTrial,obj.nIntrvl2Rsp);
        end

        if ~isempty(obj.cmpX) && ~isempty(obj.stdX)
            ind=Set.isUniform(obj.cmpX,1) & Set.isUniform(obj.stdX,1);
            obj.stdX(:,ind)=[];
            obj.cmpX(:,ind)=[];
        end
        if obj.bRecordRcmpChs
            obj.RcmpChs=nan(obj.nTrial,obj.nIntrvl2Rsp);
        end
        if strcmp(obj.expType,'2IFC') && ~isempty(obj.cmpIntrvl) &&  all(ismember(obj.cmpIntrvl,[1,2])) && any(ismember(obj.cmpIntrvl,2))
            obj.cmpIntrvl=obj.cmpIntrvl-1;
        end
        obj.get_answers();
    end
    function obj=populate_rnd(obj)
        obj.bSoundCorrect=false;
        for t = 1:obj.nTrial
        for int=1:obj.nIntrvl2Rsp
            if strcmp(obj.expType,'2IFC')
                keyValue=randi(2)-1;
            end
            obj.record(t,int,keyValue);
        end
        end
    end

    function obj=record(obj,t,int,keyValue, answer)
        if ~exist('int') || isempty(int)
            int=1;
        end

        if (~exist('answer','var') || isempty(answer))
            answer=obj.answers(t,int);
        else
            obj.record_answer(answer,t,int);
        end
        obj.record_response(keyValue,t,int);
        obj.get_correct(answer,t,int);
        %[answer keyValue obj.bCorrect(t,int)]
        if obj.bSoundCorrect
            obj.sound(t,int);
        end
        if obj.bRecordRcmpChs
            obj.get_Rcmp(keyValue,t,int);
        end
    end
    function obj=get_answers(obj)
        if strcmp(obj.expType,'2IFC') && ~isempty(obj.cmpX) && ~isempty(obj.stdX) && ~isempty(obj.cmpIntrvl)
            obj.answers= Rsp.get_answers_2IFC(obj.stdX,obj.cmpX,obj.cmpIntrvl,obj.method);
        elseif ~isempty(obj.nTrial)
            obj.answers=zeros(obj.nTrial, obj.nIntrvl2Rsp);
        end
    end
    function obj=record_answer(obj,answer,t,i)
        obj.answer(t,i)=answer;
    end
    function obj=record_response(obj,keyValue,t,i)
        obj.responses(t,i)=keyValue;
    end
    function obj=get_correct(obj,answer,t,i)
        obj.bCorrect(t,i)=obj.responses(t,i)==answer;
    end
    function obj=get_Rcmp(obj,keyValue,t,i)
        if obj.bFlip
            obj.RcmpChs(t,i)=keyValue~=obj.cmpIntrvl(t,i);
        else
            obj.RcmpChs(t,i)=keyValue==obj.cmpIntrvl(t,i);
        end
    end
    function obj=sound(obj,t,i)
        if obj.bSoundCorrect & obj.bCorrect(t,i)
            obj.sound_correct();
        elseif obj.bSoundCorrect & ~obj.bCorrect(t,i)
            obj.sound_incorrect();
        end
    end
    function obj = sound_correct(obj)
        freq = 0.73;
        sound(sin(freq.*[0:1439]).*cosWindowFlattop([1 1440],720,720,0));
    end
    function obj = sound_incorrect(obj)
        freq = 0.73/2;
        sound(sin(freq.*[0:1439]).*cosWindowFlattop([1 1440],720,720,0));
    end
    function OUT=return_OUT(obj,bRmNans)
        if ~exist('bRmNans','var')
            bRmNans=[];
        end
        OUT=Rsp.return_OUT_fun(obj,bRmNans);
        %R=exp.RSP.responses;
        %if size(R,2) > 1
        %    R(:, ~any(R,1))=[];
        %end
        %if all(ismember(R,[0,1]))
        %    R=R+1;
        %end
    end
end
methods(Static=true)
    function OUT=return_OUT_fun(obj,bRmNans)
        if ~exist('bRmNans','var') || isempty(bRmNans)
            bRmNans=0;
        end
        OUT=struct();
        OUT.R=obj.responses;
        OUT.answers=obj.answers;
        OUT.bCorrect=obj.bCorrect;
        if obj.bRecordRcmpChs
            OUT.RcmpChosen=obj.RcmpChs;
        end
        if ~isempty(obj.cmpIntrvl)
            OUT.cmpIntrvl=obj.cmpIntrvl;
        end
        if ~isempty(obj.cmpX)
            OUT.cmpX=obj.cmpX;
        end
        if ~isempty(obj.stdX)
            OUT.stdX=obj.stdX;
        end
        if ~bRmNans
            return
        end

        flds=fieldnames(OUT);
        indNans=false(size(OUT.R));
        for i = 1:length(flds)
            fld=flds{i};
            indNans=indNans|isnan(OUT.(fld));
        end
        for i = 1:length(flds)
            fld=flds{i};
            OUT.(fld)(indNans,:)=[];
        end
    end
    function RcmpChs=get_RcmpChs(R,cmpIntrvl,bFlip)
        if ~exist('bFlip','var')
            bFlip=0;
        end
        if bFlip
            RcmpChs=R~=cmpIntrvl;
        else
            RcmpChs=R==cmpIntrvl;
        end
    end
    function [correct,answer] = get_correct_2IFC(R,stdX,cmpX,cmpIntrval,method)
        %function [correct,answer] = get_correct_2IFC(R,stdX,cmpX,cmpIntrvl)
        answer=Rsp.get_answers_2IFC(stdX,cmpX,cmpIntrvl,method);
        % cmpIntrvl is binary
        correct=R==answer;
    end
    function answers= get_answers_2IFC(stdX,cmpX,cmpIntrvl,method)
        if all(ismember(cmpIntrvl,[1,2])) && any(ismember(cmpIntrvl,2))
            cmpIntrvl=cmpIntrvl-1;
        end
        if strcmp(method,'mag')
            cmpX=abs(cmpX);
            stdX=abs(stdX);
            %tmp=cmpX;
            %cmpX=abs(stdX); % NOTE FLIPPED
            %stdX=abs(tmp);
        end
        answers=zeros(size(cmpIntrvl));
        ind=cmpX > stdX;
        answers(ind)=cmpIntrvl(ind);

        ind=cmpX < stdX;
        answers(ind)=~cmpIntrvl(ind);

        ind=cmpX == stdX;
        ind(:,sum(ind,1)==size(ind,1))=[];

        answer(ind) = double(rand(sum(ind),1) > 0.5);
    end
end
end
