clear; clc; close all;
folder = 'C:\Users\Admin\Desktop\RMX\Lab\Load cell';
S = load(fullfile(folder,'data3.mat'));
names = fieldnames(S);
fc_Hz = 2; % Trial setting, not an experimentally proven signal bandwidth.
breakVoltage_V = 0.25; % Provisional boundary near the 130 g measurements.
source = strings(0,1); trial=[]; mass=[]; voltage=[];
times={}; rawSignals={}; filteredSignals={};
for j=1:numel(names)
    tok=regexp(names{j},'^W(\d+)_([23])$','tokens','once');
    if isempty(tok), continue; end
    ts=S.(names{j}).getElement(2).Values;
    t=double(ts.Time(:)); x=double(ts.Data(:));
    dt=median(diff(t));
    assert(all(isfinite(x)) && dt>0 && max(abs(diff(t)-dt))<1e-6*dt);
    alpha=1-exp(-2*pi*fc_Hz*dt);
    % Causal one-pole low-pass; initialize to first reading, not zero.
    xf=filter(alpha,[1 -(1-alpha)],x,(1-alpha)*x(1));
    keep=floor(.2*numel(x))+1:ceil(.8*numel(x));
    source(end+1,1)=string(names{j}); trial(end+1,1)=str2double(tok{2});
    % Assumption inherited from original calibration: W00305_2 = 30.5 g.
    mass(end+1,1)=str2double(tok{1})/10;
    voltage(end+1,1)=mean(xf(keep));
    times{end+1,1}=t; rawSignals{end+1,1}=x; filteredSignals{end+1,1}=xf;
end
[~,order]=sortrows([trial mass],[1 2]);
source=source(order); trial=trial(order); mass=mass(order); voltage=voltage(order);
times=times(order); rawSignals=rawSignals(order); filteredSignals=filteredSignals(order);
v=voltage; w=mass;
pLinear=polyfit(v,w,1);
model=fitModel(v,w,breakVoltage_V);
predLinear=polyval(pLinear,v); predPiece=applyModel(v,model);
% Hold out an entire trial, not individual time samples from the same run.
cvLinear=zeros(size(w)); cvPiece=zeros(size(w));
for heldTrial=[2 3]
    train=trial~=heldTrial; test=~train;
    p=polyfit(v(train),w(train),1);
    q=fitModel(v(train),w(train),breakVoltage_V);
    cvLinear(test)=polyval(p,v(test));
    cvPiece(test)=applyModel(v(test),q);
end
fprintf('Boundary (chosen for exploration): %.6f V\n',model.vb);
fprintf('m=%.12g; b=%.12g; s=%.12g; k=%.12g; Wb=%.12g\n', ...
    model.m,model.b,model.s,model.k,model.m*model.vb+model.b);
fprintf('Full linear: m=%.12g b=%.12g\n',pLinear(1),pLinear(2));
fprintf('Fit RMSE (g): linear %.6f; piecewise %.6f\n', ...
    rmsError(predLinear,w),rmsError(predPiece,w));
fprintf('Held-trial RMSE (g): linear %.6f; piecewise %.6f\n', ...
    rmsError(cvLinear,w),rmsError(cvPiece,w));
for r=[2 3]
    test=trial==r;
    fprintf('Held trial %d RMSE (g): linear %.6f; piecewise %.6f\n',r, ...
        rmsError(cvLinear(test),w(test)),rmsError(cvPiece(test),w(test)));
end
low=w<=130;
fprintf('Low range <=130 g fit RMSE: linear %.6f; piecewise %.6f\n', ...
    rmsError(predLinear(low),w(low)),rmsError(predPiece(low),w(low)));
fprintf('Low range <=130 g held-trial RMSE: linear %.6f; piecewise %.6f\n', ...
    rmsError(cvLinear(low),w(low)),rmsError(cvPiece(low),w(low)));
fprintf('Low range has %d observations, only four mass levels per trial.\n',sum(low));
T=table(source,trial,mass,voltage,predLinear,predPiece,cvLinear,cvPiece);
writetable(T,fullfile(folder,'data3_piecewise_results.csv'));
save(fullfile(folder,'data3_piecewise_model.mat'),'model','pLinear','fc_Hz','breakVoltage_V');

fig=figure('Color','w','Position',[100 100 1200 780]);
tiledlayout(2,2,'Padding','compact');
for panel=1:2
    ax=nexttile; hold on;
    plot(v(trial==2),w(trial==2),'o','DisplayName','Trial 2');
    plot(v(trial==3),w(trial==3),'s','DisplayName','Trial 3');
    vg=linspace(min(v),max(v),1000)';
    plot(vg,polyval(pLinear,vg),'--','DisplayName','Single linear');
    plot(vg,applyModel(vg,model),'-','LineWidth',1.5,'DisplayName','Exponential + linear');
    xline(model.vb,':','Boundary','HandleVisibility','off');
    xlabel('Filtered mean voltage (V)'); ylabel('Reference mass (g)');
    if panel==1, title('Calibration: all points'); else, title('Low-mass detail'); xlim([0 .4]); ylim([-30 210]); end
    styleAxes(ax);
end
ax=nexttile; hold on;
plot(w,predLinear-w,'o','DisplayName','Single linear');
plot(w,predPiece-w,'s','DisplayName','Exponential + linear');
yline(0,':','HandleVisibility','off'); xlabel('Reference mass (g)'); ylabel('Predicted - reference (g)'); title('Fit error (training data)'); styleAxes(ax);
ax=nexttile; hold on;
plot(w,cvLinear-w,'o','DisplayName','Single linear');
plot(w,cvPiece-w,'s','DisplayName','Exponential + linear');
yline(0,':','HandleVisibility','off'); xlabel('Reference mass (g)'); ylabel('Predicted - reference (g)'); title('Error on held-out trial'); styleAxes(ax);
exportgraphics(fig,fullfile(folder,'data3_piecewise_calibration.png'),'Resolution',160);

fig2=figure('Color','w','Position',[100 100 1250 780]); tiledlayout(2,1,'Padding','compact');
for r=[2 3]
    ax=nexttile; hold on; offset=0; first=true;
    for j=find(trial==r)'
        t=times{j}; x=rawSignals{j}; xf=filteredSignals{j};
        tt=t-t(1)+offset;
        h1=plot(tt,applyModel(x,model),'Color',[.75 .75 .75]);
        h2=plot(tt,applyModel(xf,model),'Color',[0 .35 .7],'LineWidth',1);
        h3=plot(tt,repmat(w(j),size(tt)),'--','Color',[.8 .25 .05],'LineWidth',1);
        if first
            set(h1,'DisplayName','Raw voltage -> piecewise mass');
            set(h2,'DisplayName','2 Hz causal low-pass -> piecewise mass');
            set(h3,'DisplayName','Reference mass'); first=false;
        else
            set([h1 h2 h3],'HandleVisibility','off');
        end
        if offset>0, xline(offset,':','Color',[.8 .8 .8],'HandleVisibility','off'); end
        offset=tt(end)+median(diff(t));
    end
    title(sprintf('Trial %d: separate recordings sorted by mass; NOT a continuous step test',r));
    xlabel('Concatenated record time (s)'); ylabel('Estimated mass (g)'); styleAxes(ax);
end
exportgraphics(fig2,fullfile(folder,'data3_piecewise_time.png'),'Resolution',160);

function model=fitModel(v,w,vb)
    high=v>=vb; p=polyfit(v(high),w(high),1);
    opts=optimset('Display','off','MaxFunEvals',15000,'MaxIter',5000,'TolX',1e-9,'TolFun',1e-9);
    best=Inf;
    for k0=[-1 -5 -15 -40]
        z0=[log(max(p(1),1)),p(2),log(300),log(-k0)];
        [z,loss]=fminsearch(@(z)objective(z,v,w,vb),z0,opts);
        if loss<best, best=loss; model=decode(z,vb); end
    end
end
function loss=objective(z,v,w,vb)
    % Constrain scales to prevent numerical overflow and preserve monotonicity.
    if any(~isfinite(z)) || any(abs(z([1 3 4]))>12) || abs(z(2))>1e5
        loss=1e30; return;
    end
    q=decode(z,vb);
    if abs(q.k)*max(abs(v-vb))>500, loss=1e30; return; end
    y=applyModel(v,q); loss=sum((y-w).^2);
    if ~isfinite(loss), loss=1e30; end
end
function q=decode(z,vb)
    q=struct('m',exp(z(1)),'b',z(2),'s',exp(z(3)),'k',-exp(z(4)),'vb',vb);
end
function y=applyModel(v,q)
    y=q.m*v+q.b; low=v<q.vb;
    % Continuous at vb; derivative is positive in both regions.
    y(low)=q.m*q.vb+q.b+(q.s/q.k)*expm1(q.k*(v(low)-q.vb));
end
function e=rmsError(y,w)
    e=sqrt(mean((y-w).^2));
end
function styleAxes(ax)
    grid(ax,'on'); set(ax,'Color','w','XColor','k','YColor','k'); ax.Title.Color='k';
    legend(ax,'Location','best','Color','w','TextColor','k');
end
