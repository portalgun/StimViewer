classdef Exp < handle
properties
    % PARAM
    nTrial
    nInterval     % expands to max
    trlSd
    intSd
    sdGenerator %default?
    outSd=struct()

    disabledTrl
    disabledInt

    % n x (1+nInterval)
    % trl interval1 interval2...
    trlIndexPrivate
    trlIndexPublic %STATIC, sorted
    intIndexPrivate
    intIndexPublic
    trlUnsortIndex

    bTrlSorted=1;
    bIntSorted=1;

    t=0;
    i=0;
    te=0;
    ti=0;

%% listeing
    %eNextTrial
    %eStartExp
    % disable intervals trials
end
properties(Hidden=true)
    intSdTmp
    trlSdTmp
end
events
    IndexChanged
    ExpComplete
    TrialStart
    IntervalStart
    TrialComplete
end
methods
    function obj=Exp(PAR)
        Opts=PAR.Opts.Exp;
        flds=fieldnames(Opts);
        for i = 1:length(flds)
            fld=flds{i};
            obj.(fld)=Opts.(fld)
        end

        obj.init_public_index();
        obj.init_private_indeces();

        obj.get_disabled(PAR.STM)
    end
%%
    function obj=get_disabled(stm,~)
        obj.disabledInt=obj.duration==0;
        obj.disabledTrl=all(obj.duration,2);
    end
    function obj=start(obj,~,~);
        obj.te=0;
        obj.ti=0;
        obj.next_trail()
    end
    function obj=go_to_trial(obj,~,data)
        if data > obj.nTrl
            return
        end
        obj.te=data;
        obj.t=obj.indexPrivate(obj.te,1)
        obj.
    end
    function obj=go_to_trial_p(obj,~,data)
        % TODO
        % and event
    end
%%
    function obj=next_trial(obj,~,~)
        T=obj.te+1; %increment external
        if T > obj.nTrial
            notify(obj,'ExpComplete');
        end
        obj.run_trial(T);
    end

    function obj=run_trial(obj,te)
        obj.te=te;
        obj.t=obj.trlIndexPrivate(obj.te,1)
        % NOTE STOP USING te HERE
        obj.ie=-1;
        if obj.disabledTrl(obj.t)
            obj.next_trial()
            return
        end
        obj.i=0;
        notify(obj,'TrialStart',obj.t);
        for k=1:obj.nInetervals
            obj.next_interval();
        end
    end
%%
    function obj=next_interval(obj)
        I=obj.i+1;
        if I > obj.nInterval(obj.t)
            notify(obj,'TrialComplete');
            return
        end
        obj.run_interval(I);
    end
    function obj=run_interval(obt,i)
        obj.ie=ie;
        obj.i=obj.intIndexPrivate(obj.te,obj.ie)
        % NOTE STOP USING ie HERE
        if obj.disabledInt(obj.t,obj.i)
            obj.next_trial()
        else
            notify(obj,'IntervalStart',obj.i);
        end
    end
%%
    function sd=get_seed(obj)
        sd=rng('shuffle',obj.sdGenerator);
        sd=rng('shuffle',obj.sdGenerator);
        sd=rng('shuffle',obj.sdGenerator);
        sd=sd.Seed;
    end
    function obj=shuffle_trials(obj,trlSd)
        if ~exist('trlSd','var') || isempty(trlSd)
            obj.trlSd=obj.get_seed();
        else
            obj.trlSd=trlSd;
        end
        obj.init_private_indeces();
    end
    function obj=shuffle_intervals(obj,intSd)
        if ~exist('intSd','var') || isempty(intSd)
            obj.intSd=obj.get_seed();
        else
            obj.intSd=intSd;
        end
        obj.init_private_indeces();
    end
    function obj=sort_trials(obj);
        if obj.bTrlSorted
            return
        end
        obj.trlSdTmp=obj.trlSd;
        obj.trlSd=0;
        obj.init_private_indeces();

        obj.trlSd=obj.trlSdTmp;
        obj.trlSdTmp=[];
        obj.bTrlSorted=1;
        obj.notify(obj,'IndexUpdated',obj.trlIndexPrivate);
    end
    function obj=sort_intervals(obj)
        if obj.bIndSorted
            return
        end
        obj.intSdTmp=obj.intSd;
        obj.intSd=0;
        obj.init_private_indeces();

        obj.intSd=obj.intSdTmp;
        obj.intSdTmp=[];
        obj.bIndSorted=1;
        obj.notify(obj,'IndexUpdated',obj.trlIndexPrivate);
    end
    function obj=unsort_trials(obj)
        if obj.bTrlSorted==0
            return
        end
        obj.bTrlSorted=0;
        obj.init_private_index(obj);
        obj.notify(obj,'IndexUpdated',obj.trlIndexPrivate);
    end
    function obj=unsort_intervals(obj)
        if obj.bIntSorted==0
            return
        end
        obj.bIntSorted=0;
        obj.init_private_index(obj);
        obj.notify(obj,'IndexUpdated',obj.trlIndexPrivate);
    end
methods(Private=true)
    function obj=apply_trial_seed(obj)
        obj.outSd.trlSd=rng(obj.trlSd,obj.sdGenerator);
        obj.trlIndexPrivate=Vec.col(randPerm(obj.trlIndexPrivate));
        [~,obj.trlUnsortIndex]=sort(obj.trlIndexPrivate);
    end
    function obj=apply_interval_seed(obj)
        obj.outSd.intSd=rng(obj.trlSd,obj.sdGenerator);
        for k = 1:obj.nTrl
            obj.intIndexPrivate(k,:)=Vec.row(randPerm(obj.trlIndexPrivate(k,:)))
        end
    end
    function obj=init_public_index
        obj.trlIndexPublic=(1:obj.nTrl)';
        obj.intIndexPublic=repmat(1:obj.nInterval,obj.nTrl,1);
    end
    function obj=init_private_indeces(obj);
        obj.trlIndexPrivate=1:obj.nTrl'
        obj.intIndexPrivate=repmat(1:obj.nInterval,obj.nTrl,1);

        if ~isempty(obj.trlSd) && obj.trlSd > 0 && ~obj.bTrlSorted
            obj.bIntSorted=0;
            obj.apply_trial_seed();
        end
        if ~isempty(obj.intSd) && obj.intSd > 0 && ~obj.bIntSorted
            obj.bTrlSorted=0;
            obj.apply_interval_seed();
        end
        % NOTE intervals suffled first, then trials shuffled
        obj.intIndexPrivate(obj.trlIndexPrivate,:);
    end
end
%%
end
end
