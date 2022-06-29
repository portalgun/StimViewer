classdef PtchsPlotter < handle
properties
    f
    sp
    clim=[]
    pos=[]

    Parent
end
methods
    function obj= PtchsPlotter(opts)
        %obj.Parent=parent;
        %P=obj.getPlotP();
        %obj.plotOpts=Args.parse(struct(),P,obj.Parent.plotOpts);
    end
    function plot(obj,ims,opts)
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

        flds=fieldnames(ims);
        bPlot=structfun(@(x) x.bPlot,opts);
        flds(~bPlot)=[];

        n=sum(bPlot);
        m=max(structfun(@numel,ims));
        m(~bPlot)=[];

        clims=zeros(n,m,2);
        for i = 1:n
        for j = 1:m
            if j==1
                xlabel(flds{i});
            end
            subPlot([n,m],i,j);
            im=ims.(flds{i}){j};
            opt=opts.(flds{i}){j}; % XXX
            if isempty(im)
                continue
            end
            hold off;
            imagesc(real(im));
            hold on;

            % RECT
            if strcmp(opt.buffORptch,'buff')
                if strcmp(opts.mode,'sng');
                    PszRC=size(im);
                    PctrRC=PszRC/2+0.5;
                    Plot.rect(PctrRC, PszRC(1), Opts.PszRC(2),'r',1,1);
                elseif strcmp(opts.mode,'sbs')
                    % TODO
                elseif strcmp(opts.mode,'ana')
                    % TODO
                end
            end

            ptch_plot.format_fun;
            obj.clims(i,j,:)=caxis;
        end
        end

        drawnow
        obj.pos=get(gcf,'Position');
    end
    function obj=zoom_in(obj,inc)
        obj.append_reset('stm');
        if ~exist('inc','var') || isempty(inc)
            inc=0.05;
        end
        obj.stmOpts.stmMult=obj.stmOpts.stmMult+inc;
        obj.pos=obj.sp.position;
        obj.pos(3:4)=obj.pos(3:4)*obj.stmOpts.stmMult;
    end
    function obj=zoom_out(obj,dec)
        obj.append_reset('stm');
        if ~exist('dec','var') || isempty(dec)
            dec=0.05;
        end
        obj.stmOpts.stmMult=obj.stmOpts.stmMult-dec;
        obj.pos=obj.sp.position;
        obj.pos(3:4)=obj.pos(3:4)*obj.stmOpts.stmMult;
    end
    function zoom_reset(obj)
        obj.append_reset('stm');
        obj.stmOpts.stmMult=1; % XXX
        obj.pos=obj.sp.position;
        obj.pos(3:4)=obj.pos(3:4)*stmSz;

        % XXX WHpix
    end
end
methods(Static)
    function P=getP()
        P={ ...
           'sp',[],@(x) isempty(x) | isa(x,'SubPlots');
           'clim',[],'isnumeric_2_e';
           'pos',[],'isnumeric_4_e';
        };
    end
end
end
